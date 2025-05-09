@description('Resource ID of the Event Hub that CrowdStrike needs access to. This is the target Event Hub for role assignment.')
param eventHubId string

@description('Role definition ID for the Azure RBAC role to assign.')
param roleDefinitionId string

@description('Principal ID of the CrowdStrike application registered in Entra ID. This service principal will be granted the specified role on the Event Hub.')
param azurePrincipalId string


resource activityLogEventHubRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(azurePrincipalId, roleDefinitionId, eventHubId)
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: azurePrincipalId
    principalType: 'ServicePrincipal'
  }
}
