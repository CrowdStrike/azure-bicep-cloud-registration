targetScope = 'managementGroup'

/*
  This Bicep template assigns the Reader role to a managed identity at the management group scope.
  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('Principal ID of the user-assigned managed identity that will execute deployment scripts. This identity needs appropriate permissions.')
param scriptRunnerIdentityId string

@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

var defaultRoleIds = [
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
]

var defaultRoleDefinitionIds = [
  for roleId in defaultRoleIds: resourceId('Microsoft.Authorization/roleDefinitions', roleId)
]
resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleDefinitionId in union(defaultRoleDefinitionIds, []): {
    name: guid(scriptRunnerIdentityId, roleDefinitionId, managementGroup().id, env)
    properties: {
      roleDefinitionId: roleDefinitionId
      principalId: scriptRunnerIdentityId
      principalType: 'ServicePrincipal'
    }
  }
]
