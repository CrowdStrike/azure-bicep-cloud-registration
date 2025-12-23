targetScope = 'resourceGroup'

/*
  This Bicep template deploys resource group level scanning resources
  Copyright (c) 2025 CrowdStrike, Inc.
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

/* Variables */
var vaultIPAddress = '10.1.3.30'

var environment = length(env) > 0 ? '-${env}' : env
// NOTE: key vault has name limit constraints, so prefix and suffix are omitted 
var keyVaultName = 'kv-cs-${uniqueString(resourceGroup().id, 'CrowdStrikeScanningKeyVault')}'
var managedIdentityName = '${resourceNamePrefix}id-csscanning${environment}${resourceNameSuffix}'
var clientCredentialsName = 'client-credentials'
var resourceGroupAccessCustomRole = {
  roleName: '${resourceNamePrefix}role-csscanning-rgaccess-${subscription().subscriptionId}${resourceNameSuffix}'
  roleDescription: 'CrowdStrike Agentless Scanning Resource Group Access Role'
  roleActions: [
    // ============ Blob Storage ============
    // Private Endpoint
    'Microsoft.Network/privateEndpoints/read'
    'Microsoft.Network/privateEndpoints/write'
    'Microsoft.Network/privateEndpoints/delete'
    'Microsoft.Network/virtualNetworks/subnets/join/action'
    // DNS Zone
    'Microsoft.Resources/subscriptions/resourceGroups/read'
    'Microsoft.Network/privateDnsZones/read'
    'Microsoft.Network/privateDnsZones/write'
    'Microsoft.Network/privateDnsZones/delete'
    // DNS Zone Link vNet
    'Microsoft.Network/privateDnsZones/virtualNetworkLinks/read'
    'Microsoft.Network/privateDnsZones/virtualNetworkLinks/write'
    'Microsoft.Network/privateDnsZones/virtualNetworkLinks/delete'
    'Microsoft.Network/virtualNetworks/join/action'
    // DNS Zone Group
    'Microsoft.Network/privateEndpoints/privateDnsZoneGroups/read'
    'Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write'
    'Microsoft.Network/privateEndpoints/privateDnsZoneGroups/delete'
    'Microsoft.Network/privateDnsZones/join/action'

    // ============ Scanner VM ============
    'Microsoft.Network/networkSecurityGroups/read'
    'Microsoft.Network/networkSecurityGroups/write'
    'Microsoft.Network/networkSecurityGroups/delete'
    'Microsoft.Network/networkInterfaces/read'
    'Microsoft.Network/networkInterfaces/write'
    'Microsoft.Network/networkInterfaces/delete'
    'Microsoft.Network/networkInterfaces/join/action'
    'Microsoft.Compute/virtualMachines/read'
    'Microsoft.Compute/virtualMachines/write'
    'Microsoft.Compute/virtualMachines/delete'
    'Microsoft.Network/virtualNetworks/read'
    'Microsoft.ManagedIdentity/userAssignedIdentities/read'
    'Microsoft.ManagedIdentity/userAssignedIdentities/assign/action'
    'Microsoft.Resources/deployments/read'
    'Microsoft.Resources/deployments/write'
    'Microsoft.Resources/deployments/delete'
    'Microsoft.Resources/deployments/operationStatuses/read'
    'Microsoft.Resources/deploymentStacks/*'
    // Always include delete permission for public IPs
    'Microsoft.Network/publicIPAddresses/delete'

    // ============ Validation ============
    'Microsoft.Network/virtualNetworks/subnets/read'
    'Microsoft.Resources/deployments/whatIf/action'
    'Microsoft.Resources/deployments/validate/action'
    'Microsoft.Resources/deploymentScripts/read'
    'Microsoft.KeyVault/vaults/read'
    'Microsoft.Compute/virtualMachines/retrieveBootDiagnosticsData/action'
    'Microsoft.Resources/templateSpecs/read'
    'Microsoft.Resources/templateSpecs/versions/read'
  ]
}

// Conditional permissions for public IPs when NAT Gateway is disabled
var conditionalPublicIPPermissions = [
  'Microsoft.Network/publicIPAddresses/read'
  'Microsoft.Network/publicIPAddresses/write'
  'Microsoft.Network/publicIPAddresses/join/action'
]

resource resourceGroupAccessRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(resourceGroup().id, resourceGroupAccessCustomRole.roleName)
  properties: {
    roleName: resourceGroupAccessCustomRole.roleName
    description: resourceGroupAccessCustomRole.roleDescription
    type: 'CustomRole'
    permissions: [
      {
        actions: !agentlessScanningDeployNatGateway
          ? union(resourceGroupAccessCustomRole.roleActions, conditionalPublicIPPermissions)
          : resourceGroupAccessCustomRole.roleActions
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      resourceGroup().id
    ]
  }
}

resource rgRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, scanningPrincipalId, resourceGroupAccessRole.id)
  properties: {
    roleDefinitionId: resourceGroupAccessRole.id
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

resource scanningKeyVaultPrivateZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  location: 'global'
  name: 'privatelink.vaultcore.azure.net'
  tags: tags
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
  name: guid(subscription().id, resourceGroup().id, builtinKeyVaultSecretsUserRole.id, scannerManagedIdentity.id)
  scope: scanningKeyVault
  properties: {
    roleDefinitionId: builtinKeyVaultSecretsUserRole.id
    principalId: scannerManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource scanningKeyVaultDnsRecord 'Microsoft.Network/privateDnsZones/A@2024-06-01' = {
  parent: scanningKeyVaultPrivateZone
  name: scanningKeyVault.name
  properties: {
    aRecords: [
      {
        ipv4Address: vaultIPAddress
      }
    ]
    ttl: 10
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

output scanningKeyVaultName string = scanningKeyVault.name
output scanningManagedIdentityId string = scannerManagedIdentity.id
output scanningManagedIdentityPrincipalId string = scannerManagedIdentity.properties.principalId
