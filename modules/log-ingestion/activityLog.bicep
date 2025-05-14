targetScope = 'subscription'

/*
  This Bicep template deploys diagnostic settings for current subscription in order to
  forward activity logs to CrowdStrike.
  Copyright (c) 2025 CrowdStrike, Inc.
*/

@description('Resource ID of the Event Hub Authorization Rule that grants "Send" permissions. Used to configure diagnostic settings to send logs to the Event Hub.')
param eventHubAuthorizationRuleId string

@description('Name of the Event Hub instance where Activity Logs will be sent. This Event Hub must exist within the namespace referenced by the authorization rule.')
param eventHubName string

@description('Name for the diagnostic settings configuration that sends Activity Logs to the Event Hub. Used for identification in the Azure portal.')
param diagnosticSettingsName string

/*
  Deploy Diagnostic Settings for Azure Activity Logs - current Azure subscription

  Collect Azure Activity Logs and submit them to CrowdStrike

  Note:
   - 'Contributor' permissions are required to create Azure Activity Logs diagnostic settings
*/
resource activityDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingsName
  properties: {
    eventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    eventHubName: eventHubName
    logs: [
      {
        category: 'Administrative'
        enabled: true
      }
      {
        category: 'Security'
        enabled: true
      }
      {
        category: 'ServiceHealth'
        enabled: true
      }
      {
        category: 'Alert'
        enabled: true
      }
      {
        category: 'Recommendation'
        enabled: true
      }
      {
        category: 'Policy'
        enabled: true
      }
      {
        category: 'Autoscale'
        enabled: true
      }
      {
        category: 'ResourceHealth'
        enabled: true
      }
    ]
  }
}
