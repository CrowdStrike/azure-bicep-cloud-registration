targetScope = 'resourceGroup'

/*
  This Bicep module creates both role definition AND role assignment for CrowdStrike scanning subnet access
  Copyright (c) 2025 CrowdStrike, Inc.
*/

@description('Principal ID of the CrowdStrike service principal.')
param scanningPrincipalId string

param customVnetSubnetRoleId string

@description('The subnet resource ID to scope the role assignment to.')
param subnetResourceId string

// Reference the existing VNet
resource existingVnet 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  name: split(subnetResourceId, '/')[8]
}

// Reference the existing subnet
resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = {
  name: split(subnetResourceId, '/')[10]
  parent: existingVnet
}

// Create role assignment using the custom role, scoped to the specific subnet
resource customVnetRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subnetResourceId, 'customVnetAccess', scanningPrincipalId)
  scope: existingSubnet
  properties: {
    roleDefinitionId: customVnetSubnetRoleId
    principalId: scanningPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = customVnetRoleAssignment.id