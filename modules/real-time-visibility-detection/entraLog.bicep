targetScope = 'subscription'

/*
  This Bicep template deploys diagnostic settings for Entra ID in order to
  forward logs to CrowdStrike for Indicator of Attack (IOA) assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('Event Hub Authorization Rule Id.')
param eventHubAuthorizationRuleId string

@description('Event Hub Name.')
param eventHubName string = 'cs-eventhub-monitor-aad-logs'

@description('Entra ID Diagnostic Settings Name.')
param diagnosticSettingsName string = 'cs-aad-to-eventhub'

/* 
  Deploy Diagnostic Settings for Microsoft Entra ID Logs

  Collect Microsoft Entra ID logs and submit them to CrowdStrike for analysis of Indicators of Attack (IOA)

  Note:
   - To export SignInLogs a P1 or P2 Microsoft Entra ID license is required
   - 'Security Administrator' or 'Global Administrator' Entra ID permissions are required
*/
resource entraDiagnosticSettings 'microsoft.aadiam/diagnosticSettings@2017-04-01' = {
  name: diagnosticSettingsName
  scope: tenant()
  properties: {
    eventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    eventHubName: eventHubName
    logs: [
      {
        category: 'AuditLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'SignInLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'NonInteractiveUserSignInLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'ServicePrincipalSignInLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'ManagedIdentitySignInLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'ADFSSignInLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}
