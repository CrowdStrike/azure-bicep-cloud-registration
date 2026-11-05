import {
  DspmAccessScopes
  needsScannerRole
  accessRolePermissions
  scannerRolePermissions
  resourceGroupAccessRolePermissions
  customVnetSubnetRolePermissions
  resourceGroupScannerRolePermissions
} from '../../models/scanning-roles.bicep'

targetScope = 'subscription'

/*
  This Bicep template defines custom role definitions at subscription scope
  for CrowdStrike Scanning.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

/* Parameters */
@maxLength(10)
@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string = ''

@maxLength(10)
@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string = ''

@description('Whether NAT Gateway is enabled. When false, public IP permissions are included for VM connectivity.')
param agentlessScanningDeployNatGateway bool = true

@description('Whether to create the resource group role definitions. Only needed for the host subscription.')
param includeResourceGroupRoles bool = true

@description('Whether custom VNet subnets are used. When true, creates the custom VNet subnet access role.')
param useCustomSubnets bool = false

@description('DSPM datastores to apply permissions for, all false when DSPM is disabled.')
param inputDspmAccessScopes DspmAccessScopes

@description('Controls whether to enable vulnerability scanning.')
param inputEnableVulnerabilityScanning bool = false

/* Variables */
var accessRoleName = '${resourceNamePrefix}role-csscanning-access-${subscription().subscriptionId}${resourceNameSuffix}'
var scannerRoleName = '${resourceNamePrefix}role-csscanning-scanner-${subscription().subscriptionId}${resourceNameSuffix}'
var resourceGroupAccessRoleName = '${resourceNamePrefix}role-csscanning-rg-access-${subscription().subscriptionId}${resourceNameSuffix}'
var customVnetRoleName = '${resourceNamePrefix}role-csscanning-custom-vnet-${subscription().subscriptionId}${resourceNameSuffix}'
var resourceGroupScannerRoleName = '${resourceNamePrefix}role-csscanning-rg-scanner-${subscription().subscriptionId}${resourceNameSuffix}'

/* Role Definitions */
resource accessRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, accessRoleName)
  properties: {
    roleName: accessRoleName
    description: accessRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: union(
          accessRolePermissions.baseActions,
          needsScannerRole(inputDspmAccessScopes) ? accessRolePermissions.dspmStorageAccountActions : [],
          inputDspmAccessScopes.azureSql ? accessRolePermissions.dspmAzureSqlActions : [],
          (inputDspmAccessScopes.virtualMachines || inputEnableVulnerabilityScanning)
            ? accessRolePermissions.virtualMachinesScanningActions
            : []
        )
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

resource scannerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (needsScannerRole(inputDspmAccessScopes)) {
  name: guid(subscription().id, scannerRoleName)
  properties: {
    roleName: scannerRoleName
    description: scannerRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: union(
          inputDspmAccessScopes.blobStorage ? scannerRolePermissions.dspmBlobStorageActions : [],
          inputDspmAccessScopes.tableStorage ? scannerRolePermissions.dspmTableStorageActions : [],
          inputDspmAccessScopes.azureFiles ? scannerRolePermissions.dspmAzureFilesActions : []
        )
        notActions: []
        dataActions: union(
          inputDspmAccessScopes.blobStorage ? scannerRolePermissions.dspmBlobStorageDataActions : [],
          inputDspmAccessScopes.tableStorage ? scannerRolePermissions.dspmTableStorageDataActions : [],
          inputDspmAccessScopes.azureFiles ? scannerRolePermissions.dspmAzureFilesDataActions : []
        )
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

resource resourceGroupAccessRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (includeResourceGroupRoles) {
  name: guid(subscription().id, resourceGroupAccessRoleName)
  properties: {
    roleName: resourceGroupAccessRoleName
    description: resourceGroupAccessRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: union(
          resourceGroupAccessRolePermissions.actions,
          !agentlessScanningDeployNatGateway ? resourceGroupAccessRolePermissions.conditionalPublicIPActions : [],
          (inputDspmAccessScopes.virtualMachines || inputEnableVulnerabilityScanning)
            ? resourceGroupAccessRolePermissions.virtualMachinesScanningActions
            : [],
          inputDspmAccessScopes.azureSql ? resourceGroupAccessRolePermissions.dspmAzureSqlActions : []
        )
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

// Custom VNet role applies only to the host subscription (single sub) — no need for MG-scoped definition
resource customVnetSubnetRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (useCustomSubnets) {
  name: guid(subscription().id, 'customVnetSubnetAccess')
  properties: {
    roleName: customVnetRoleName
    description: customVnetSubnetRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: customVnetSubnetRolePermissions.actions
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

resource resourceGroupScannerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = if (includeResourceGroupRoles) {
  name: guid(subscription().id, resourceGroupScannerRoleName)
  properties: {
    roleName: resourceGroupScannerRoleName
    description: resourceGroupScannerRolePermissions.description
    type: 'CustomRole'
    permissions: [
      {
        actions: resourceGroupScannerRolePermissions.actions
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

/* Outputs */
output accessRoleId string = accessRole.id
output scannerRoleId string = needsScannerRole(inputDspmAccessScopes) ? scannerRole.id : ''
output resourceGroupAccessRoleId string = includeResourceGroupRoles ? resourceGroupAccessRole.id : ''
output customVnetSubnetRoleId string = useCustomSubnets ? customVnetSubnetRole.id : ''
output resourceGroupScannerRoleId string = includeResourceGroupRoles ? resourceGroupScannerRole.id : ''
