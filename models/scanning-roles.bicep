/*
  This Bicep template defines shared role permission definitions for CrowdStrike Scanning.
  Single source of truth for all scanning role permissions used by both management group
  and subscription deployment paths.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

@export()
@sealed()
@description('DSPM datastores to apply permissions for. Omitted datastores default to true.')
type DspmAccessScopesInput = {
  @description('Apply permissions for DSPM Blob Storage scanning.')
  blobStorage: bool?

  @description('Apply permissions for DSPM Table Storage scanning.')
  tableStorage: bool?

  @description('Apply permissions for DSPM Azure Files scanning.')
  azureFiles: bool?

  @description('Apply permissions for DSPM virtual machine scanning. Vulnerability scanning grants the same permissions on its own.')
  virtualMachines: bool?

  @description('Apply permissions for DSPM Azure SQL Database scanning.')
  azureSql: bool?
}

@export()
@description('DSPM datastores to apply permissions for, all false when DSPM is disabled.')
type DspmAccessScopes = {
  blobStorage: bool
  tableStorage: bool
  azureFiles: bool
  virtualMachines: bool
  azureSql: bool
}

@export()
@description('Resolves which DSPM datastores get permissions: those not set to false, and none when DSPM is disabled.')
func resolveDspmAccessScopes(enableDspm bool, scopes DspmAccessScopesInput) DspmAccessScopes => {
  blobStorage: enableDspm && (scopes.?blobStorage ?? true)
  tableStorage: enableDspm && (scopes.?tableStorage ?? true)
  azureFiles: enableDspm && (scopes.?azureFiles ?? true)
  virtualMachines: enableDspm && (scopes.?virtualMachines ?? true)
  azureSql: enableDspm && (scopes.?azureSql ?? true)
}

@export()
@description('Whether the Scanner role is needed. The Scanner role holds only Storage Account permissions.')
func needsScannerRole(scopes DspmAccessScopes) bool => scopes.blobStorage || scopes.tableStorage || scopes.azureFiles

@export()
@description('Permissions for the CrowdStrike Agentless Scanning Access Role.')
var accessRolePermissions = {
  description: 'CrowdStrike Agentless Scanning Access Role'
  baseActions: [
    // ============ Validation ============
    'Microsoft.Authorization/roleAssignments/read'
    'Microsoft.Authorization/policyDefinitions/read'
  ]
  dspmStorageAccountActions: [
    // ============ Storage Accounts ============
    'Microsoft.Storage/storageAccounts/read' // Check location and public access
    'Microsoft.Storage/storageAccounts/PrivateEndpointConnectionsApproval/action' // Approve private link connections
  ]
  dspmAzureSqlActions: [
    // ============ Azure SQL ============
    'Microsoft.Sql/servers/databases/write' // Copy a source database into the host scanning resource group
  ]
  virtualMachinesScanningActions: [
    // ============ Virtual Machines ============
    'Microsoft.Compute/disks/beginGetAccess/action' // Access source disk for snapshot
    'Microsoft.Compute/disks/read' // Read source disk metadata
    'Microsoft.Compute/virtualMachines/read' // Read VM metadata
    'Microsoft.Compute/virtualMachineScaleSets/read' // Read VMSS metadata
    'Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read' // Read VMSS instance metadata
  ]
}

@export()
@description('Permissions for the CrowdStrike Agentless Scanning Scanner Role.')
var scannerRolePermissions = {
  description: 'CrowdStrike Agentless Scanning Scanner Role'
  dspmBlobStorageActions: [
    'Microsoft.Storage/storageAccounts/blobServices/containers/read'
  ]
  dspmBlobStorageDataActions: [
    'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'
  ]
  dspmTableStorageActions: [
    'Microsoft.Storage/storageAccounts/tableServices/tables/read'
  ]
  dspmTableStorageDataActions: [
    'Microsoft.Storage/storageAccounts/tableServices/tables/entities/read'
  ]
  dspmAzureFilesActions: [
    'Microsoft.Storage/storageAccounts/fileServices/shares/read'
  ]
  dspmAzureFilesDataActions: [
    'Microsoft.Storage/storageAccounts/fileServices/fileshares/files/read'
    'Microsoft.Storage/storageAccounts/fileServices/readFileBackupSemantics/action'
  ]
}

@export()
@description('Permissions for the CrowdStrike Agentless Scanning Resource Group Access Role.')
var resourceGroupAccessRolePermissions = {
  description: 'CrowdStrike Agentless Scanning Resource Group Access Role'
  actions: [
    // ============ Common ============
    // Private Endpoint
    'Microsoft.Network/privateEndpoints/read'
    'Microsoft.Network/privateEndpoints/write'
    'Microsoft.Network/privateEndpoints/delete'
    'Microsoft.Network/virtualNetworks/subnets/join/action'

    // ============ Scanner VM ============
    'Microsoft.Network/networkSecurityGroups/read'
    'Microsoft.Network/networkSecurityGroups/write'
    'Microsoft.Network/networkSecurityGroups/delete'
    'Microsoft.Network/networkInterfaces/read'
    'Microsoft.Network/networkInterfaces/write'
    'Microsoft.Network/networkInterfaces/delete'
    'Microsoft.Network/networkInterfaces/join/action'
    'Microsoft.Compute/virtualMachines/read'
    'Microsoft.Compute/virtualMachines/write'
    'Microsoft.Compute/virtualMachines/delete'
    'Microsoft.Network/virtualNetworks/read'
    'Microsoft.ManagedIdentity/userAssignedIdentities/read'
    'Microsoft.ManagedIdentity/userAssignedIdentities/assign/action'
    'Microsoft.Resources/deployments/read'
    'Microsoft.Resources/deployments/write'
    'Microsoft.Resources/deployments/delete'
    'Microsoft.Resources/deployments/operationStatuses/read'
    'Microsoft.Resources/deploymentStacks/*'
    // Always include delete permission for public IPs
    'Microsoft.Network/publicIPAddresses/delete'

    // ============ Validation ============
    'Microsoft.Network/virtualNetworks/subnets/read'
    'Microsoft.Resources/deployments/whatIf/action'
    'Microsoft.Resources/deployments/validate/action'
    'Microsoft.Resources/deploymentScripts/read'
    'Microsoft.KeyVault/vaults/read'
    'Microsoft.Compute/virtualMachines/retrieveBootDiagnosticsData/action'
    'Microsoft.Authorization/locks/read'
  ]
  conditionalPublicIPActions: [
    'Microsoft.Network/publicIPAddresses/read'
    'Microsoft.Network/publicIPAddresses/write'
    'Microsoft.Network/publicIPAddresses/join/action'
  ]
  virtualMachinesScanningActions: [
    'Microsoft.Compute/snapshots/read'
    'Microsoft.Compute/snapshots/write'
    'Microsoft.Compute/snapshots/delete'
    'Microsoft.Compute/disks/write'
    'Microsoft.Compute/disks/delete'
  ]
  dspmAzureSqlActions: [
    // ============ Azure SQL ============
    'Microsoft.Sql/servers/write'
    'Microsoft.Sql/servers/databases/write'
    'Microsoft.Sql/servers/privateEndpointConnectionsApproval/action'
    'Microsoft.Sql/servers/delete'
    'Microsoft.Sql/servers/databases/delete'
  ]
}

@export()
@description('Permissions for the CrowdStrike Agentless Scanning Custom VNet Subnet Access Role.')
var customVnetSubnetRolePermissions = {
  description: 'CrowdStrike Agentless Scanning Custom VNet Subnet Access Role'
  actions: [
    'Microsoft.Network/virtualNetworks/subnets/join/action'
    'Microsoft.Network/virtualNetworks/read'
    'Microsoft.Network/virtualNetworks/subnets/read'
  ]
}

@export()
@description('Permissions for the CrowdStrike Agentless Scanning Scanner Resource Group Role.')
var resourceGroupScannerRolePermissions = {
  description: 'CrowdStrike Agentless Scanning Scanner Resource Group Role'
  actions: [
    'Microsoft.Compute/virtualMachines/attachDetachDataDisks/action'
  ]
}
