targetScope = 'resourceGroup'

/*
  This Bicep template deploys resource group level scanning resources
  Copyright (c) 2026 CrowdStrike, Inc.
*/

/* Parameters */
@description('Principal ID of the CrowdStrike application registered in Entra ID. This ID is used for role assignments and access control.')
param scanningPrincipalId string

@description('Client ID for the Falcon API.')
param falconClientId string

@description('Client secret for the Falcon API.')
@secure()
param falconClientSecret string

@maxLength(10)
@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string = ''

@maxLength(10)
@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string = ''

@description('Environment label (for example, prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Tags to be applied to all deployed resources. Used for resource organization and governance.')
param tags object

@description('Whether NAT Gateway is enabled. When false, public IP permissions are included for VM connectivity.')
param agentlessScanningDeployNatGateway bool = true

@description('Controls whether to enable vulnerability scanning.')
param inputEnableVulnerabilityScanning bool = false

@description('Role definition ID for resource group access role. When provided, skips per-subscription role creation (management group mode).')
param resourceGroupAccessRoleId string = ''

@description('Role definition ID for scanner resource group role. When provided, skips per-subscription role creation (management group mode).')
param resourceGroupScannerRoleId string = ''

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env
// NOTE: key vault has name limit constraints, so prefix and suffix are omitted
var keyVaultName = 'kv-cs-${uniqueString(resourceGroup().id, 'CrowdStrikeScanningKeyVault', 'v2')}'
var managedIdentityName = '${resourceNamePrefix}id-csscanning${environment}${resourceNameSuffix}'
var clientCredentialsName = 'client-credentials'

/* Input Validation */
var validatedResourceGroupAccessRoleId = empty(resourceGroupAccessRoleId)
  ? fail('"resourceGroupAccessRoleId" must be provided to scanningResourceGroup module')
  : resourceGroupAccessRoleId
var validatedResourceGroupScannerRoleId = inputEnableVulnerabilityScanning && empty(resourceGroupScannerRoleId)
  ? fail('"resourceGroupScannerRoleId" must be provided when vulnerability scanning is enabled')
  : resourceGroupScannerRoleId

resource rgRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, scanningPrincipalId, validatedResourceGroupAccessRoleId)
  properties: {
    roleDefinitionId: validatedResourceGroupAccessRoleId
    principalId: scanningPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource scannerManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  location: resourceGroup().location
  name: managedIdentityName
  tags: tags
}

@description('This is the built-in Reader role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#reader')
resource builtinReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
}

@description('This is the built-in Key Vault Secrets User role. See https://docs.azure.cn/en-us/role-based-access-control/built-in-roles/security#key-vault-secrets-user')
resource builtinKeyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource managedIdentityReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, builtinReaderRole.id, scannerManagedIdentity.id)
  properties: {
    roleDefinitionId: builtinReaderRole.id
    principalId: scannerManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource scanningKeyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  location: resourceGroup().location
  name: keyVaultName
  properties: {
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: true
    enableSoftDelete: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    publicNetworkAccess: 'disabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: 7
    tenantId: subscription().tenantId
  }
  tags: union(tags, { CSTagResourceType: 'KeyVault' })
}

resource managedIdentityVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(
    subscription().id,
    resourceGroup().id,
    builtinKeyVaultSecretsUserRole.id,
    scannerManagedIdentity.id,
    scanningKeyVault.name
  )
  scope: scanningKeyVault
  properties: {
    roleDefinitionId: builtinKeyVaultSecretsUserRole.id
    principalId: scannerManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource clientCredentials 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: scanningKeyVault
  name: clientCredentialsName
  properties: {
    contentType: 'string'
    value: string({
      clientId: falconClientId
      clientSecret: falconClientSecret
    })
  }
  tags: tags
}

resource resourceGroupScannerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (inputEnableVulnerabilityScanning) {
  name: guid(subscription().id, resourceGroup().id, validatedResourceGroupScannerRoleId, scannerManagedIdentity.id)
  properties: {
    roleDefinitionId: validatedResourceGroupScannerRoleId
    principalId: scannerManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output scanningKeyVaultName string = scanningKeyVault.name
output scanningManagedIdentityId string = scannerManagedIdentity.id
output scanningManagedIdentityPrincipalId string = scannerManagedIdentity.properties.principalId
