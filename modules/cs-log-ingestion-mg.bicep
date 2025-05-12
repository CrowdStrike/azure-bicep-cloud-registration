import { ActivityLogSettings, EntraIdLogSettings } from '../models/log-ingestion.bicep'

targetScope = 'managementGroup'

/*
  This Bicep template deploys Azure Activity Log Diagnostic Settings
  to existing Azure subscriptions in the current Entra Id tenant
  to enable CrowdStrike Real Time Visibility and Detection assessment.
  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('List of Azure management group IDs to monitor. These management groups will be configured for CrowdStrike monitoring.')
param managementGroupIds array

@description('List of Azure subscription IDs to monitor. These subscriptions will be configured for CrowdStrike monitoring.')
param subscriptionIds array

@minLength(36)
@maxLength(36)
@description('Subscription ID where CrowdStrike infrastructure resources will be deployed. This subscription hosts shared resources like Event Hubs.')
param csInfraSubscriptionId string

@description('List of CrowdStrike Falcon service IP addresses that need network access. These IPs will be allowed through the Event Hub firewall.')
param falconIpAddresses array

@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string

@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string

@description('Name of the resource group where CrowdStrike infrastructure resources will be deployed.')
param resourceGroupName string

@description('Principal ID of the CrowdStrike application registered in Entra ID. This service principal will be granted necessary permissions.')
param azurePrincipalId string

@description('Configuration settings for Azure Activity Log collection and monitoring.')
param activityLogSettings ActivityLogSettings

@description('Configuration settings for Microsoft Entra ID log collection and monitoring.')
param entraIdLogSettings EntraIdLogSettings

@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string

@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Tags to be applied to all deployed resources. Used for resource organization, governance, and cost tracking.')
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
    activityLogSettings: activityLogSettings
    entraIdLogSettings: entraIdLogSettings
    falconIpAddresses: falconIpAddresses
    location: location
    env: env
    tags: tags
  }
}

// Deployment for management groups
module realTimeVisibilityDetectionForMG 'log-ingestion/logIngestionForMgmtGroup.bicep' = [
  for (mgmtGroupId, i) in managementGroupIds: {
    name: '${resourceNamePrefix}cs-log-mg-${mgmtGroupId}${environment}${resourceNameSuffix}'
    scope: managementGroup(mgmtGroupId)
    params: {
      eventHubAuthorizationRuleId: deploymentForSubs.outputs.eventHubAuthorizationRuleIdForActivityLog
      activityLogEventHubName: deploymentForSubs.outputs.activityLogEventHubName
      activityLogEventHubId: deploymentForSubs.outputs.activityLogEventHubId
      resourceGroupName: resourceGroupName
      csInfraSubscriptionId: csInfraSubscriptionId
      activityLogDiagnosticSettingsName: deploymentForSubs.outputs.activityLogDiagnosticSettingsName
      activityLogSettings: activityLogSettings
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      location: location
    }
  }
]

output activityLogEventHubId string = deploymentForSubs.outputs.activityLogEventHubId
output activityLogEventHubConsumerGroupName string = deploymentForSubs.outputs.activityLogEventHubConsumerGroupName
output entraLogEventHubId string = deploymentForSubs.outputs.entraLogEventHubId
output entraLogEventHubConsumerGroupName string = deploymentForSubs.outputs.entraLogEventHubConsumerGroupName
