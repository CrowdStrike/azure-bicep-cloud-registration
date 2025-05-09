targetScope = 'subscription'

/*
  This Bicep template deploys diagnostic settings for Entra ID in order to
  forward logs to CrowdStrike for Real Time Visibility and Detection assessment.
  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('Resource ID of the Event Hub Authorization Rule that grants send permissions. Used to configure diagnostic settings to send Entra ID logs to the Event Hub.')
param eventHubAuthorizationRuleId string

@description('Name of the Event Hub instance where Entra ID logs will be sent. This Event Hub must exist within the namespace referenced by the authorization rule.')
param eventHubName string

@description('Name for the diagnostic settings configuration that sends Entra ID logs to the Event Hub. Used for identification in the Azure portal.')
param diagnosticSettingsName string

/* 
  Deploy Diagnostic Settings for Microsoft Entra ID Logs

  Collect Microsoft Entra ID logs and submit them to CrowdStrike for Real Time Visibility and Detection

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
