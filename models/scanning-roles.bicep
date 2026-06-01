/*
  This Bicep template defines shared role permission definitions for CrowdStrike Scanning.
  Single source of truth for all scanning role permissions used by both management group
  and subscription deployment paths.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

@export()
@description('Permissions for the CrowdStrike Agentless Scanning Access Role.')
var accessRolePermissions = {
  description: 'CrowdStrike Agentless Scanning Access Role'
  baseActions: [
    // ============ Validation ============
    'Microsoft.Authorization/roleAssignments/read'
    'Microsoft.Authorization/policyDefinitions/read'
  ]
  dspmActions: [
    // ============ Blob Storage ============
    'Microsoft.Storage/storageAccounts/read' // Check location and public access
    'Microsoft.Storage/storageAccounts/PrivateEndpointConnectionsApproval/action' // Approve private link connections
  ]
  vulnScanningActions: [
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
  dspmActions: [
    'Microsoft.Storage/storageAccounts/blobServices/containers/read'
  ]
  dspmDataActions: [
    'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'
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
  ]
  conditionalPublicIPActions: [
    'Microsoft.Network/publicIPAddresses/read'
    'Microsoft.Network/publicIPAddresses/write'
    'Microsoft.Network/publicIPAddresses/join/action'
  ]
  vulnScanningActions: [
    'Microsoft.Compute/snapshots/write' // Create snapshot in our RG
    'Microsoft.Compute/snapshots/read' // Read snapshot in our RG
    'Microsoft.Compute/disks/write' // Create disk from snapshot
    'Microsoft.Compute/disks/delete' // Cleanup disk
    'Microsoft.Compute/snapshots/delete' // Cleanup snapshot
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
@description('Permissions for the CrowdStrike Agentless Scanning Scanner Resource Group Role (vulnerability scanning).')
var scannerRgRolePermissions = {
  description: 'CrowdStrike Agentless Scanning Scanner Resource Group Role'
  actions: [
    'Microsoft.Compute/virtualMachines/write'
    'Microsoft.Compute/virtualMachines/read'
    'Microsoft.Network/networkInterfaces/join/action'
    'Microsoft.Compute/disks/write'
    'Microsoft.ManagedIdentity/userAssignedIdentities/assign/action'
    'Microsoft.Compute/virtualMachines/attachDetachDataDisks/action'
  ]
}
