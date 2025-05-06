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

@description('The Azure region for the resources deployed in this solution.')
param region string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string

@description('The prefix to be added to the deployment name.')
param prefix string

@description('The suffix to be added to the deployment name.')
param suffix string

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string

@description('Type of the Principal')
param azurePrincipalType string

@description('Tags to be applied to all resources.')
param tags object

@description('Settings of feature modules')
param featureSettings FeatureSettings

@description('List of IP addresses of Crowdstrike Falcon service. Please refer to https://falcon.crowdstrike.com/documentation/page/re07d589/add-crowdstrike-ip-addresses-to-cloud-provider-allowlists-0 for the IP address list of your Falcon region.')
param falconIpAddresses array

@minLength(36)
@maxLength(36)
@description('Subscription Id of the default Azure Subscription.')
param csInfraSubscriptionId string // DO NOT CHANGE - used for registration validation

@description('List of Azure subscription IDs to monitor')
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
  diagnosticSettingsName: 'diag-cslientid'        // DO NOT CHANGE - used for registration validation
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
  name: '${prefix}cs-li-eventhub-${env}-${region}${suffix}'
  scope: scope
  params: {
    activityLogSettings: activityLogSettings
    entraLogSettings: entraLogSettings
    falconIpAddresses: falconIpAddresses
    azurePrincipalId: azurePrincipalId
    azurePrincipalType: azurePrincipalType
    activityLogEnabled: featureSettings.realTimeVisibilityDetection.deployActivityLogDiagnosticSettings
    entraLogEnabled: featureSettings.realTimeVisibilityDetection.deployEntraLogDiagnosticSettings
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
module activityDiagnosticSettings 'activityLog.bicep' = [for subId in union(subscriptionIds, [csInfraSubscriptionId]): if(featureSettings.realTimeVisibilityDetection.deployActivityLogDiagnosticSettings && !activityLogSettings.useExistingEventHub) { // make sure the specified infra subscription is in the scope
  name:  '${prefix}cs-li-activity-diag-${env}${suffix}'
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

module entraDiagnosticSettings 'entraLog.bicep' = if (featureSettings.realTimeVisibilityDetection.deployEntraLogDiagnosticSettings && !entraLogSettings.useExistingEventHub) {
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
output activityLogEventHubId string = eventHub.outputs.eventhubs.activityLog.eventHubId
output entraLogEventHubId string = eventHub.outputs.eventhubs.entraLog.eventHubId
