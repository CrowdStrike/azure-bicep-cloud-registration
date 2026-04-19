targetScope = 'subscription'

/*
  This Bicep template handles batched scanning subscription deployment
  to overcome the 800 iteration limit for large numbers of subscriptions.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

/* Parameters */
@maxLength(800)
@description('Batched list of subscription entries with their scanning locations. Each entry contains subscriptionId and locations array. (max: 800)')
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

@description('Azure locations (regions) where DSPM will be deployed.')
param inputAgentlessScanningLocations array = []

@description('Azure locations (regions) where DSPM will be deployed as subscription ID to locations map.')
param inputAgentlessScanningLocationsPerSubscription object = {}

@description('Per-region custom VNet configuration for agentless scanning.')
param inputAgentlessScanningCustomVnetConfiguration object = {}

@description('Role definition ID for access role. When provided, uses MG-scoped role instead of creating per-subscription.')
param accessRoleId string = ''

@description('Role definition ID for scanner role. When provided, uses MG-scoped role instead of creating per-subscription.')
param scannerRoleId string = ''

@description('Role definition ID for resource group access role. When provided, uses MG-scoped role instead of creating per-subscription.')
param resourceGroupAccessRoleId string = ''

@description('Whether to create the resource group access role definition in per-subscription roles. Only needed for host subscriptions.')
param includeResourceGroupAccessRole bool = true

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env
var useExternalRoles = !empty(accessRoleId)

/* Create per-subscription roles when no MG-scoped roles are provided */
module subRoles 'scanningRolesForSub.bicep' = [
  for sub in subscriptionEntries: if (!useExternalRoles) {
    name: '${resourceNamePrefix}cs-scanning-roles-${uniqueString(sub.subscriptionId)}${environment}${resourceNameSuffix}'
    scope: subscription(sub.subscriptionId)
    params: {
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      env: env
      agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
      includeResourceGroupAccessRole: includeResourceGroupAccessRole
    }
  }
]

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
      inputAgentlessScanningLocations: inputAgentlessScanningLocations
      inputAgentlessScanningLocationsPerSubscription: inputAgentlessScanningLocationsPerSubscription
      inputAgentlessScanningCustomVnetConfiguration: inputAgentlessScanningCustomVnetConfiguration
      accessRoleId: useExternalRoles ? accessRoleId : subRoles[i]!.outputs.accessRoleId
      scannerRoleId: useExternalRoles ? scannerRoleId : subRoles[i]!.outputs.scannerRoleId
      resourceGroupAccessRoleId: useExternalRoles
        ? resourceGroupAccessRoleId
        : subRoles[i]!.outputs.resourceGroupAccessRoleId
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
