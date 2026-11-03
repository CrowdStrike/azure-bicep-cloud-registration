import { filterLocationsPerSubscription } from '../../models/scanning.bicep'

targetScope = 'subscription'

/*
  This Bicep template handles batched scanning subscription deployment
  to stay under the 800 resource and 4 MB deployment size limits for large numbers of subscriptions.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

@export()
@description('Maximum number of subscriptions per scanning batch, sized to stay within Azure Resource Manager deployment limits. Keep the @maxLength of subscriptionEntries here and in scanningRolesSubBatch.bicep equal to it.')
var maxScanningBatchSize = 75

/* Parameters */
@maxLength(75)
@description('Batched list of subscription entries with their scanning locations. Each entry contains subscriptionId and locations array. (max: 75)')
param subscriptionEntries array

@description('Client ID for the Falcon API.')
param falconClientId string

@description('Client secret for the Falcon API.')
@secure()
param falconClientSecret string

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

@description('Azure locations (regions) where DSPM will be deployed as subscription ID to locations map. Covers only the subscriptions in this batch.')
param inputAgentlessScanningLocationsPerSubscription object = {}

@description('Per-region custom VNet configuration for agentless scanning.')
param inputAgentlessScanningCustomVnetConfiguration object = {}

@description('Role definition ID for access role. When provided, uses MG-scoped role instead of creating per-subscription.')
param accessRoleId string = ''

@description('Role definition ID for scanner role. When provided, uses MG-scoped role instead of creating per-subscription.')
param scannerRoleId string = ''

@description('Role definition ID for resource group access role. When provided, uses MG-scoped role instead of creating per-subscription.')
param resourceGroupAccessRoleId string = ''

@description('Role definition ID for scanner resource group role. When provided, uses MG-scoped role instead of creating per-subscription.')
param resourceGroupScannerRoleId string = ''

@description('Whether to create the resource group role definitions in per-subscription roles. Only needed for host subscriptions.')
param includeResourceGroupRoles bool = true

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env
var useExternalRoles = !empty(accessRoleId)

/* Create per-subscription roles when no MG-scoped roles are provided */
module subRoles 'scanningRolesSubBatch.bicep' = if (!useExternalRoles) {
  name: '${resourceNamePrefix}cs-scanning-roles-batch-${uniqueString(deployment().name)}${environment}${resourceNameSuffix}'
  params: {
    subscriptionEntries: subscriptionEntries
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    env: env
    agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
    includeResourceGroupRoles: includeResourceGroupRoles
    inputEnableDspm: inputEnableDspm
    inputEnableVulnerabilityScanning: inputEnableVulnerabilityScanning
  }
}

/* Deploy scanning infrastructure for subscriptions in this batch */
module scanningSub 'scanningForSub.bicep' = [
  for (sub, i) in subscriptionEntries: {
    name: '${resourceNamePrefix}cs-scanning-${sub.subscriptionId}${environment}${resourceNameSuffix}'
    scope: subscription(sub.subscriptionId)
    params: {
      falconClientId: falconClientId
      falconClientSecret: falconClientSecret
      scanningPrincipalId: scanningPrincipalId
      scanningEnvironmentLocations: sub.locations
      scanningManagedIdentityPrincipalId: scanningManagedIdentityPrincipalId
      agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
      agentlessScanningHostSubscriptionId: agentlessScanningHostSubscriptionId
      inputEnableDspm: inputEnableDspm
      inputEnableVulnerabilityScanning: inputEnableVulnerabilityScanning
      inputAgentlessScanningLocations: inputAgentlessScanningLocations
      inputAgentlessScanningLocationsPerSubscription: filterLocationsPerSubscription(
        inputAgentlessScanningLocationsPerSubscription,
        [sub]
      )
      inputAgentlessScanningCustomVnetConfiguration: inputAgentlessScanningCustomVnetConfiguration
      accessRoleId: useExternalRoles ? accessRoleId : subRoles!.outputs.roles[i].accessRoleId
      scannerRoleId: useExternalRoles ? scannerRoleId : subRoles!.outputs.roles[i].scannerRoleId
      resourceGroupAccessRoleId: useExternalRoles
        ? resourceGroupAccessRoleId
        : subRoles!.outputs.roles[i].resourceGroupAccessRoleId
      resourceGroupScannerRoleId: useExternalRoles
        ? resourceGroupScannerRoleId
        : subRoles!.outputs.roles[i].resourceGroupScannerRoleId
      resourceGroupName: resourceGroupName
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      env: env
      tags: tags
    }
  }
]

/* Outputs */
output subscriptionsProcessed int = length(subscriptionEntries)
