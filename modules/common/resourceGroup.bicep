targetScope = 'subscription'

/*
  This Bicep template creates a resource group in the specified Azure subscription.
  Copyright (c) 2025 CrowdStrike, Inc.
*/

param resourceGroupName string

@description('Azure region where the resource group will be created. Should be selected based on data residency requirements and proximity to monitored resources.')
param location string

@description('Tags to be applied to the resource group. Used for resource organization, governance, and cost tracking.')
param tags object

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

output id string = resourceGroup.id
output name string = resourceGroup.name
