import {
  accessRolePermissions
  scannerRolePermissions
  resourceGroupAccessRolePermissions
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

@maxLength(4)
@description('Environment label (for example, prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Whether NAT Gateway is enabled. When false, public IP permissions are included for VM connectivity.')
param agentlessScanningDeployNatGateway bool = true

/* Variables */
var accessRoleName = '${resourceNamePrefix}role-csscanning-access-${subscription().subscriptionId}${resourceNameSuffix}'
var scannerRoleName = '${resourceNamePrefix}role-csscanning-scanner-${subscription().subscriptionId}${resourceNameSuffix}'
var resourceGroupAccessRoleName = '${resourceNamePrefix}role-csscanning-rgaccess-${subscription().subscriptionId}${resourceNameSuffix}'

/* Role Definitions */
resource accessRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, accessRoleName, env)
  properties: {
    roleName: accessRoleName
    description: accessRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: accessRolePermissions.actions
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
  name: guid(subscription().id, scannerRoleName, env)
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
      subscription().id
    ]
  }
}

resource resourceGroupAccessRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, resourceGroupAccessRoleName, env)
  properties: {
    roleName: resourceGroupAccessRoleName
    description: resourceGroupAccessRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: union(
          resourceGroupAccessRolePermissions.actions,
          !agentlessScanningDeployNatGateway ? resourceGroupAccessRolePermissions.conditionalPublicIPActions : []
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

/* Outputs */
output accessRoleId string = accessRole.id
output scannerRoleId string = scannerRole.id
output resourceGroupAccessRoleId string = resourceGroupAccessRole.id
