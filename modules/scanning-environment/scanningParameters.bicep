targetScope = 'subscription'

/*
  This Bicep template deploys a policy definition to store scanning parameters
  Copyright (c) 2025 CrowdStrike, Inc.
*/

/* Parameters */
@description('Principal ID of the CrowdStrike application registered in Entra ID. This ID is used for role assignments and access control.')
param scanningPrincipalId string

@description('Client ID for the Falcon API.')
param inputFalconClientId string

@description('Controls whether to enable DSPM.')
param inputEnableDspm bool

@description('Azure locations (regions) where DSPM will be deployed.')
param inputAgentlessScanningLocations array

@description('Azure locations (regions) where DSPM will be deployed as subscription ID to locations map.')
param inputAgentlessScanningLocationsPerSubscription object

@description('Controls whether to deploy NAT Gateway for scanning environment.')
param inputAgentlessScanningDeployNatGateway bool

@maxLength(10)
@description('Optional prefix added to all resource names for organization and identification purposes.')
param inputResourceNamePrefix string

@maxLength(10)
@description('Optional suffix added to all resource names for organization and identification purposes.')
param inputResourceNameSuffix string

@maxLength(4)
@description('Environment label (for example, prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param inputEnv string

@description('Tags to be applied to all deployed resources. Used for resource organization and governance.')
param inputTags object

/* Variables */
var environment = length(inputEnv) > 0 ? '-${inputEnv}' : inputEnv
var policyDefinitionName = '${inputResourceNamePrefix}policy-csscanning-parameters${environment}${inputResourceNameSuffix}'
var version = '1.0.0+bicep.1'

/* Functions */
func boolToJson(value bool) string => value ? 'true' : 'false'
#disable-next-line BCP329 square brackets will be created by array to string conversion
func stringToJson(value string) string => substring(string([value]), 1, length(string([value])) - 2)

/* Serialized parameters */
var parameterDefinitions = {
  deploymentVersion: stringToJson(version)
  scanningPrincipalId: stringToJson(scanningPrincipalId)
  falconClientId: stringToJson(inputFalconClientId)
  enableDspm: boolToJson(inputEnableDspm)
  agentlessScanningLocations: string(inputAgentlessScanningLocations)
  agentlessScanningLocationsPerSubscription: string(inputAgentlessScanningLocationsPerSubscription)
  agentlessScanningDeployNatGateway: boolToJson(inputAgentlessScanningDeployNatGateway)
  resourceNamePrefix: stringToJson(inputResourceNamePrefix)
  resourceNameSuffix: stringToJson(inputResourceNameSuffix)
  env: stringToJson(inputEnv)
  tags: string(inputTags)
}

var policyParameters = toObject(items(parameterDefinitions), item => item.key, item => {
  type: 'String'
  defaultValue: item.value
})

var policyRuleConditions = map(items(parameterDefinitions), item => {
  value: '[parameters(\'${item.key}\')]'
  exists: 'true'
})

resource scanningParametersPolicy 'Microsoft.Authorization/policyDefinitions@2024-05-01' = {
  name: policyDefinitionName
  properties: {
    displayName: 'CrowdStrike Agentless Scanning Parameters'
    policyType: 'Custom'
    mode: 'All'
    metadata: {
      category: 'CrowdStrike'
      version: '1.0.0'
    }
    parameters: policyParameters
    policyRule: {
      if: {
        allOf: policyRuleConditions
      }
      then: {
        effect: 'disabled'
      }
    }
  }
}

output policyDefinitionId string = scanningParametersPolicy.id
