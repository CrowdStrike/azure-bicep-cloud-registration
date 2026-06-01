targetScope = 'subscription'

/*
  This Bicep template deploys scanning infrastructure in a subscription: role assignments,
  resource group resources, and scanning regions. Role definitions are created externally
  (at management group or subscription scope) and passed in via parameters.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

/* Parameters */
@description('Client ID for the Falcon API.')
param falconClientId string

@description('Client secret for the Falcon API.')
@secure()
param falconClientSecret string

@description('Azure locations (regions) where scanning environment will be deployed.')
param scanningEnvironmentLocations array

@description('Principal ID of the CrowdStrike application registered in Entra ID. This ID is used for role assignments and access control.')
param scanningPrincipalId string

@description('Principal ID of the scanning managed identity from the host subscription. Used in cross-account mode for non-host subscriptions.')
param scanningManagedIdentityPrincipalId string = ''

@description('Name of the resource group where CrowdStrike infrastructure resources will be deployed.')
param resourceGroupName string

@maxLength(10)
@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string = ''

@maxLength(10)
@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string = ''

@maxLength(4)
@description('Environment label (for example, prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Tags to be applied to all deployed resources. Used for resource organization, governance, and cost tracking.')
param tags object

@description('Controls whether to deploy NAT Gateway for scanning environment.')
param agentlessScanningDeployNatGateway bool = true

@description('Azure agentless scanning host subscription ID.')
param agentlessScanningHostSubscriptionId string = ''

@description('Controls whether to enable DSPM.')
param inputEnableDspm bool = false

@description('Controls whether to enable vulnerability scanning.')
param inputEnableVulnerabilityScanning bool = false

@description('Azure locations (regions) where DSPM will be deployed.')
param inputAgentlessScanningLocations array = []

@description('Azure locations (regions) where DSPM will be deployed as subscription ID to locations map.')
param inputAgentlessScanningLocationsPerSubscription object = {}

@description('Per-region custom VNet configuration for agentless scanning.')
param inputAgentlessScanningCustomVnetConfiguration object = {}

@description('Role definition ID for access role (created externally at MG or subscription scope).')
param accessRoleId string

@description('Role definition ID for scanner role (created externally at MG or subscription scope).')
param scannerRoleId string

@description('Role definition ID for resource group access role (created externally at MG or subscription scope).')
param resourceGroupAccessRoleId string

@description('Role definition ID for custom VNet subnet access role (created externally at subscription scope). Empty when custom subnets are not used.')
param customVnetSubnetRoleId string = ''

@description('Role definition ID for scanner resource group role (created externally at MG or subscription scope). Empty when not provided.')
param scannerRgRoleId string = ''

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env
var shouldDeployResources = empty(agentlessScanningHostSubscriptionId) || subscription().subscriptionId == agentlessScanningHostSubscriptionId

/* Role Assignments */
resource accessRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, scanningPrincipalId, accessRoleId)
  properties: {
    roleDefinitionId: accessRoleId
    principalId: scanningPrincipalId
    principalType: 'ServicePrincipal'
  }
}

/* Resource Group Deployment */
resource scanningResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: resourceGroupName
}

module scanningResourceGroupModule 'scanningResourceGroup.bicep' = if (shouldDeployResources) {
  name: '${resourceNamePrefix}cs-scanning-rg-${uniqueString(subscription().subscriptionId)}${resourceNameSuffix}'
  scope: scanningResourceGroup
  params: {
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    scanningPrincipalId: scanningPrincipalId
    agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
    inputEnableVulnerabilityScanning: inputEnableVulnerabilityScanning
    resourceGroupAccessRoleId: resourceGroupAccessRoleId
    scannerRgRoleId: scannerRgRoleId
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    env: env
    tags: tags
  }
}

resource scannerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: shouldDeployResources
    ? guid(subscription().id, 'scanningManagedIdentityPrincipalId', scannerRoleId)
    : guid(subscription().id, scanningManagedIdentityPrincipalId, scannerRoleId)
  properties: {
    principalId: shouldDeployResources
      ? scanningResourceGroupModule!.outputs.scanningManagedIdentityPrincipalId
      : scanningManagedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: scannerRoleId
  }
}

module scanningRegion 'scanningRegion.bicep' = [
  for location in scanningEnvironmentLocations: if (shouldDeployResources) {
    name: '${resourceNamePrefix}cs-scanning-env${environment}-${location.name}${resourceNameSuffix}'
    scope: scanningResourceGroup
    params: {
      agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
      customScannersSubnet: location.customScannersSubnet
      customClonesSubnet: location.customClonesSubnet
      scanningPrincipalId: scanningPrincipalId
      customVnetSubnetRoleId: customVnetSubnetRoleId
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      env: env
      location: location.name
      tags: tags
    }
    dependsOn: [
      scanningResourceGroupModule
    ]
  }
]

@batchSize(1)
module scanningKeyVaultPrivateEndpoint 'scanningKeyVaultPrivateEndpoint.bicep' = [
  for (location, index) in scanningEnvironmentLocations: if (shouldDeployResources) {
    name: '${resourceNamePrefix}cs-scanning-vault-pe${environment}-${location.name}${resourceNameSuffix}'
    scope: scanningResourceGroup
    params: {
      scanningKeyVaultName: scanningResourceGroupModule!.outputs.scanningKeyVaultName
      scanningKeyVaultSubnetId: scanningRegion[index]!.outputs.clonesSubnetId
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      env: env
      location: location.name
      tags: tags
    }
  }
]

module scanningParametersModule 'scanningParameters.bicep' = {
  name: '${resourceNamePrefix}cs-scanning-params${environment}${resourceNameSuffix}'
  params: {
    scanningPrincipalId: scanningPrincipalId
    inputFalconClientId: falconClientId
    inputEnableDspm: inputEnableDspm
    inputEnableVulnerabilityScanning: inputEnableVulnerabilityScanning
    inputAgentlessScanningLocations: inputAgentlessScanningLocations
    inputAgentlessScanningLocationsPerSubscription: inputAgentlessScanningLocationsPerSubscription
    inputAgentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
    inputAgentlessScanningHostSubscriptionId: agentlessScanningHostSubscriptionId
    inputAgentlessScanningCustomVnetConfiguration: inputAgentlessScanningCustomVnetConfiguration
    inputResourceNamePrefix: resourceNamePrefix
    inputResourceNameSuffix: resourceNameSuffix
    inputEnv: env
    inputTags: tags
  }
  dependsOn: [
    scannerRoleAssignment
    scanningRegion
    scanningKeyVaultPrivateEndpoint
  ]
}

output scanningManagedIdentityId string = shouldDeployResources
  ? scanningResourceGroupModule!.outputs.scanningManagedIdentityId
  : ''
output scanningManagedIdentityPrincipalId string = shouldDeployResources
  ? scanningResourceGroupModule!.outputs.scanningManagedIdentityPrincipalId
  : ''
