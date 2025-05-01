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
@description('Targetscope of the Falcon Cloud Security integration.')
@allowed([
  'ManagementGroup'
  'Subscription'
])
param targetScope string = 'ManagementGroup'

@description('List of Azure management group IDs to monitor')
param managementGroupIds array = []

@description('List of Azure subscription IDs to monitor')
param subscriptionIds array = []

@description('Azure subscription ID that will host CrowdStrike infrastructure')
param csInfraSubscriptionId string

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string

@description('Principal type of the specified principal Id')
param azurePrincipalType string = 'ServicePrincipal'

@description('CID for the Falcon API.')
param falconCID string = ''

@description('Client ID for the Falcon API.')
param falconClientId string=''

@description('Client secret for the Falcon API.')
@secure()
param falconClientSecret string=''

@description('Falcon cloud API url')
param falconUrl string = 'api.crowdstrike.com'

@description('IP addresses of Crowdstrike Falcon. Please refer to https://falcon.crowdstrike.com/documentation/page/re07d589/add-crowdstrike-ip-addresses-to-cloud-provider-allowlists-0 for the IP address list of your Falcon region.')
param falconIpAddresses array = [
  '13.52.148.107'
  '52.52.20.134'
  '54.176.76.126'
  '54.176.197.246'
]

@description('Type of the Azure account to integrate.')
@allowed([
  'commercial'
])
param azureAccountType string = 'commercial'

@description('Location for the resources deployed in this solution.')
param region string = deployment().location

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string = 'prod'

@description('Tags to be applied to all resources.')
param tags object = {
  CSTagVendor: 'Crowdstrike'
}

@description('The prefix to be added to the deployment name.')
param deploymentNamePrefix string = ''

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = ''

@description('Settings of feature modules')
param featureSettings FeatureSettings = {
  realTimeVisibilityDetection: {
    enabled: true
    deployActivityLogDiagnosticSettings: true       
    deployActivityLogDiagnosticSettingsPolicy: true 
    deployEntraLogDiagnosticSettings: true          
    enableAppInsights: false                        
  }
}


// ===========================================================================
var crowdstrikeInfraSubscriptionId = length(csInfraSubscriptionId) > 0 ? csInfraSubscriptionId : (length(subscriptionIds) > 0 ? subscriptionIds[0] : '')
var distinctSubscriptionIds = union(subscriptionIds, [csInfraSubscriptionId]) // remove duplicated values
var distinctManagementGroupIds = union(managementGroupIds, []) // remove duplicated values
var prefix = length(deploymentNamePrefix) > 0 ? '${deploymentNamePrefix}-' : ''
var suffix = length(deploymentNameSuffix) > 0 ? '-${deploymentNameSuffix}' : ''

/* Resources used across modules
1. Role assignments to the Crowdstrike's app service principal
2. Discover subscriptions of the specified management groups
*/
module global 'modules/cs-global-mg.bicep' = {
  name: '${prefix}cs-ai-mg-deployment${suffix}'
  params: {
    csInfraSubscriptionId: crowdstrikeInfraSubscriptionId
    managementGroupIds: distinctManagementGroupIds
    subscriptionIds: distinctSubscriptionIds
    azurePrincipalId: azurePrincipalId
    azurePrincipalType: azurePrincipalType
    prefix: prefix
    suffix: suffix
    region: region
    env: env
    tags: tags
  }
}

module logInjection 'modules/cs-log-injection-mg.bicep' = if (featureSettings.realTimeVisibilityDetection.enabled && targetScope == 'ManagementGroup') {
    name: '${prefix}cs-li-mg-deployment${suffix}'
    params: {
      targetScope: targetScope
      managementGroupIds: distinctManagementGroupIds
      subscriptionIds: distinctSubscriptionIds
      csInfraSubscriptionId: crowdstrikeInfraSubscriptionId
      managementGroupsToSubsctiptions: global.outputs.managementGroupsToSubsctiptions
      featureSettings: featureSettings
      falconIpAddresses: falconIpAddresses
      prefix: prefix
      suffix: suffix
      region: region
      env: env
      tags: tags
    }
    dependsOn: [
      global
    ]
}
