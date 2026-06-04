import {
  accessRolePermissions
  scannerRolePermissions
  resourceGroupAccessRolePermissions
  customVnetSubnetRolePermissions
  scannerRgRolePermissions
} from '../../models/scanning-roles.bicep'

targetScope = 'subscription'

/*
  This Bicep template defines custom role definitions at subscription scope
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

@description('Whether to create the resource group role definitions. Only needed for the host subscription.')
param includeResourceGroupRoles bool = true

@description('Whether custom VNet subnets are used. When true, creates the custom VNet subnet access role.')
param useCustomSubnets bool = false

@description('Controls whether to enable DSPM.')
param inputEnableDspm bool = false

@description('Controls whether to enable vulnerability scanning.')
param inputEnableVulnerabilityScanning bool = false

/* Variables */
var accessRoleName = '${resourceNamePrefix}role-csscanning-access-${subscription().subscriptionId}${resourceNameSuffix}'
var scannerRoleName = '${resourceNamePrefix}role-csscanning-scanner-${subscription().subscriptionId}${resourceNameSuffix}'
var resourceGroupAccessRoleName = '${resourceNamePrefix}role-csscanning-rgaccess-${subscription().subscriptionId}${resourceNameSuffix}'
var customVnetRoleName = '${resourceNamePrefix}role-csscanning-custom-vnet-${subscription().subscriptionId}${resourceNameSuffix}'
var scannerRgRoleName = '${resourceNamePrefix}role-csscanning-rgscanner-${subscription().subscriptionId}${resourceNameSuffix}'

/* Role Definitions */
resource accessRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, accessRoleName)
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
      subscription().id
    ]
  }
}

resource scannerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, scannerRoleName)
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
      subscription().id
    ]
  }
}

resource resourceGroupAccessRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (includeResourceGroupRoles) {
  name: guid(subscription().id, resourceGroupAccessRoleName)
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
      subscription().id
    ]
  }
}

// Custom VNet role applies only to the host subscription (single sub) — no need for MG-scoped definition
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

resource scannerRgRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (inputEnableVulnerabilityScanning && includeResourceGroupRoles) {
  name: guid(subscription().id, scannerRgRoleName)
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
      subscription().id
    ]
  }
}

/* Outputs */
output accessRoleId string = accessRole.id
output scannerRoleId string = scannerRole.id
output resourceGroupAccessRoleId string = includeResourceGroupRoles ? resourceGroupAccessRole.id : ''
output customVnetSubnetRoleId string = useCustomSubnets ? customVnetSubnetRole.id : ''
output resourceGroupScannerRoleId string = (inputEnableVulnerabilityScanning && includeResourceGroupRoles) ? scannerRgRole.id : ''
