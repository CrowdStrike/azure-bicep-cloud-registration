@description('Name of the user assigned identity')
param name string

@description('Azure region for the resources deployed in this solution.')
param region string

@description('Tags to be applied to all resources.')
param tags object

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: region
  tags: tags
}

output id string = managedIdentity.id
output name string = managedIdentity.name
output clientId string = managedIdentity.properties.clientId
output principalId string = managedIdentity.properties.principalId
