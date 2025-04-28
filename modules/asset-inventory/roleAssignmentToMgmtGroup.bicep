targetScope='managementGroup'

@description('The prefix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs'

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = ''

param customRoleDefinitionId string

@description('Principal Id of the Application Registration in Entra ID.')
param azurePrincipalId string

@description('Type of the Principal, defaults to ServicePrincipal.')
param azurePrincipalType string = 'ServicePrincipal'

var defaultRoleIds = [
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
  '39bc4728-0917-49c7-9d2c-d95423bc2eb4' // Security Reader
  '21090545-7ca7-4776-b22c-e363652d74d2' // Key Vault Reader
  '7f6c6a51-bcf8-42ba-9220-52d62157d7db' // Azure Kubernetes Service RBAC Reader
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
