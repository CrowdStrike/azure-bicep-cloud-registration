targetScope = 'resourceGroup'

/*
  This Bicep template deploys private endpoint connecting key vault to subnet in the scanning environment
  Copyright (c) 2025 CrowdStrike, Inc.
*/

/* Parameters */
@description('Azure location (region) where subscription level scanning resources will be deployed.')
param location string

@description('Subnet ID to use for KeyVault Private Endpoint.')
param vaultSubnetId string

@description('Name of KeyVault utilized by data scanning.')
param scanningKeyVaultName string

@maxLength(10)
@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string = ''

@maxLength(10)
@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string = ''

@maxLength(4)
@description('Environment label (for example, prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Tags to be applied to all deployed resources. Used for resource organization and governance.')
param tags object

/* Variables */
var vaultIPAddress = '10.1.3.30'

var environment = length(env) > 0 ? '-${env}' : env
var vaultPrivateEndpointName = '${resourceNamePrefix}pep-csscanning-vault${environment}-${location}${resourceNameSuffix}'
var vaultPrivateLinkServiceConnectionName = '${resourceNamePrefix}plsc-csscanning-vault${environment}-${location}${resourceNameSuffix}'
var vaultIpConfigurationName = '${resourceNamePrefix}ipconfig-csscanning${environment}-${location}${resourceNameSuffix}'

resource vaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-07-01' = {
  location: location
  name: vaultPrivateEndpointName
  properties: {
    privateLinkServiceConnections: [
      {
        name: vaultPrivateLinkServiceConnectionName
        properties: {
          groupIds: [
            'vault'
          ]
          privateLinkServiceId: resourceId(
            subscription().subscriptionId,
            resourceGroup().name,
            'Microsoft.KeyVault/vaults',
            scanningKeyVaultName
          )
        }
      }
    ]
    ipConfigurations: [
      {
        name: vaultIpConfigurationName
        properties: {
          groupId: 'vault'
          memberName: 'default'
          privateIPAddress: vaultIPAddress
        }
      }
    ]
    subnet: {
      id: vaultSubnetId
    }
  }
  tags: tags
}
