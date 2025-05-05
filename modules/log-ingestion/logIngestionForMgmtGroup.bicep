import { DiagnosticLogSettings } from '../../models/real-time-visibility-detection.bicep'
import { FeatureSettings } from '../../models/common.bicep'

targetScope = 'managementGroup'

/*
  This Bicep template deploys Azure Activity Log Diagnostic Settings
  to existing Azure subscriptions in the current Entra Id tenant
  to enable CrowdStrike Indicator of Attack (IOA) assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('Targetscope of the Falcon Cloud Security integration.')
@allowed([
  'ManagementGroup'
  'Subscription'
])
param targetScope string

@description('The prefix to be added to the deployment name.')
param prefix string

@description('The suffix to be added to the deployment name.')
param suffix string

@description('Directly specified active subscriptions  ')
param individualSubscriptionIds array

@description('Active subscriptions under management groups.')
param managedSubscriptions array

@description('Event Hub Authorization Rule Id.')
param eventHubAuthorizationRuleId string

@description('Event Hub Name.')
param eventHubName string

@description('Settings of feature modules')
param featureSettings FeatureSettings

@description('Azure region for the resources deployed in this solution.')
param region string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string

@description('Tags to be applied to all resources.')
param tags object

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

module activityLogDiagnosticSettings 'activityLog.bicep' = [for subId in managedSubscriptions: if((featureSettings.realTimeVisibilityDetection.deployActivityLogDiagnosticSettings && !activityLogSettings.useExistingEventHub) && indexOf(individualSubscriptionIds, subId) < 0) {
  name: '${prefix}cs-li-activity-diag-${subId}-${env}${suffix}'
  scope: subscription(subId)
  params: {
    eventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    eventHubName: eventHubName
    diagnosticSettingsName: '${prefix}${activityLogSettings.diagnosticSettingsName}${suffix}'
  }
}]

module activityLogDiagnosticSettingsPolicyAssignment 'activityLogPolicy.bicep' = if (featureSettings.realTimeVisibilityDetection.deployActivityLogDiagnosticSettingsPolicy) {
  name: '${prefix}cs-li-policy-${region}${suffix}'
  params: {
    eventHubName: eventHubName
    eventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    prefix: prefix
    suffix: suffix
    region: region
    env: env
  }
}
