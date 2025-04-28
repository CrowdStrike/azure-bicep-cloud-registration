param falconClientId string

@secure()
param falconClientSecret string

@allowed([
  'US-1'
  'US-2'
  'EU-1'
])
param falconCloudRegion string = 'US-1'

param location string = resourceGroup().location
param tags object = {}

resource setAzureDefaultSubscription 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'cs-horizon-ioa-${subscription().subscriptionId}'
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '12.3'
    environmentVariables: [
      {
        name: 'FALCON_CLOUD_REGION'
        value: falconCloudRegion
      }
      {
        name: 'FALCON_CLIENT_ID'
        value: falconClientId
      }
      {
        name: 'FALCON_CLIENT_SECRET'
        secureValue: falconClientSecret
      }
    ]
    arguments: '-AzureTenantId ${tenant().tenantId} -AzureSubscriptionId ${subscription().subscriptionId}'
    scriptContent: loadTextContent('../../scripts/Set-AzureDefaultSubscription.ps1')
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
  }
}
