targetScope = 'subscription'

/*
  This Bicep template creates a resource group in the specified Azure subscription.
  Copyright (c) 2025 CrowdStrike, Inc.
*/

@description('Azure region where the resource group will be created. Should be selected based on data residency requirements and proximity to monitored resources.')
param location string

@description('Name of the resource group that will be deployed.')
param resourceGroupName string

@description('Tags to be applied to the resource group. Used for resource organization, governance, and cost tracking.')
param tags object

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
  tags: union(tags, { CSTagResourceType: 'ResourceGroup' })
}

output id string = resourceGroup.id
output name string = resourceGroup.name
