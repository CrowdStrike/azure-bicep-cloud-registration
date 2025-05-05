targetScope='subscription'

param resourceGroupName string

@description('Azure region for the resources deployed in this solution.')
param region string

@description('Tags to be applied to all resources.')
param tags object

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: region
  tags: tags
}

output id string = resourceGroup.id
output name string = resourceGroup.name
