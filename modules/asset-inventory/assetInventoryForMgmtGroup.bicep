targetScope = 'managementGroup'

/*
  This Bicep template deploys infrastructure to enable CrowdStrike Asset Inventory
  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string

@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string

@description('Principal ID of the CrowdStrike application registered in Entra ID. This service principal will be granted necessary permissions.')
param azurePrincipalId string

@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

var environment = length(env) > 0 ? '-${env}' : env

/* Define required permissions at Azure Management Group scope */
module customRole 'customRoleForMgmtGroup.bicep' = {
  name: '${resourceNamePrefix}cs-inv-csreader-role-mg${environment}${resourceNameSuffix}'
  params: {
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    env: env
  }
}

module roleAssignment 'roleAssignmentToMgmtGroup.bicep' = {
  name: '${resourceNamePrefix}cs-inv-ra-mg${environment}${resourceNameSuffix}'
  params: {
    azurePrincipalId: azurePrincipalId
    customRoleDefinitionId: customRole.outputs.id
    env: env
  }
}

output customRoleName string = customRole.outputs.name
