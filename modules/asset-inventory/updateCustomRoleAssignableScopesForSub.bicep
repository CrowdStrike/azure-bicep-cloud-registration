targetScope = 'subscription'
/*
  This Bicep template defines the required permissions at Azure Subscription scope to enable CrowdStrike
  Asset Inventory
  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string

@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string

@description('List of Azure subscription IDs to monitor. These subscriptions will be configured for CrowdStrike monitoring.')
param subscriptionIds array

@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

var customRole = {
  roleName: 'role-csreader'
  roleDescription: 'CrowdStrike custom role to allow read access to App Service and Function.'
  roleActions: [
    'Microsoft.Web/sites/Read'
    'Microsoft.Web/sites/config/Read'
    'Microsoft.Web/sites/config/list/Action'
  ]
}
var environment = length(env) > 0 ? '-${env}' : env
var fullPathSubscriptionIds = [for subId in subscriptionIds: '/subscriptions/${subId}']
var roleName = '${resourceNamePrefix}${customRole.roleName}-sub${resourceNameSuffix}'
var roleId = guid(roleName, tenant().tenantId, subscription().id, env)

module existingAssignableScopes 'customRoleAssignableScopesForSub.bicep' = {
  name: '${resourceNamePrefix}cs-inv-role-csreader-scope${environment}${resourceNameSuffix}'
  params: {
    roleId: roleId
  }
}

resource customRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: roleId
  properties: {
    assignableScopes: union(existingAssignableScopes.outputs.assignableScopes, fullPathSubscriptionIds)
    description: customRole.roleDescription
    permissions: [
      {
        actions: customRole.roleActions
        notActions: []
      }
    ]
    roleName: roleName
    type: 'CustomRole'
  }
}

output id string = customRoleDefinition.id
output name string = customRoleDefinition.properties.roleName
