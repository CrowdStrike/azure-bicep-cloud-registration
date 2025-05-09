import {FeatureSettings} from 'models/common.bicep'

targetScope='subscription'

metadata name = 'CrowdStrike Falcon Cloud Security Integration'
metadata description = 'Deploys CrowdStrike Falcon Cloud Security integration for Indicator of Misconfiguration (IOM) and Indicator of Attack (IOA) assessment'
metadata owner = 'CrowdStrike'
/*
  This Bicep template deploys CrowdStrike Falcon Cloud Security integration for
  Indicator of Misconfiguration (IOM) and Indicator of Attack (IOA) assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('List of Azure subscription IDs to monitor')
param subscriptionIds array = []

@minLength(36)
@maxLength(36)
@description('Subscription Id of the default Azure Subscription.')
param csInfraSubscriptionId string

@description('List of IP addresses of Crowdstrike Falcon service. Please refer to https://falcon.crowdstrike.com/documentation/page/re07d589/add-crowdstrike-ip-addresses-to-cloud-provider-allowlists-0 for the IP address list of your Falcon region.')
param falconIpAddresses array = []

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string

@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string = deployment().location

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string = 'prod'

@description('Tags to be applied to all resources.')
param tags object = {
  CSTagVendor: 'crowdstrike'
}

@description('The prefix to be added to the deployment name.')
param resourceNamePrefix string = ''

@description('The suffix to be added to the deployment name.')
param resourceNameSuffix string = ''

@description('Settings of feature modules')
param featureSettings FeatureSettings = {
  realTimeVisibilityDetection: {
    enabled: true
    activityLogSettings: {
      enabled: true
      deployRemediationPolicy: true
      existingEventhub: {
        use: false
        name: ''
        namespaceName: ''
        resourceGroupName: ''
        subscriptionId: ''
      }
    }
    entraIdLogSettings: {
      enabled: true
      existingEventhub: {
        use: false
        name: ''
        namespaceName: ''
        resourceGroupName: ''
        subscriptionId: ''
      }
    }                    
  }
}


// ===========================================================================
var subscriptions = union(subscriptionIds, [csInfraSubscriptionId]) // remove duplicated values
var environment = length(env) > 0 ? '-${env}' : env

/* Resources used across modules
1. Role assignments to the Crowdstrike's app service principal
*/
module assetInventory 'modules/cs-asset-inventory-sub.bicep' = {
  name: '${resourceNamePrefix}cs-inv-sub-deployment-${env}${resourceNameSuffix}'
  params: {
    csInfraSubscriptionId: csInfraSubscriptionId
    subscriptionIds: subscriptions
    azurePrincipalId: azurePrincipalId
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    env: env
  }
}

var resourceGroupName = '${resourceNamePrefix}rg-cs${environment}${resourceNameSuffix}'
module resourceGroup 'modules/common/resourceGroup.bicep' = if (featureSettings.realTimeVisibilityDetection.enabled) {
    name: '${resourceNamePrefix}cs-rg${environment}${resourceNameSuffix}'
    scope: subscription(csInfraSubscriptionId)

    params: {
        resourceGroupName: resourceGroupName
        location: location
        tags: tags
    }
}


module logIngestion 'modules/cs-log-ingestion-sub.bicep' = if (featureSettings.realTimeVisibilityDetection.enabled) {
  name: '${resourceNamePrefix}cs-log-sub-deployment-${env}${resourceNameSuffix}'
  scope: subscription(csInfraSubscriptionId)
  params: {
    subscriptionIds: subscriptions
    resourceGroupName: resourceGroupName
    falconIpAddresses: falconIpAddresses
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    azurePrincipalId: azurePrincipalId
    featureSettings: featureSettings.realTimeVisibilityDetection
    location: location
    env: env
    tags: tags
  }
  dependsOn: [
    resourceGroup
  ]
}

output csCustomReaderRoleName string = assetInventory.outputs.customRoleName
output activityLogEventHubId string = logIngestion.outputs.activityLogEventHubId
output entraIDLogEventHubId string = logIngestion.outputs.entraIdLogEventHubId
