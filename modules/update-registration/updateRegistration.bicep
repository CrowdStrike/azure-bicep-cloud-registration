/*
  This Bicep template update the Event Hub settings back to Falcon Cloud Security.
  Copyright (c) 2025 CrowdStrike, Inc.
*/

import { DeploymentScriptSettings } from '../../models/deployment-script.bicep'

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

@description('Indicates whether this is the initial registration')
param isInitialRegistration bool

@description('Azure cloud type for this registration. Use "commercial" for standard Azure or "gov" for Azure Government. Empty string omits the field from the API request.')
param accountType string = ''

@description('Configuration to use an existing, policy-compliant storage account for deployment scripts instead of the auto-provisioned one.')
param deploymentScriptSettings DeploymentScriptSettings?

@description('Resource ID of the user-assigned managed identity to attach to the deployment script. Required by Azure whenever the deployment script runs inside a virtual network (deploymentScriptSettings.subnetId is set).')
param scriptRunnerIdentityId string?

@description('A unique string generated for each deployment, to make sure the script is always run.')
param forceUpdateTag string = newGuid()

resource subscriptionsInManagementGroup 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: guid('updateRegistration', resourceGroup().id, env, location)
  location: location
  kind: 'AzurePowerShell'
  tags: tags
  identity: scriptRunnerIdentityId != null
    ? {
        type: 'UserAssigned'
        userAssignedIdentities: {
          '${scriptRunnerIdentityId}': {}
        }
      }
    : null
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
    arguments: '-AzureTenantId \\"${tenant().tenantId}\\" -IsInitialRegistration ${isInitialRegistration ? '$True' : '$False'} -EventHubsJson \'${replace(string(eventHubs), '"', '\\"')}\' -AccountType \\"${accountType}\\"'
    scriptContent: loadTextContent('../../scripts/Update-Registration.ps1')
    retentionInterval: 'PT24H'
    cleanupPreference: 'OnExpiration'
    forceUpdateTag: forceUpdateTag
    storageAccountSettings: deploymentScriptSettings != null
      ? union(
          {
            storageAccountName: last(split(deploymentScriptSettings!.storageAccountId, '/'))
          },
          deploymentScriptSettings.?subnetId != null
            ? {}
            : { storageAccountKey: deploymentScriptSettings.?storageAccountKey }
        )
      : null
    containerSettings: deploymentScriptSettings.?subnetId != null
      ? {
          subnetIds: [
            { id: deploymentScriptSettings.?subnetId! }
          ]
        }
      : null
  }
}
