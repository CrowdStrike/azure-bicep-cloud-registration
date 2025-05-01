targetScope='subscription'
/*
  This Bicep template defines the required permissions at Azure Subscription scope to enable CrowdStrike
  Indicator of Misconfiguration (IOM)
  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('The prefix to be added to the deployment name.')
param prefix string

@description('The suffix to be added to the deployment name.')
param suffix string

param subscriptionIds array

var customRole = {
  roleName: 'cs-website-reader'
  roleDescription: 'CrowdStrike custom role to allow read access to App Service and Function.'
  roleActions: [
    'Microsoft.Web/sites/Read'
    'Microsoft.Web/sites/config/Read'
    'Microsoft.Web/sites/config/list/Action'
  ]
}

var fullPathSubscriptionIds = [for subId in subscriptionIds: '/subscriptions/${subId}']


resource customRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(customRole.roleName, tenant().tenantId, subscription().id)
  properties: {
    assignableScopes: fullPathSubscriptionIds
    description: customRole.roleDescription
    permissions: [
      {
        actions: customRole.roleActions
        notActions: []
      }
    ]
    roleName: '${prefix}${customRole.roleName}-sub${suffix}'
    type: 'CustomRole'
  }
}

output id string = customRoleDefinition.id
