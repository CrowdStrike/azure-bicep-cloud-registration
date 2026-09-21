targetScope = 'resourceGroup'

/*
  This Bicep module grants the Storage File Data Privileged Contributor role on an existing
  storage account to the script runner identity, scoped to that storage account.

  Microsoft.Resources/deploymentScripts requires this role on its identity whenever
  containerSettings.subnetIds is set and an existing storage account is supplied via
  storageAccountSettings - the storage account key alone is not sufficient in that
  configuration. See https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-script-vnet-private-endpoint.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

@description('Name of the existing storage account to grant the role on.')
param storageAccountName string

@description('Principal ID of the user-assigned managed identity attached to the deployment script.')
param scriptRunnerIdentityId string

var storageFileDataPrivilegedContributorRoleId = '69566ab7-960f-475b-8e7c-b3118f30c6bd'

resource existingStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource storageFileDataRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(existingStorageAccount.id, storageFileDataPrivilegedContributorRoleId, scriptRunnerIdentityId)
  scope: existingStorageAccount
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageFileDataPrivilegedContributorRoleId)
    principalId: scriptRunnerIdentityId
    principalType: 'ServicePrincipal'
  }
}
