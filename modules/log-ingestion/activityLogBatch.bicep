targetScope = 'subscription'

/*
  This Bicep template handles batched Activity Log diagnostic settings deployment
  to overcome the 800 iteration limit for large numbers of subscriptions.
  Copyright (c) 2025 CrowdStrike, Inc.
*/

/* Parameters */
@maxLength(800)
@description('List of Azure subscription IDs to monitor. These subscriptions will be configured for CrowdStrike monitoring. (max: 800)')
param subscriptionIds array

@description('Name for the diagnostic settings configuration that sends Activity Logs to the Event Hub. Used for identification in the Azure portal.')
param diagnosticSettingsName string

@description('Name of the Event Hub instance where Activity Logs will be sent. This Event Hub must exist within the namespace referenced by the authorization rule.')
param eventHubName string

@description('Resource ID of the Event Hub Authorization Rule that grants "Send" permissions. Used to configure diagnostic settings to send logs to the Event Hub.')
param eventHubAuthorizationRuleId string

@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string

@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string

@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Batch number for unique naming')
param batchNumber int

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env

/* Deploy Activity Log Diagnostic Settings for subscriptions in this batch */
module activityDiagnosticSettings 'activityLog.bicep' = [
  for subId in subscriptionIds: {
    name: '${resourceNamePrefix}cs-log-activity-${batchNumber}-${uniqueString(subId)}${environment}${resourceNameSuffix}'
    scope: subscription(subId)
    params: {
      diagnosticSettingsName: diagnosticSettingsName
      eventHubName: eventHubName
      eventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    }
  }
]

/* Outputs */
output subscriptionsProcessed int = length(subscriptionIds)
output batchNumber int = batchNumber
