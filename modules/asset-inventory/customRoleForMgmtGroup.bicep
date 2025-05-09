targetScope='managementGroup'
/*
  This Bicep template defines the required permissions at Azure management group scope to enable CrowdStrike
  Indicator of Misconfiguration (IOM)
  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('The prefix to be added to the resource name.')
param resourceNamePrefix string

@description('The suffix to be added to the resource name.')
param resourceNameSuffix string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
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

var roleName = '${resourceNamePrefix}${customRole.roleName}-${managementGroup().name}${resourceNameSuffix}'
resource customRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(roleName, tenant().tenantId, managementGroup().id, env)
  properties: {
    assignableScopes: [managementGroup().id]
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
output name string = customRoleDefinition.name
