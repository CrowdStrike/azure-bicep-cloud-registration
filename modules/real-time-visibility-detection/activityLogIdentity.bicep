param activityLogIdentityName string
param location string = resourceGroup().location
param tags object = {}

resource activityLogIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: activityLogIdentityName
  location: location
  tags: tags
}

output activityLogIdentityId string = activityLogIdentity.id
output activityLogIdentityName string = activityLogIdentity.name
output activityLogIdentityClientId string = activityLogIdentity.properties.clientId
output activityLogIdentityPrincipalId string = activityLogIdentity.properties.principalId
