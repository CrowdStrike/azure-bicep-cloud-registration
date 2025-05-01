import { DiagnosticLogSettings } from '../../models/real-time-visibility-detection.bicep'
import { FeatureSettings } from '../../models/common.bicep'

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
param region string

param env string

@description('The prefix to be added to the deployment name.')
param prefix string

@description('The suffix to be added to the deployment name.')
param suffix string

@description('Tags to be applied to all resources.')
param tags object

param featureSettings FeatureSettings

param falconIpAddresses array

@minLength(36)
@maxLength(36)
param csInfraSubscriptionId string // DO NOT CHANGE - used for registration validation

param subscriptionIds array


/* ParameterBag for Activity Logs */
param activityLogSettings DiagnosticLogSettings = {
  useExistingEventHub: false
  eventHubNamespaceName : ''                                // Optional, used only when useExistingEventHub is set to true
  eventHubName: ''        // Optional, used only when useExistingEventHub is set to true
  eventHubResourceGroupName: ''                             // Optional, used only when useExistingEventHub is set to true
  eventHubSubscriptionId: ''                                // Optional, used only when useExistingEventHub is set to true
  eventHubAuthorizationRuleId: ''                           // Optional, used only when useExistingEventHub is set to true
  diagnosticSettingsName: 'diag-csliactivity-${env}'               // DO NOT CHANGE - used for registration validation
}

/* ParameterBag for EntraId Logs */
param entraLogSettings DiagnosticLogSettings = {
  useExistingEventHub: false
  eventHubNamespaceName : ''                    // Optional, used only when useExistingEventHub is set to true
  eventHubName: '' // Optional, used only when useExistingEventHub is set to true
  eventHubResourceGroupName: ''                 // Optional, used only when useExistingEventHub is set to true
  eventHubSubscriptionId: ''                    // Optional, used only when useExistingEventHub is set to true
  eventHubAuthorizationRuleId: ''               // Optional, used only when useExistingEventHub is set to true
  diagnosticSettingsName: 'diag-cslientid-${env}'        // DO NOT CHANGE - used for registration validation
}



/* Variables */
var resourceGroupName = '${prefix}rg-csli-${env}${suffix}'
var scope = az.resourceGroup(resourceGroupName)

/* Resource Deployment */
resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: region
  tags: tags
}

// Create EventHub Namespace and Eventhubs used by CrowdStrike
module eventHub 'eventHub.bicep' = {
  name: '${prefix}cs-li-eventhub${region}${suffix}'
  scope: scope
  params: {
    activityLogSettings: activityLogSettings
    entraLogSettings: entraLogSettings
    falconIpAddresses: falconIpAddresses
    prefix: prefix
    suffix: suffix
    tags: tags
    region: region
    env: env
  }
  dependsOn: [
    resourceGroup
  ]
}

/* Deploy Activity Log Diagnostic Settings for current Azure subscription */
module activityDiagnosticSettings 'activityLog.bicep' = [for subId in union(subscriptionIds, [csInfraSubscriptionId]): { // make sure the specified infra subscription is in the scope
  name:  '${prefix}cs-li-activity-diag${suffix}'
  scope: subscription(subId)
  params: {
      diagnosticSettingsName: '${prefix}${activityLogSettings.diagnosticSettingsName}${suffix}'
      eventHubAuthorizationRuleId: eventHub.outputs.eventhubs.activityLog.eventHubAuthorizationRuleId
      eventHubName: eventHub.outputs.eventhubs.activityLog.eventHubName
  }
  dependsOn: [
    resourceGroup
  ]
}]

module entraDiagnosticSettings 'entraLog.bicep' = if (featureSettings.realTimeVisibilityDetection.deployEntraLogDiagnosticSettings) {
  name: '${prefix}cs-li-entid-diag${suffix}'
  params: {
    diagnosticSettingsName: '${prefix}${entraLogSettings.diagnosticSettingsName}${suffix}'
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
