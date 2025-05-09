import {ActivityLogSettings, EntraIdLogSettings} from '../../models/real-time-visibility-detection.bicep'

@description('Eventhub Resource ID')
param eventHubId string

@description('role definition ID')
param roleDefinitionId string

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string


resource activityLogEventHubRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(azurePrincipalId, roleDefinitionId, eventHubId)
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: azurePrincipalId
    principalType: 'ServicePrincipal'
  }
}
