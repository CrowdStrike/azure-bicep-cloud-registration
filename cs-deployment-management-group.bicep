import {FeatureSettings} from 'models/common.bicep'

targetScope='managementGroup'

metadata name = 'CrowdStrike Falcon Cloud Security Integration'
metadata description = 'Deploys CrowdStrike Falcon Cloud Security integration for Indicator of Misconfiguration (IOM) and Indicator of Attack (IOA) assessment'
metadata owner = 'CrowdStrike'

/*
  This Bicep template deploys CrowdStrike Falcon Cloud Security integration for
  Indicator of Misconfiguration (IOM) and Indicator of Attack (IOA) assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('List of Azure management group IDs to monitor')
param managementGroupIds array = []

@description('List of Azure subscription IDs to monitor')
param subscriptionIds array = []

@minLength(36)
@maxLength(36)
@description('Subscription Id of the default Azure Subscription.')
param csInfraSubscriptionId string

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string

@description('List of IP addresses of Crowdstrike Falcon service. Please refer to https://falcon.crowdstrike.com/documentation/page/re07d589/add-crowdstrike-ip-addresses-to-cloud-provider-allowlists-0 for the IP address list of your Falcon region.')
param falconIpAddresses array = []

@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string = deployment().location

@maxLength(4)
@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string = 'prod'

@description('Tags to be applied to all resources.')
param tags object = {
  CSTagVendor: 'Crowdstrike'
}

@maxLength(10)
@description('The prefix to be added to the resource name.')
param resourceNamePrefix string = ''

@maxLength(10)
@description('The suffix to be added to the resource name.')
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
var managementGroups = union(managementGroupIds, []) // remove duplicated values
var environment = length(env) > 0 ? '-${env}' : env

/* Resources used across modules
1. Role assignments to the Crowdstrike's app service principal
2. Discover subscriptions of the specified management groups
*/
module assetInventory 'modules/cs-asset-inventory-mg.bicep' = {
  name: '${resourceNamePrefix}cs-inv-mg-deployment-${env}${resourceNameSuffix}'
  params: {
    managementGroupIds: managementGroups
    subscriptionIds: subscriptions
    azurePrincipalId: azurePrincipalId
    csInfraSubscriptionId: csInfraSubscriptionId
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

module scriptRunnerIdentity 'modules/cs-script-runner-identity-mg.bicep' = if (featureSettings.realTimeVisibilityDetection.enabled) {
    name: '${resourceNamePrefix}cs-script-runner-identity${environment}${resourceNameSuffix}'

    params: {
        csInfraSubscriptionId: csInfraSubscriptionId
        managementGroupIds: managementGroups
        resourceGroupName: resourceGroupName
        resourceNamePrefix: resourceNamePrefix
        resourceNameSuffix: resourceNameSuffix
        env: env
        location: location
        tags: tags
    }

    dependsOn: [
        resourceGroup
    ]
}

module deploymentScope 'modules/cs-deployment-scope-mg.bicep' = if (featureSettings.realTimeVisibilityDetection.enabled) {
    name: '${resourceNamePrefix}cs-deployment-scope${environment}${resourceNameSuffix}'
    params: {
        managementGroupIds: managementGroups
        subscriptionIds: subscriptions
        resourceGroupName: resourceGroupName
        scriptRunnerIdentityId: scriptRunnerIdentity.outputs.id
        csInfraSubscriptionId: csInfraSubscriptionId
        resourceNamePrefix: resourceNamePrefix
        resourceNameSuffix: resourceNameSuffix
        env: env
        location: location
        tags: tags
    }
}

module logIngestion 'modules/cs-log-ingestion-mg.bicep' = if (featureSettings.realTimeVisibilityDetection.enabled) {
    name: '${resourceNamePrefix}cs-log-mg-deployment${environment}${resourceNameSuffix}'
    params: {
      managementGroupIds: managementGroups
      subscriptionIds: subscriptions
      csInfraSubscriptionId: csInfraSubscriptionId
      resourceGroupName: resourceGroupName
      featureSettings: featureSettings.realTimeVisibilityDetection
      falconIpAddresses: falconIpAddresses
      azurePrincipalId: azurePrincipalId
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      location: location
      env: env
      tags: tags
    }
    dependsOn: [
        resourceGroup
        deploymentScope
    ]
}

output customReaderRoleNameForSubs string = assetInventory.outputs.customRoleNameForSubs
output customReaderRoleNameForMGs array = assetInventory.outputs.customRoleNameForMGs
output activityLogEventHubId string = logIngestion.outputs.activityLogEventHubId
output entraIDLogEventHubId string = logIngestion.outputs.entraIdLogEventHubId
