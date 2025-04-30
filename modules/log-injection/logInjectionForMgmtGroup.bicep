import {RealTimeVisibilityDetectionSettings} from '../../models/real-time-visibility-detection.bicep'

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
param targetScope string = 'ManagementGroup'

@description('The prefix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs'

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = ''

@description('Directly specified active subscriptions  ')
param individualSubscriptionIds array

@description('Active subscriptions under management groups.')
param managedSubscriptions array

@description('Event Hub Authorization Rule Id.')
param eventHubAuthorizationRuleId string

@description('Event Hub Name.')
param eventHubName string

param featureSettings RealTimeVisibilityDetectionSettings = {
  enabled: true
  deployActivityLogDiagnosticSettings: true
  deployEntraLogDiagnosticSettings: true
  deployActivityLogDiagnosticSettingsPolicy: true
  enableAppInsights: false
}

@description('Location for the resources deployed in this solution.')
param region string = deployment().location

@description('Tags to be applied to all resources.')
param tags object = {
  CSTagVendor: 'Crowdstrike'
}

module activityLogDiagnosticSettings 'activityLog.bicep' = [for subId in managedSubscriptions: if(featureSettings.deployActivityLogDiagnosticSettings && indexOf(individualSubscriptionIds, subId) < 0) {
  name: '${deploymentNamePrefix}-cs-li-monitor-activity-diag-${subId}-${deploymentNameSuffix}'
  scope: subscription(subId)
  params: {
    eventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    eventHubName: eventHubName
  }
}]

module activityLogDiagnosticSettingsPolicyAssignment 'activityLogPolicy.bicep' = if (featureSettings.deployActivityLogDiagnosticSettingsPolicy) {
  name: '${deploymentNamePrefix}-cs-li-policy-${region}-${deploymentNameSuffix}'
  params: {
    eventHubName: eventHubName
    eventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    deploymentNamePrefix: deploymentNamePrefix
    deploymentNameSuffix: deploymentNameSuffix
    region: region
  }
}
