import {
  subscriptionAccessRolePermissions
  scannerRolePermissions
  customVnetSubnetRolePermissions
} from '../../models/scanning-roles.bicep'

targetScope = 'subscription'

/*
  This Bicep template deploys infrastructure to enable CrowdStrike Scanning in subscription
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

@description('Azure locations (regions) where DSPM will be deployed.')
param inputAgentlessScanningLocations array = []

@description('Azure locations (regions) where DSPM will be deployed as subscription ID to locations map.')
param inputAgentlessScanningLocationsPerSubscription object = {}

@description('Per-region custom VNet configuration for agentless scanning.')
param inputAgentlessScanningCustomVnetConfiguration object = {}

@description('Role definition ID for subscription access role. When provided, skips per-subscription role creation (management group mode).')
param subscriptionAccessRoleId string = ''

@description('Role definition ID for scanner role. When provided, skips per-subscription role creation (management group mode).')
param scannerRoleId string = ''

@description('Role definition ID for resource group access role. When provided, skips per-subscription role creation (management group mode).')
param resourceGroupAccessRoleId string = ''

/* Variables */
var useExternalRoles = !empty(subscriptionAccessRoleId)
var useCustomSubnets = length(filter(
  scanningEnvironmentLocations,
  location => !empty(location.customScannersSubnet) && !empty(location.customClonesSubnet)
)) > 0
var environment = length(env) > 0 ? '-${env}' : env
var shouldDeployResources = empty(agentlessScanningHostSubscriptionId) || subscription().subscriptionId == agentlessScanningHostSubscriptionId
var subscriptionAccessRoleName = '${resourceNamePrefix}role-csscanning-access-${subscription().subscriptionId}${resourceNameSuffix}'
var scannerRoleName = '${resourceNamePrefix}role-csscanning-scanner-${subscription().subscriptionId}${resourceNameSuffix}'
var customVnetRoleName = '${resourceNamePrefix}role-csscanning-custom-vnet-${subscription().subscriptionId}${resourceNameSuffix}'

resource subscriptionAccessRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (!useExternalRoles) {
  name: guid(subscription().id, subscriptionAccessRoleName)
  properties: {
    roleName: subscriptionAccessRoleName
    description: subscriptionAccessRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: subscriptionAccessRolePermissions.actions
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

resource accessRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    subscription().id,
    scanningPrincipalId,
    useExternalRoles ? subscriptionAccessRoleId : subscriptionAccessRole.id
  )
  properties: {
    roleDefinitionId: useExternalRoles ? subscriptionAccessRoleId : subscriptionAccessRole.id
    principalId: scanningPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource scannerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (!useExternalRoles) {
  name: guid(subscription().id, scannerRoleName)
  properties: {
    roleName: scannerRoleName
    description: scannerRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: scannerRolePermissions.actions
        notActions: []
        dataActions: scannerRolePermissions.dataActions
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

resource customVnetSubnetRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (useCustomSubnets) {
  name: guid(subscription().id, 'customVnetSubnetAccess')
  properties: {
    roleName: customVnetRoleName
    description: customVnetSubnetRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: customVnetSubnetRolePermissions.actions
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

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
    resourceGroupAccessRoleId: resourceGroupAccessRoleId
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    env: env
    tags: tags
  }
}

var effectiveScannerRoleId = useExternalRoles ? scannerRoleId : scannerRole.id

resource scannerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: shouldDeployResources
    ? guid(subscription().id, 'scanningManagedIdentityPrincipalId', effectiveScannerRoleId)
    : guid(subscription().id, scanningManagedIdentityPrincipalId, effectiveScannerRoleId)
  properties: {
    principalId: shouldDeployResources
      ? scanningResourceGroupModule!.outputs.scanningManagedIdentityPrincipalId
      : scanningManagedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: effectiveScannerRoleId
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
      customVnetSubnetRoleId: useCustomSubnets ? customVnetSubnetRole.id : ''
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
