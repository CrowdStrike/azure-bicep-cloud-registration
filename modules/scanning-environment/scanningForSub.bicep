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

@description('Controls whether to enable DSPM.')
param inputEnableDspm bool = false

@description('Azure locations (regions) where DSPM will be deployed.')
param inputAgentlessScanningLocations array = []

@description('Azure locations (regions) where DSPM will be deployed as subscription ID to locations map.')
param inputAgentlessScanningLocationsPerSubscription object = {}

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env
var subscriptionAccessRoleName = '${resourceNamePrefix}role-csscanning-access-${subscription().subscriptionId}${resourceNameSuffix}'
var subscriptionAccessRoleDescription = 'CrowdStrike Scanning Subscription Access Role'
var scannerRoleName = '${resourceNamePrefix}role-csscanning-scanner-${subscription().subscriptionId}${resourceNameSuffix}'
var scannerRoleDescription = 'CrowdStrike Scanning Subscription Scanner Role'

resource subscriptionAccessRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, subscriptionAccessRoleName)
  properties: {
    roleName: subscriptionAccessRoleName
    description: subscriptionAccessRoleDescription
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          // ============ Blob Storage ============
          'Microsoft.Storage/storageAccounts/read' // Check location and public access
          'Microsoft.Storage/storageAccounts/PrivateEndpointConnectionsApproval/action' // Approve private link connections

          // ============ Validation ============
          'Microsoft.Authorization/roleAssignments/read'
          'Microsoft.Authorization/policyDefinitions/read'
        ]
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
        actions: [
          'Microsoft.Storage/storageAccounts/blobServices/containers/read'
        ]
        notActions: []
        dataActions: [
          'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'
        ]
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

module scanningResourceGroupModule 'scanningResourceGroup.bicep' = {
  name: '${resourceNamePrefix}cs-scanning-rg-${uniqueString(subscription().subscriptionId)}${resourceNameSuffix}'
  scope: scanningResourceGroup
  params: {
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    scanningPrincipalId: scanningPrincipalId
    agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    env: env
    tags: tags
  }
}

resource scannerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, 'scanningManagedIdentityPrincipalId', scannerRole.id)
  properties: {
    roleDefinitionId: scannerRole.id
    principalId: scanningResourceGroupModule.outputs.scanningManagedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

module scanningRegion 'scanningRegion.bicep' = [
  for location in scanningEnvironmentLocations: {
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
  for (location, index) in scanningEnvironmentLocations: {
    name: '${resourceNamePrefix}cs-scanning-vault-pe${environment}-${location}${resourceNameSuffix}'
    scope: scanningResourceGroup
    params: {
      scanningKeyVaultSubnetId: scanningRegion[index].outputs.clonesSubnetId
      scanningKeyVaultName: scanningResourceGroupModule.outputs.scanningKeyVaultName
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
    inputAgentlessScanningLocations: inputAgentlessScanningLocations
    inputAgentlessScanningLocationsPerSubscription: inputAgentlessScanningLocationsPerSubscription
    inputAgentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
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
