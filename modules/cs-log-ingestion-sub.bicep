import { DiagnosticLogSettings } from '../models/real-time-visibility-detection.bicep'
import { FeatureSettings } from '../models/common.bicep'

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
@description('Azure subscription ID that will host CrowdStrike infrastructure')
param csInfraSubscriptionId string // DO NOT CHANGE - used for registration validation

@description('List of Azure subscription IDs to monitor')
param subscriptionIds array

module deploymentForSubs 'log-ingestion/logIngestionForSub.bicep' = {
  name: '${prefix}cs-li-sub-${env}${suffix}'
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

output activityLogEventHubId string = deploymentForSubs.outputs.activityLogEventHubId
output entraIdLogEventHubId string = deploymentForSubs.outputs.entraLogEventHubId
