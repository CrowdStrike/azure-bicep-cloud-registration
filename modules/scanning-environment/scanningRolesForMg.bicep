import {
  accessRolePermissions
  scannerRolePermissions
  resourceGroupAccessRolePermissions
  customVnetSubnetRolePermissions
  scannerRgRolePermissions
} from '../../models/scanning-roles.bicep'

targetScope = 'managementGroup'

/*
  This Bicep template defines custom role definitions at management group scope
  for CrowdStrike Scanning.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

/* Parameters */
@maxLength(10)
@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string = ''

@maxLength(10)
@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string = ''

@description('Whether NAT Gateway is enabled. When false, public IP permissions are included for VM connectivity.')
param agentlessScanningDeployNatGateway bool = true

@description('Whether to create the resource group access role definition. Only needed for the MG containing the host subscription.')
param includeResourceGroupAccessRole bool = true

@description('Whether custom VNet subnets are used. When true, creates the custom VNet subnet access role.')
param useCustomSubnets bool = false

@description('Controls whether to enable DSPM.')
param inputEnableDspm bool = false

@description('Controls whether to enable vulnerability scanning.')
param inputEnableVulnerabilityScanning bool = false

/* Variables */
var accessRoleName = '${resourceNamePrefix}role-csscanning-access-${managementGroup().name}${resourceNameSuffix}'
var scannerRoleName = '${resourceNamePrefix}role-csscanning-scanner-${managementGroup().name}${resourceNameSuffix}'
var resourceGroupAccessRoleName = '${resourceNamePrefix}role-csscanning-rgaccess-${managementGroup().name}${resourceNameSuffix}'
var customVnetRoleName = '${resourceNamePrefix}role-csscanning-custom-vnet-${managementGroup().name}${resourceNameSuffix}'
var scannerRgRoleName = '${resourceNamePrefix}role-csscanning-scannerrg-${managementGroup().name}${resourceNameSuffix}'

/* Role Definitions */
resource accessRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(managementGroup().id, accessRoleName)
  properties: {
    roleName: accessRoleName
    description: accessRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: union(
          accessRolePermissions.baseActions,
          inputEnableDspm ? accessRolePermissions.dspmActions : [],
          inputEnableVulnerabilityScanning ? accessRolePermissions.vulnScanningActions : []
        )
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      managementGroup().id
    ]
  }
}

resource scannerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(managementGroup().id, scannerRoleName)
  properties: {
    roleName: scannerRoleName
    description: scannerRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: inputEnableDspm ? scannerRolePermissions.dspmActions : []
        notActions: []
        dataActions: inputEnableDspm ? scannerRolePermissions.dspmDataActions : []
        notDataActions: []
      }
    ]
    assignableScopes: [
      managementGroup().id
    ]
  }
}

resource resourceGroupAccessRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (includeResourceGroupAccessRole) {
  name: guid(managementGroup().id, resourceGroupAccessRoleName)
  properties: {
    roleName: resourceGroupAccessRoleName
    description: resourceGroupAccessRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: union(
          resourceGroupAccessRolePermissions.actions,
          !agentlessScanningDeployNatGateway ? resourceGroupAccessRolePermissions.conditionalPublicIPActions : [],
          inputEnableVulnerabilityScanning ? resourceGroupAccessRolePermissions.vulnScanningActions : []
        )
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      managementGroup().id
    ]
  }
}

resource customVnetSubnetRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (useCustomSubnets) {
  name: guid(managementGroup().id, 'customVnetSubnetAccess')
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
      managementGroup().id
    ]
  }
}

resource scannerRgRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (inputEnableVulnerabilityScanning && includeResourceGroupAccessRole) {
  name: guid(managementGroup().id, scannerRgRoleName)
  properties: {
    roleName: scannerRgRoleName
    description: scannerRgRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: scannerRgRolePermissions.actions
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      managementGroup().id
    ]
  }
}

/* Outputs */
output accessRoleId string = accessRole.id
output scannerRoleId string = scannerRole.id
output resourceGroupAccessRoleId string = includeResourceGroupAccessRole ? resourceGroupAccessRole.id : ''
output customVnetSubnetRoleId string = useCustomSubnets ? customVnetSubnetRole.id : ''
output scannerRgRoleId string = (inputEnableVulnerabilityScanning && includeResourceGroupAccessRole) ? scannerRgRole.id : ''
