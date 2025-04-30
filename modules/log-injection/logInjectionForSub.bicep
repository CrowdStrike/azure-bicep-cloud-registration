import {
  RealTimeVisibilityDetectionSettings
  DiagnosticLogSettings
} from '../../models/real-time-visibility-detection.bicep'

targetScope = 'subscription'

/*
  This Bicep template deploys infrastructure to enable CrowdStrike 
  Indicator of Attack (IOA) assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('Targetscope of the IOM integration.')
@allowed([
  'ManagementGroup'
  'Subscription'
])
param targetScope string

@description('The location for the resources deployed in this solution.')
param region string = deployment().location

@description('The prefix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs-ioa'

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = ''

@description('Tags to be applied to all resources.')
param tags object = {
  CSTagVendor: 'Crowdstrike'
}

param featureSettings RealTimeVisibilityDetectionSettings = {
  enabled: true
  deployActivityLogDiagnosticSettings: true
  deployEntraLogDiagnosticSettings: true 
  deployActivityLogDiagnosticSettingsPolicy: true
  enableAppInsights: false
}

@minLength(36)
@maxLength(36)
param defaultSubscriptionId string // DO NOT CHANGE - used for registration validation

param subscriptionIds array

/* ParameterBag for Activity Logs */
param activityLogSettings DiagnosticLogSettings = {
  useExistingEventHub: false
  eventHubNamespaceName : ''                                // Optional, used only when useExistingEventHub is set to true
  eventHubName: 'cs-eventhub-monitor-activity-logs'         // Optional, used only when useExistingEventHub is set to true
  eventHubResourceGroupName: ''                             // Optional, used only when useExistingEventHub is set to true
  eventHubSubscriptionId: ''                                // Optional, used only when useExistingEventHub is set to true
  eventHubAuthorizationRuleId: ''                           // Optional, used only when useExistingEventHub is set to true
  diagnosticSettingsName: 'cs-monitor-activity-to-eventhub' // DO NOT CHANGE - used for registration validation
}

/* ParameterBag for EntraId Logs */
param entraLogSettings DiagnosticLogSettings = {
  useExistingEventHub: false
  eventHubNamespaceName : ''                   // Optional, used only when useExistingEventHub is set to true
  eventHubName: 'cs-eventhub-monitor-aad-logs' // Optional, used only when useExistingEventHub is set to true
  eventHubResourceGroupName: ''                // Optional, used only when useExistingEventHub is set to true
  eventHubSubscriptionId: ''                   // Optional, used only when useExistingEventHub is set to true
  eventHubAuthorizationRuleId: ''              // Optional, used only when useExistingEventHub is set to true
  diagnosticSettingsName: 'cs-aad-to-eventhub' // DO NOT CHANGE - used for registration validation
}



/* Variables */
var resourceGroupName = '${deploymentNamePrefix}-cs-li-rg-${region}-${deploymentNameSuffix}'
var scope = az.resourceGroup(resourceGroupName)

/* Resource Deployment */
resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: region
  tags: tags
}

// Create EventHub Namespace and Eventhubs used by CrowdStrike
module eventHub 'eventHub.bicep' = {
  name: '${deploymentNamePrefix}-cs-li-eventhub-${region}-${deploymentNameSuffix}'
  scope: scope
  params: {
    activityLogSettings: activityLogSettings
    entraLogSettings: entraLogSettings
    deploymentNamePrefix: deploymentNamePrefix
    deploymentNameSuffix: deploymentNameSuffix
    tags: tags
    region: region
  }
  dependsOn: [
    resourceGroup
  ]
}

/* Deploy Activity Log Diagnostic Settings for current Azure subscription */
module activityDiagnosticSettings 'activityLog.bicep' = [for subId in union(subscriptionIds, [defaultSubscriptionId]): { // make sure the specified infra subscription is in the scope
  name:  '${deploymentNamePrefix}-cs-li-monitor-activity-diag-${deploymentNameSuffix}'
  scope: subscription(subId)
  params: {
      diagnosticSettingsName: activityLogSettings.diagnosticSettingsName
      eventHubAuthorizationRuleId: eventHub.outputs.eventhubs.activityLog.eventHubAuthorizationRuleId
      eventHubName: eventHub.outputs.eventhubs.activityLog.eventHubName
  }
  dependsOn: [
    resourceGroup
  ]
}]

module entraDiagnosticSettings 'entraLog.bicep' = if (featureSettings.deployEntraLogDiagnosticSettings) {
  name: '${deploymentNamePrefix}-cs-li-monitor-aad-diag-${deploymentNameSuffix}'
  params: {
    diagnosticSettingsName: entraLogSettings.diagnosticSettingsName
    eventHubName: eventHub.outputs.eventhubs.entraLog.eventHubName
    eventHubAuthorizationRuleId: eventHub.outputs.eventhubs.entraLog.eventHubAuthorizationRuleId
  }
  dependsOn: [
    resourceGroup
  ]
}

/* Deployment outputs required for follow-up activities */
output eventHubAuthorizationRuleIdForActivityLog string = eventHub.outputs.eventhubs.activityLog.eventHubAuthorizationRuleId
output eventHubAuthorizationRuleIdForEntraLog string = eventHub.outputs.eventhubs.entraLog.eventHubAuthorizationRuleId
output activityLogEventHubName string = eventHub.outputs.eventhubs.activityLog.eventHubName
output entraLogEventHubName string = eventHub.outputs.eventhubs.entraLog.eventHubName
