targetScope='subscription'

@description('Role definition Id of the custom Crowdstrike reader role')
param customRoleDefinitionId string

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string

var defaultRoleIds = [
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
]

var defaultRoleDefinitionIds = [for roleId in defaultRoleIds: resourceId('Microsoft.Authorization/roleDefinitions', roleId)]
resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleDefinitionId in union(defaultRoleDefinitionIds, [customRoleDefinitionId]): {
    name: guid(azurePrincipalId, roleDefinitionId, subscription().id, env)
    properties: {
      roleDefinitionId: roleDefinitionId
      principalId: azurePrincipalId
      principalType: 'ServicePrincipal'
    }
  }
]
