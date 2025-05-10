targetScope = 'subscription'

param roleId string

resource existingCustomRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: roleId
}

output assignableScopes array = existingCustomRoleDefinition.properties.assignableScopes
