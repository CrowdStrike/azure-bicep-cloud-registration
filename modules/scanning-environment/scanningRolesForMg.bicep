import {
  accessRolePermissions
  scannerRolePermissions
  resourceGroupAccessRolePermissions
  customVnetSubnetRolePermissions
  resourceGroupScannerRolePermissions
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

@description('Whether to create the resource group role definitions. Only needed for the MG containing the host subscription.')
param includeResourceGroupRoles bool = true

@description('Whether custom VNet subnets are used. When true, creates the custom VNet subnet access role.')
param useCustomSubnets bool = false

@description('Controls whether to enable DSPM.')
param inputEnableDspm bool = false

@description('Controls whether to enable vulnerability scanning.')
param inputEnableVulnerabilityScanning bool = false

/* Variables */
var accessRoleName = '${resourceNamePrefix}role-csscanning-access-${managementGroup().name}${resourceNameSuffix}'
var scannerRoleName = '${resourceNamePrefix}role-csscanning-scanner-${managementGroup().name}${resourceNameSuffix}'
var resourceGroupAccessRoleName = '${resourceNamePrefix}role-csscanning-rg-access-${managementGroup().name}${resourceNameSuffix}'
var customVnetRoleName = '${resourceNamePrefix}role-csscanning-custom-vnet-${managementGroup().name}${resourceNameSuffix}'
var resourceGroupScannerRoleName = '${resourceNamePrefix}role-csscanning-rg-scanner-${managementGroup().name}${resourceNameSuffix}'

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
          inputEnableVulnerabilityScanning ? accessRolePermissions.vulnerabilityScanningActions : []
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

resource scannerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (inputEnableDspm) {
  name: guid(managementGroup().id, scannerRoleName)
  properties: {
    roleName: scannerRoleName
    description: scannerRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: scannerRolePermissions.dspmActions
        notActions: []
        dataActions: scannerRolePermissions.dspmDataActions
        notDataActions: []
      }
    ]
    assignableScopes: [
      managementGroup().id
    ]
  }
}

resource resourceGroupAccessRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (includeResourceGroupRoles) {
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
          inputEnableVulnerabilityScanning ? resourceGroupAccessRolePermissions.vulnerabilityScanningActions : []
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

resource resourceGroupScannerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (inputEnableVulnerabilityScanning && includeResourceGroupRoles) {
  name: guid(managementGroup().id, resourceGroupScannerRoleName)
  properties: {
    roleName: resourceGroupScannerRoleName
    description: resourceGroupScannerRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: resourceGroupScannerRolePermissions.actions
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
output scannerRoleId string = inputEnableDspm ? scannerRole.id : ''
output resourceGroupAccessRoleId string = includeResourceGroupRoles ? resourceGroupAccessRole.id : ''
output customVnetSubnetRoleId string = useCustomSubnets ? customVnetSubnetRole.id : ''
output resourceGroupScannerRoleId string = (inputEnableVulnerabilityScanning && includeResourceGroupRoles)
  ? resourceGroupScannerRole.id
  : ''
