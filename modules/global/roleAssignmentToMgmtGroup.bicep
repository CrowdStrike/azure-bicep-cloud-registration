targetScope='managementGroup'

@description('The prefix to be added to the deployment name.')
param prefix string

@description('The suffix to be added to the deployment name.')
param suffix string

param customRoleDefinitionId string

param scriptRunnerIdentityId string

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string

@description('Type of the Principal, defaults to ServicePrincipal.')
param azurePrincipalType string

var defaultRoleIds = [
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
]

var defaultRoleDefinitionIds = [for roleId in defaultRoleIds: resourceId('Microsoft.Authorization/roleDefinitions', roleId)]
resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleDefinitionId in union(defaultRoleDefinitionIds, [customRoleDefinitionId]): {
    name: guid(azurePrincipalId, roleDefinitionId, managementGroup().id)
    properties: {
      roleDefinitionId: roleDefinitionId
      principalId: azurePrincipalId
      principalType: azurePrincipalType
    }
  }
]

var ReaderRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
resource activityLogIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(scriptRunnerIdentityId, ReaderRoleId, managementGroup().id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', ReaderRoleId)
    principalId: scriptRunnerIdentityId
    principalType: azurePrincipalType
  }
}
