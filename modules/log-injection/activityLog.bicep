targetScope = 'subscription'

/*
  This Bicep template deploys diagnostic settings for current subscription in order to
  forward logs to CrowdStrike for Indicator of Attack (IOA) assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('Event Hub Authorization Rule Id.')
param eventHubAuthorizationRuleId string

@description('Event Hub Name.')
param eventHubName string

@description('Entra ID Diagnostic Settings Name.')
param diagnosticSettingsName string = 'cs-li-monitor-activity-to-eventhub'

/*
  Deploy Diagnostic Settings for Azure Activity Logs - current Azure subscription

  Collect Azure Activity Logs and submit them to CrowdStrike for analysis of Indicators of Attack (IOA)

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
