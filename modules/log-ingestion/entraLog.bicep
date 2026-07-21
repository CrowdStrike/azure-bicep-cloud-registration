targetScope = 'subscription'

/*
  This Bicep template deploys diagnostic settings for Entra ID in order to
  forward logs to CrowdStrike.
  Copyright (c) 2025 CrowdStrike, Inc.
*/

@description('Resource ID of the Event Hub Authorization Rule that grants send permissions. Used to configure diagnostic settings to send Entra ID logs to the Event Hub.')
param eventHubAuthorizationRuleId string

@description('Name of the Event Hub instance where Entra ID logs will be sent. This Event Hub must exist within the namespace referenced by the authorization rule.')
param eventHubName string

@description('Name for the diagnostic settings configuration that sends Entra ID logs to the Event Hub. Used for identification in the Azure portal.')
param diagnosticSettingsName string

@description('Azure cloud type for this registration. Use "commercial" for standard Azure or "gov" for Azure Government. Empty string is treated as commercial.')
param accountType string = ''

/*
  Full set of Microsoft Entra ID diagnostic log categories collected for
  CrowdStrike. Order is preserved for stability of the generated logs array.
*/
var allEntraLogCategories = [
  'AuditLogs'
  'SignInLogs'
  'NonInteractiveUserSignInLogs'
  'ServicePrincipalSignInLogs'
  'ManagedIdentitySignInLogs'
  'ADFSSignInLogs'
  'MicrosoftGraphActivityLogs'
  'ProvisioningLogs'
  'UserRiskEvents'
  'RiskyUsers'
  'RiskyServicePrincipals'
  'ServicePrincipalRiskEvents'
  'NetworkAccessTrafficLogs'
]

// Categories not supported by Azure Government. NetworkAccessTrafficLogs is a
// Microsoft Entra Global Secure Access category unavailable in Gov, and ARM
// rejects the whole diagnostic settings resource if any listed category is
// unsupported. Add further Gov-unsupported categories here as they are found.
var govUnsupportedCategories = [
  'NetworkAccessTrafficLogs'
]

var selectedCategories = accountType == 'gov'
  ? filter(allEntraLogCategories, category => !contains(govUnsupportedCategories, category))
  : allEntraLogCategories

/*
  Deploy Diagnostic Settings for Microsoft Entra ID Logs

  Collect Microsoft Entra ID logs and submit them to CrowdStrike

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
    logs: map(selectedCategories, category => {
      category: category
      enabled: true
      retentionPolicy: {
        days: 0
        enabled: false
      }
    })
  }
}
