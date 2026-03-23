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

@description('Controls whether to deploy NAT Gateway for scanning environment.')
param agentlessScanningDeployNatGateway bool = true

@description('Optional existing custom scanners subnet ID to use instead of creating a new one.')
param customScannersSubnet string = ''

@description('Optional existing custom clones subnet ID to use instead of creating a new one.')
param customClonesSubnet string = ''


/* Variables */
var useCustomSubnets = !empty(customClonesSubnet) && !empty(customScannersSubnet) && !empty(customVaultSubnet)
var vnetAddressPrefix = '10.1.0.0/22'
var clonesSubnetPrefix = '10.1.1.0/24'
var scannersSubnetPrefix = '10.1.2.0/24'

var environment = length(env) > 0 ? '-${env}' : env
var scannersPublicIpName = '${resourceNamePrefix}pip-csscanning-scanners${environment}-${location}${resourceNameSuffix}'
var scannersNatGatewayName = '${resourceNamePrefix}ng-csscanning-scanners${environment}-${location}${resourceNameSuffix}'
var scanningNsgName = '${resourceNamePrefix}nsg-csscanning${environment}-${location}${resourceNameSuffix}'
var scanningVnetName = '${resourceNamePrefix}vnet-csscanning${environment}-${location}${resourceNameSuffix}'
var clonesSubnetName = '${resourceNamePrefix}snet-csscanning-clones${environment}-${location}${resourceNameSuffix}'
var scannersSubnetName = '${resourceNamePrefix}snet-csscanning-scanners${environment}-${location}${resourceNameSuffix}'
var vaultVirtualLinkName = useCustomSubnets
  ? '${keyVaultPrivateZone}/${resourceNamePrefix}vnl-csscanning-vault-custom${environment}-${location}${resourceNameSuffix}'
  : '${keyVaultPrivateZone}/${resourceNamePrefix}vnl-csscanning-vault${environment}-${location}${resourceNameSuffix}'

// Reference existing custom VNet and subnets if provided (all 3 custom subnets must be provided)
resource existingCustomVnet 'Microsoft.Network/virtualNetworks@2024-07-01' existing = if (useCustomSubnets) {
  name: split(customClonesSubnet, '/')[8]
  scope: resourceGroup(split(customClonesSubnet, '/')[2], split(customClonesSubnet, '/')[4])
}

resource existingClonesSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = if (useCustomSubnets) {
  name: split(customClonesSubnet, '/')[10]
  parent: existingCustomVnet
}

resource existingScannersSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = if (useCustomSubnets) {
  name: split(customScannersSubnet, '/')[10]
  parent: existingCustomVnet
}

resource scannersPublicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = if (agentlessScanningDeployNatGateway) {
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

resource scannersNatGateway 'Microsoft.Network/natGateways@2024-07-01' = if (agentlessScanningDeployNatGateway && !useCustomSubnets) {
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

resource scanningNsg 'Microsoft.Network/networkSecurityGroups@2024-07-01' = if (!useCustomSubnets) {
  location: location
  name: scanningNsgName
  tags: tags
}

resource scanningVnet 'Microsoft.Network/virtualNetworks@2024-07-01' = if (!useCustomSubnets) {
  location: location
  name: scanningVnetName
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
  }
  tags: union(tags, { CSTagResourceType: 'VirtualNetwork' })
}

resource clonesSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' = if (!useCustomSubnets) {
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

resource scannersSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' = if (!useCustomSubnets) {
  parent: scanningVnet
  name: scannersSubnetName
  properties: {
    addressPrefixes: [scannersSubnetPrefix]
    defaultOutboundAccess: false
    natGateway: agentlessScanningDeployNatGateway
      ? {
          id: scannersNatGateway.id
        }
      : null
    networkSecurityGroup: {
      id: scanningNsg.id
    }
  }
  dependsOn: [
    clonesSubnet // subnets cannot be deployed in parallel
  ]
}

output clonesSubnetId string = clonesSubnet.id
