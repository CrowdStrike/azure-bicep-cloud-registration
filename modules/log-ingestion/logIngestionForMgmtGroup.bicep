import { RealTimeVisibilityDetectionSettings } from '../../models/real-time-visibility-detection.bicep'
import { FeatureSettings } from '../../models/common.bicep'

targetScope = 'managementGroup'

/*
  This Bicep template deploys Azure Activity Log Diagnostic Settings
  to existing Azure subscriptions in the current Entra Id tenant
  to enable CrowdStrike Indicator of Attack (IOA) assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('The prefix to be added to the resource name.')
param resourceNamePrefix string

@description('The suffix to be added to the resource name.')
param resourceNameSuffix string

@minLength(36)
@maxLength(36)
@description('Azure subscription ID that will host CrowdStrike infrastructure')
param csInfraSubscriptionId string

@description('Event Hub Authorization Rule Id.')
param eventHubAuthorizationRuleId string

@description('Resource group name for the Crowdstrike infrastructure resources')
param resourceGroupName string

@description('Diagnostic settings name of activity log')
param activityLogDiagnosticSettingsName string

@description('Event Hub Name for activity log')
param activityLogEventHubName string

@description('Event Hub ID for activity log')
param activityLogEventHubId string

@description('Settings of feature modules')
param featureSettings RealTimeVisibilityDetectionSettings

@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string

module activityLogDiagnosticSettingsPolicyAssignment 'activityLogPolicy.bicep' = if (featureSettings.activityLogSettings.enabled && !featureSettings.activityLogSettings.existingEventhub.use && featureSettings.activityLogSettings.deployRemediationPolicy) {
  name: '${resourceNamePrefix}cs-log-policy-${location}${resourceNameSuffix}'
  params: {
    eventHubName: activityLogEventHubName
    eventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    eventhubSubscriptionId: csInfraSubscriptionId
    eventhubResourceGroupName: resourceGroupName
    eventhubId: activityLogEventHubId
    activityLogDiagnosticSettingsName: activityLogDiagnosticSettingsName
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    location: location
  }
}
