import {
  subscriptionAccessRolePermissions
  scannerRolePermissions
  resourceGroupAccessRolePermissions
} from '../../models/scanning-roles.bicep'

targetScope = 'managementGroup'

/*
  This Bicep template defines custom role definitions at management group scope
  for CrowdStrike Scanning, reducing the number of custom roles consumed per tenant.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

/* Parameters */
@maxLength(10)
@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string = ''

@maxLength(10)
@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string = ''

@maxLength(4)
@description('Environment label (for example, prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Whether NAT Gateway is enabled. When false, public IP permissions are included for VM connectivity.')
param agentlessScanningDeployNatGateway bool = true

/* Variables */
var subscriptionAccessRoleName = '${resourceNamePrefix}role-csscanning-access-${managementGroup().name}${resourceNameSuffix}'
var scannerRoleName = '${resourceNamePrefix}role-csscanning-scanner-${managementGroup().name}${resourceNameSuffix}'
var resourceGroupAccessRoleName = '${resourceNamePrefix}role-csscanning-rgaccess-${managementGroup().name}${resourceNameSuffix}'

/* Role Definitions */
resource subscriptionAccessRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(managementGroup().id, subscriptionAccessRoleName, env)
  properties: {
    roleName: subscriptionAccessRoleName
    description: subscriptionAccessRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: subscriptionAccessRolePermissions.actions
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
  name: guid(managementGroup().id, scannerRoleName, env)
  properties: {
    roleName: scannerRoleName
    description: scannerRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: scannerRolePermissions.actions
        notActions: []
        dataActions: scannerRolePermissions.dataActions
        notDataActions: []
      }
    ]
    assignableScopes: [
      managementGroup().id
    ]
  }
}

resource resourceGroupAccessRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(managementGroup().id, resourceGroupAccessRoleName, env)
  properties: {
    roleName: resourceGroupAccessRoleName
    description: resourceGroupAccessRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: !agentlessScanningDeployNatGateway
          ? union(
              resourceGroupAccessRolePermissions.actions,
              resourceGroupAccessRolePermissions.conditionalPublicIPActions
            )
          : resourceGroupAccessRolePermissions.actions
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
output subscriptionAccessRoleId string = subscriptionAccessRole.id
output scannerRoleId string = scannerRole.id
output resourceGroupAccessRoleId string = resourceGroupAccessRole.id
