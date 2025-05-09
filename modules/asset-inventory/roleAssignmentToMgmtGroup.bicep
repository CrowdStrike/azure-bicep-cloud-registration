targetScope = 'managementGroup'

/*
  This Bicep template assigns the Reader role and a custom role to the CrowdStrike service principal at the management group scope.
  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('Resource ID of the custom role definition created for CrowdStrike. This role will be assigned to the CrowdStrike service principal.')
param customRoleDefinitionId string

@description('Principal ID of the CrowdStrike application registered in Entra ID. This service principal will be granted the custom role.')
param azurePrincipalId string

@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

var defaultRoleIds = [
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
]

var defaultRoleDefinitionIds = [
  for roleId in defaultRoleIds: resourceId('Microsoft.Authorization/roleDefinitions', roleId)
]
resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleDefinitionId in union(defaultRoleDefinitionIds, [customRoleDefinitionId]): {
    name: guid(azurePrincipalId, roleDefinitionId, managementGroup().id, env)
    properties: {
      roleDefinitionId: roleDefinitionId
      principalId: azurePrincipalId
      principalType: 'ServicePrincipal'
    }
  }
]
