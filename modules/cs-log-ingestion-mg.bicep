import { RealTimeVisibilityDetectionSettings } from '../models/real-time-visibility-detection.bicep'

targetScope = 'managementGroup'

/*
  This Bicep template deploys Azure Activity Log Diagnostic Settings
  to existing Azure subscriptions in the current Entra Id tenant
  to enable CrowdStrike Indicator of Attack (IOA) assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('List of Azure management group IDs to monitor')
param managementGroupIds array

@description('List of Azure subscription IDs to monitor')
param subscriptionIds array

@minLength(36)
@maxLength(36)
@description('Subscription Id of the default Azure Subscription.')
param csInfraSubscriptionId string

@description('List of IP addresses of Crowdstrike Falcon service. Please refer to https://falcon.crowdstrike.com/documentation/page/re07d589/add-crowdstrike-ip-addresses-to-cloud-provider-allowlists-0 for the IP address list of your Falcon region.')
param falconIpAddresses array

@description('The prefix to be added to the resource name.')
param resourceNamePrefix string

@description('The suffix to be added to the resource name.')
param resourceNameSuffix string

@description('Resource group name for the Crowdstrike infrastructure resources')
param resourceGroupName string

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string

@description('Settings of feature modules')
param featureSettings RealTimeVisibilityDetectionSettings

@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string

@description('Tags to be applied to all resources.')
param tags object

var environment = length(env) > 0 ? '-${env}' : env

// Deployment for subscriptions
module deploymentForSubs 'log-ingestion/logIngestionForSub.bicep' = {
  name: '${resourceNamePrefix}cs-log-sub${environment}${resourceNameSuffix}'
  scope: subscription(csInfraSubscriptionId)
  params: {
    subscriptionIds: subscriptionIds
    resourceGroupName: resourceGroupName
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    azurePrincipalId: azurePrincipalId
    featureSettings: featureSettings
    falconIpAddresses: falconIpAddresses
    location: location
    env: env
    tags: tags
  }
}

// Deployment for management groups
module realTimeVisibilityDetectionForMG 'log-ingestion/logIngestionForMgmtGroup.bicep' = [for (mgmtGroupId, i) in managementGroupIds: {
  name: '${resourceNamePrefix}cs-log-mg-${mgmtGroupId}${environment}${resourceNameSuffix}'
  scope: managementGroup(mgmtGroupId)
  params: {
    eventHubAuthorizationRuleId: deploymentForSubs.outputs.eventHubAuthorizationRuleIdForActivityLog
    activityLogEventHubName: deploymentForSubs.outputs.activityLogEventHubName
    activityLogEventHubId: deploymentForSubs.outputs.activityLogEventHubId
    resourceGroupName: resourceGroupName
    csInfraSubscriptionId: csInfraSubscriptionId
    activityLogDiagnosticSettingsName: deploymentForSubs.outputs.activityLogDiagnosticSettingsName
    featureSettings: featureSettings
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    location: location
  }
}]

output activityLogEventHubId string = deploymentForSubs.outputs.activityLogEventHubId
output entraIdLogEventHubId string = deploymentForSubs.outputs.entraLogEventHubId
