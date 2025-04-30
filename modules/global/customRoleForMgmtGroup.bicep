targetScope='managementGroup'
/*
  This Bicep template defines the required permissions at Azure management group scope to enable CrowdStrike
  Indicator of Misconfiguration (IOM)
  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('The prefix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs'

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = ''

var customRole = {
  roleName: 'cs-website-reader'
  roleDescription: 'CrowdStrike custom role to allow read access to App Service and Function.'
  roleActions: [
    'Microsoft.Web/sites/Read'
    'Microsoft.Web/sites/config/Read'
    'Microsoft.Web/sites/config/list/Action'
  ]
}

resource customRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(customRole.roleName, tenant().tenantId, managementGroup().id)
  properties: {
    assignableScopes: [managementGroup().id]
    description: customRole.roleDescription
    permissions: [
      {
        actions: customRole.roleActions
        notActions: []
      }
    ]
    roleName: '${deploymentNamePrefix}-${customRole.roleName}-${managementGroup().name}-${deploymentNameSuffix}'
    type: 'CustomRole'
  }
}

output id string = customRoleDefinition.id
