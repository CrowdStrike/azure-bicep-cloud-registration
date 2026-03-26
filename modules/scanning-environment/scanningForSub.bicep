targetScope = 'subscription'

/*
  This Bicep template deploys infrastructure to enable CrowdStrike Scanning in subscription
  Copyright (c) 2025 CrowdStrike, Inc.
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

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env
var shouldDeployResources = empty(agentlessScanningHostSubscriptionId) || subscription().subscriptionId == agentlessScanningHostSubscriptionId
var subscriptionAccessRoleName = '${resourceNamePrefix}role-csscanning-access-${subscription().subscriptionId}${resourceNameSuffix}'
var subscriptionAccessRoleDescription = 'CrowdStrike Scanning Subscription Access Role'
var scannerRoleName = '${resourceNamePrefix}role-csscanning-scanner-${subscription().subscriptionId}${resourceNameSuffix}'
var scannerRoleDescription = 'CrowdStrike Scanning Subscription Scanner Role'
var baseAccessActions = [
  // ============ Validation ============
  'Microsoft.Authorization/roleAssignments/read'
  'Microsoft.Authorization/policyDefinitions/read'
]
var dspmAccessActions = [
  // ============ Blob Storage ============
  'Microsoft.Storage/storageAccounts/read' // Check location and public access
  'Microsoft.Storage/storageAccounts/PrivateEndpointConnectionsApproval/action' // Approve private link connections
]
var vulnScanningAccessActions = [
  'Microsoft.Compute/disks/beginGetAccess/action' // Access source disk for snapshot
  'Microsoft.Compute/disks/read' // Read source disk metadata
  'Microsoft.Compute/virtualMachines/read' // Read VM metadata
  'Microsoft.Compute/virtualMachineScaleSets/read' // Read VMSS metadata (Uniform VMSS)
  'Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read' // Read VMSS instance metadata
]

var dspmScannerActionsSubscriptionScope = [
  'Microsoft.Storage/storageAccounts/blobServices/containers/read'
]
var dspmScannerDataActionsSubscriptionScope = [
  'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'
]

resource subscriptionAccessRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, subscriptionAccessRoleName)
  properties: {
    roleName: subscriptionAccessRoleName
    description: subscriptionAccessRoleDescription
    type: 'CustomRole'
    permissions: [
      {
        actions: union(
          baseAccessActions,
          inputEnableDspm ? dspmAccessActions : [],
          inputEnableVulnerabilityScanning ? vulnScanningAccessActions : []
        )
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
  name: guid(subscription().id, scanningPrincipalId, subscriptionAccessRole.id)
  properties: {
    roleDefinitionId: subscriptionAccessRole.id
    principalId: scanningPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource scannerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, scannerRoleName)
  properties: {
    roleName: scannerRoleName
    description: scannerRoleDescription
    type: 'CustomRole'
    permissions: [
      {
        actions: inputEnableDspm ? dspmScannerActionsSubscriptionScope : []
        notActions: []
        dataActions: inputEnableDspm ? dspmScannerDataActionsSubscriptionScope : []
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
    inputEnableVulnerabilityScanning: inputEnableVulnerabilityScanning
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    env: env
    tags: tags
  }
}

resource scannerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: shouldDeployResources
    ? guid(subscription().id, 'scanningManagedIdentityPrincipalId', scannerRole.id)
    : guid(subscription().id, scanningManagedIdentityPrincipalId, scannerRole.id)
  properties: {
    principalId: shouldDeployResources
      ? scanningResourceGroupModule!.outputs.scanningManagedIdentityPrincipalId
      : scanningManagedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: scannerRole.id
  }
}

module scanningRegion 'scanningRegion.bicep' = [
  for location in scanningEnvironmentLocations: if (shouldDeployResources) {
    name: '${resourceNamePrefix}cs-scanning-env${environment}-${location}${resourceNameSuffix}'
    scope: scanningResourceGroup
    params: {
      agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      env: env
      location: location
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
    name: '${resourceNamePrefix}cs-scanning-vault-pe${environment}-${location}${resourceNameSuffix}'
    scope: scanningResourceGroup
    params: {
      scanningKeyVaultName: scanningResourceGroupModule!.outputs.scanningKeyVaultName
      scanningKeyVaultSubnetId: scanningRegion[index]!.outputs.clonesSubnetId
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      env: env
      location: location
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
