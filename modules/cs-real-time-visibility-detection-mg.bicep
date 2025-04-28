import {RealTimeVisibilityDetectionSettings} from '../models/real-time-visibility-detection.bicep'

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

param managementGroupIds array

param subscriptionIds array

@minLength(36)
@maxLength(36)
@description('Subscription Id of the default Azure Subscription.')
param defaultSubscriptionId string

@description('The prefix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs'

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = ''

param featureSettings RealTimeVisibilityDetectionSettings = {
  enabled: true
  deployActivityLogDiagnosticSettings: true
  deployEntraLogDiagnosticSettings: true
  deployActivityLogDiagnosticSettingsPolicy: true
  enableAppInsights: false
  resourceGroupName: 'ca-ioa-group' // DO NOT CHANGE
}

@description('Location for the resources deployed in this solution.')
param location string = deployment().location

@description('Tags to be applied to all resources.')
param tags object = {
  'cstag-vendor': 'crowdstrike'
  'stack-managed': 'true'
}



// Deployment for subscriptions
module deploymentForSubs 'real-time-visibility-detection/realTimeVisibilityDetectionForSub.bicep' = {
  name: '${deploymentNamePrefix}-realTimeVisibilityDetectionForSubs-${deploymentNameSuffix}'
  scope: subscription(defaultSubscriptionId)
  params: {
    targetScope: targetScope
    defaultSubscriptionId: defaultSubscriptionId // DO NOT CHANGE
    subscriptionIds: subscriptionIds
    deploymentNamePrefix: deploymentNamePrefix
    deploymentNameSuffix: deploymentNameSuffix
    featureSettings: featureSettings
    location: location
    tags: tags
  }
}

// Deployment for management groups
module realTimeVisibilityDetectionForMG 'real-time-visibility-detection/realTimeVisibilityDetectionForMgmtGroup.bicep' = [for mgmtGroupId in managementGroupIds: if (featureSettings.enabled && targetScope == 'ManagementGroup') {
  name: '${deploymentNamePrefix}-ioa-activityLogDiagnosticSettingsDeployment-${deploymentNameSuffix}'
  scope: managementGroup(mgmtGroupId)
  params: {
    targetScope: targetScope
    activityLogIdentityId: deploymentForSubs.outputs.activityLogIdentityId
    defaultSubscriptionId: defaultSubscriptionId
    eventHubName: deploymentForSubs.outputs.activityLogEventHubName
    eventHubAuthorizationRuleId: deploymentForSubs.outputs.eventHubAuthorizationRuleIdForActivityLog
    featureSettings: featureSettings
    location: location
    tags: tags
  }
}]
