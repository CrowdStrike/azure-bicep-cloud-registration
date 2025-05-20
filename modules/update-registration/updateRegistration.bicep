/*
  This Bicep template update the Event Hub settings back to Falcon Cloud Security.
  Copyright (c) 2025 CrowdStrike, Inc.
*/

@description('Base URL of the Falcon API.')
param falconApiFqdn string

@description('Client ID for the Falcon API.')
param falconClientId string

@description('Client secret for the Falcon API.')
@secure()
param falconClientSecret string

@description('a list of Event Hub settings for activity logs and entra ID logs ingestion. Ex: [{"purpose": "activity_logs", "event_hub_id": "<event_hub_id>", "consumer_group": "<consumer group name"}]')
param eventHubs array

@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string

@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Tags to be applied to all deployed resources. Used for resource organization, governance, and cost tracking.')
param tags object

resource subscriptionsInManagementGroup 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: guid('updateRegistration', resourceGroup().id, env, location)
  location: location
  kind: 'AzurePowerShell'
  tags: tags
  properties: {
    azPowerShellVersion: '12.3'
    environmentVariables: [
      {
        name: 'FALCON_API_BASE_URL'
        value: falconApiFqdn
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
    arguments: '-AzureTenantId \\"${tenant().tenantId}\\" -EventHubsJson \'${replace(string(eventHubs), '"', '\\"')}\''
    scriptContent: loadTextContent('../../scripts/Update-Registration.ps1')
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
  }
}
