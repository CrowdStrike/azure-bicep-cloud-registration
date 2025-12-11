targetScope = 'resourceGroup'

/*
  This Bicep template deploys regional resources of the scanning environment
  Copyright (c) 2025 CrowdStrike, Inc.
*/

/* Parameters */
@description('Azure location (region) where subscription level scanning resources will be deployed.')
param location string

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
var vnetAddressPrefix = '10.1.0.0/22'
var clonesSubnetPrefix = '10.1.1.0/24'
var scannersSubnetPrefix = '10.1.2.0/24'
var vaultSubnetPrefix = '10.1.3.0/24'
var keyVaultPrivateZone = 'privatelink.vaultcore.azure.net'

var environment = length(env) > 0 ? '-${env}' : env
var scannersPublicIpName = '${resourceNamePrefix}pip-csscanning-scanners${environment}-${location}${resourceNameSuffix}'
var scannersNatGatewayName = '${resourceNamePrefix}ng-csscanning-scanners${environment}-${location}${resourceNameSuffix}'
var scanningNsgName = '${resourceNamePrefix}nsg-csscanning${environment}-${location}${resourceNameSuffix}'
var scanningVnetName = '${resourceNamePrefix}vnet-csscanning${environment}-${location}${resourceNameSuffix}'
var clonesSubnetName = '${resourceNamePrefix}snet-csscanning-clones${environment}-${location}${resourceNameSuffix}'
var vaultSubnetName = '${resourceNamePrefix}snet-csscanning-vault${environment}-${location}${resourceNameSuffix}'
var scannersSubnetName = '${resourceNamePrefix}snet-csscanning-scanners${environment}-${location}${resourceNameSuffix}'
var vaultVirtualLinkName = '${keyVaultPrivateZone}/${resourceNamePrefix}vnl-csscanning-vault${environment}-${location}${resourceNameSuffix}'

resource scannersPublicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  location: location
  name: scannersPublicIpName
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  sku: {
    name: 'Standard'
  }
  tags: tags
}

resource scannersNatGateway 'Microsoft.Network/natGateways@2024-07-01' = {
  location: location
  name: scannersNatGatewayName
  properties: {
    idleTimeoutInMinutes: 10
    publicIpAddresses: [
      {
        id: scannersPublicIp.id
      }
    ]
  }
  sku: {
    name: 'Standard'
  }
  tags: tags
}

resource scanningNsg 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  location: location
  name: scanningNsgName
  tags: tags
}

resource scanningVnet 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  location: location
  name: scanningVnetName
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
  }
  tags: union(tags, { CSTagResourceType: 'VirtualNetwork' })
}

resource clonesSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' = {
  parent: scanningVnet
  name: clonesSubnetName
  properties: {
    addressPrefixes: [clonesSubnetPrefix]
    defaultOutboundAccess: false
    networkSecurityGroup: {
      id: scanningNsg.id
    }
  }
}

resource vaultSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' = {
  parent: scanningVnet
  name: vaultSubnetName
  properties: {
    addressPrefixes: [vaultSubnetPrefix]
    defaultOutboundAccess: false
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
      }
    ]
    networkSecurityGroup: {
      id: scanningNsg.id
    }
  }
  dependsOn: [
    clonesSubnet // subnets cannot be deployed in parallel
  ]
}

resource scannersSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' = {
  parent: scanningVnet
  name: scannersSubnetName
  properties: {
    addressPrefixes: [scannersSubnetPrefix]
    defaultOutboundAccess: false
    natGateway: {
      id: scannersNatGateway.id
    }
    networkSecurityGroup: {
      id: scanningNsg.id
    }
  }
  dependsOn: [
    vaultSubnet // subnets cannot be deployed in parallel
  ]
}

resource vaultVirtualLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  location: 'global'
  name: vaultVirtualLinkName
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: scanningVnet.id
    }
  }
  tags: tags
}

output vaultSubnetId string = vaultSubnet.id
