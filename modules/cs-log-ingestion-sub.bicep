import { RealTimeVisibilityDetectionSettings } from '../models/real-time-visibility-detection.bicep'

targetScope = 'subscription'

/*
  This Bicep template deploys infrastructure to enable CrowdStrike 
  Indicator of Attack (IOA) assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string

@description('The prefix to be added to the resource name.')
param resourceNamePrefix string

@description('The suffix to be added to the resource name.')
param resourceNameSuffix string

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string

@description('Resource group name for the Crowdstrike infrastructure resources')
param resourceGroupName string

@description('Tags to be applied to all resources.')
param tags object

@description('Settings of feature modules')
param featureSettings RealTimeVisibilityDetectionSettings

@description('List of IP addresses of Crowdstrike Falcon service. Please refer to https://falcon.crowdstrike.com/documentation/page/re07d589/add-crowdstrike-ip-addresses-to-cloud-provider-allowlists-0 for the IP address list of your Falcon region.')
param falconIpAddresses array

@description('List of Azure subscription IDs to monitor')
param subscriptionIds array

var environment = length(env) > 0 ? '-${env}' : env

module deploymentForSubs 'log-ingestion/logIngestionForSub.bicep' = {
  name: '${resourceNamePrefix}cs-log-sub${environment}${resourceNameSuffix}'
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

output activityLogEventHubId string = deploymentForSubs.outputs.activityLogEventHubId
output entraIdLogEventHubId string = deploymentForSubs.outputs.entraLogEventHubId
