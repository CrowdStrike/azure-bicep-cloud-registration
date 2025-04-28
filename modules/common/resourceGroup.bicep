targetScope='subscription'

param resourceGroupName string

param location string

param tags object = {}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

output id string = resourceGroup.id
output name string = resourceGroup.name
