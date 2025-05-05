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

@description('List of Azure management group IDs to monitor')
param managementGroupIds array

@description('List of Azure subscription IDs to monitor')
param subscriptionIds array

@description('Mapping of Azure management group IDs to Azure subscription IDs')
param managementGroupsToSubscriptions array

@minLength(36)
@maxLength(36)
@description('Subscription Id of the default Azure Subscription.')
param csInfraSubscriptionId string

@description('List of IP addresses of Crowdstrike Falcon service. Please refer to https://falcon.crowdstrike.com/documentation/page/re07d589/add-crowdstrike-ip-addresses-to-cloud-provider-allowlists-0 for the IP address list of your Falcon region.')
param falconIpAddresses array

@description('The prefix to be added to the deployment name.')
param prefix string

@description('The suffix to be added to the deployment name.')
param suffix string

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string

@description('Type of the Principal')
param azurePrincipalType string

@description('Settings of feature modules')
param featureSettings FeatureSettings

@description('Azure region for the resources deployed in this solution.')
param region string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string

@description('Tags to be applied to all resources.')
param tags object


// Deployment for subscriptions
module deploymentForSubs 'log-ingestion/logIngestionForSub.bicep' = {
  name: '${prefix}cs-li-sub-${env}${suffix}'
  scope: subscription(csInfraSubscriptionId)
  params: {
    targetScope: targetScope
    csInfraSubscriptionId: csInfraSubscriptionId // DO NOT CHANGE
    subscriptionIds: subscriptionIds
    prefix: prefix
    suffix: suffix
    azurePrincipalId: azurePrincipalId
    azurePrincipalType: azurePrincipalType
    featureSettings: featureSettings
    falconIpAddresses: falconIpAddresses
    region: region
    env: env
    tags: tags
  }
}

// Deployment for management groups
module realTimeVisibilityDetectionForMG 'log-ingestion/logIngestionForMgmtGroup.bicep' = [for (mgmtGroupId, i) in managementGroupIds: if (featureSettings.realTimeVisibilityDetection.enabled && targetScope == 'ManagementGroup') {
  name: '${prefix}cs-li-mg-${mgmtGroupId}-${env}${suffix}'
  scope: managementGroup(mgmtGroupId)
  params: {
    targetScope: targetScope
    managedSubscriptions: managementGroupsToSubscriptions[i]
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

output activityLogEventHubId string = deploymentForSubs.outputs.activityLogEventHubId
output entraIdLogEventHubId string = deploymentForSubs.outputs.entraLogEventHubId
