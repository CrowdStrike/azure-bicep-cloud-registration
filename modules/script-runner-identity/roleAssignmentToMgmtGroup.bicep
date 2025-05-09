targetScope='managementGroup'

@description('Managed identity Id of the script runner')
param scriptRunnerIdentityId string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string

var defaultRoleIds = [
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
]

var defaultRoleDefinitionIds = [for roleId in defaultRoleIds: resourceId('Microsoft.Authorization/roleDefinitions', roleId)]
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
