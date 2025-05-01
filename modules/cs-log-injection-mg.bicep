import {FeatureSettings} from '../models/common.bicep'

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

param managementGroupIds array

param subscriptionIds array

param managementGroupsToSubsctiptions array

@minLength(36)
@maxLength(36)
@description('Subscription Id of the default Azure Subscription.')
param csInfraSubscriptionId string

param falconIpAddresses array

@description('The prefix to be added to the deployment name.')
param prefix string

@description('The suffix to be added to the deployment name.')
param suffix string

param featureSettings FeatureSettings

@description('Azure region for the resources deployed in this solution.')
param region string

param env string

@description('Tags to be applied to all resources.')
param tags object


// Deployment for subscriptions
module deploymentForSubs 'log-injection/logInjectionForSub.bicep' = {
  name: '${prefix}cs-li-sub${suffix}'
  scope: subscription(csInfraSubscriptionId)
  params: {
    targetScope: targetScope
    csInfraSubscriptionId: csInfraSubscriptionId // DO NOT CHANGE
    subscriptionIds: subscriptionIds
    prefix: prefix
    suffix: suffix
    featureSettings: featureSettings
    falconIpAddresses: falconIpAddresses
    region: region
    env: env
    tags: tags
  }
}

// Deployment for management groups
module realTimeVisibilityDetectionForMG 'log-injection/logInjectionForMgmtGroup.bicep' = [for (mgmtGroupId, i) in managementGroupIds: if (featureSettings.realTimeVisibilityDetection.enabled && targetScope == 'ManagementGroup') {
  name: '${prefix}cs-li-mg-${mgmtGroupId}${suffix}'
  scope: managementGroup(mgmtGroupId)
  params: {
    targetScope: targetScope
    managedSubscriptions: managementGroupsToSubsctiptions[i]
    individualSubscriptionIds: subscriptionIds
    eventHubName: deploymentForSubs.outputs.activityLogEventHubName
    eventHubAuthorizationRuleId: deploymentForSubs.outputs.eventHubAuthorizationRuleIdForActivityLog
    featureSettings: featureSettings
    prefix: prefix
    suffix: suffix
    region: region
    env: env
    tags: tags
  }
}]
