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
@description('Targetscope of the Falcon Cloud Security integration.')
@allowed([
  'ManagementGroup'
  'Subscription'
])
param targetScope string = 'Subscription'

@description('List of Azure subscription IDs to monitor')
param subscriptionIds array = []

@minLength(32)
@maxLength(32)
@description('CID for the Falcon API.')
param falconCID string

@description('Client ID for the Falcon API.')
param falconClientId string

@description('Client secret for the Falcon API.')
@secure()
param falconClientSecret string

@description('Falcon cloud region. Defaults to US-1, allowed values are US-1, US-2 or EU-1.')
@allowed([
  'US-1'
  'US-2'
  'EU-1'
])
param falconCloudRegion string = 'US-1'

@description('Azure subscription ID that will host CrowdStrike infrastructure')
param crowdstrikeInfraSubscriptionId string

@description('Principal Id of the Application Registration in Entra ID. Only used with parameter useExistingAppRegistration.')
param azurePrincipalId string

@description('Type of the Azure account to integrate.')
@allowed([
  'commercial'
])
param azureAccountType string = 'commercial'

@description('Location for the resources deployed in this solution.')
param location string = deployment().location

@description('Tags to be applied to all resources.')
param tags object = {
  'cstag-vendor': 'crowdstrike'
  'stack-managed': 'true'
}

@description('The prefix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs'

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = ''

param featureSettings FeatureSettings = {
  assetInventory: {
    enabled: true
    assignAzureSubscriptionPermissions: true 
    resourceGroupName: 'cs-iom-group' // DO NOT CHANGE. 
  }
  realTimeVisibilityDetection: {
    enabled: true
    deployActivityLogDiagnosticSettings: true       
    deployActivityLogDiagnosticSettingsPolicy: true 
    deployEntraLogDiagnosticSettings: true          
    enableAppInsights: false                        
    resourceGroupName: 'cs-ioa-group' // DO NOT CHANGE. 
  }
}


// ===========================================================================
var distinctSubscriptionIds = union(subscriptionIds, []) // remove duplicated values

module assetInventory 'modules/cs-asset-inventory-sub.bicep' = if (featureSettings.assetInventory.enabled) {
  name: '${deploymentNamePrefix}-asset-inventory-deployment-${deploymentNameSuffix}'
  params: {
    subscriptionIds: distinctSubscriptionIds
    azurePrincipalId: azurePrincipalId
    deploymentNamePrefix: deploymentNamePrefix
    deploymentNameSuffix: deploymentNameSuffix
    location: location
    tags: tags
  }
}


module realTimeVisibilityDetection 'modules/cs-real-time-visibility-detection-sub.bicep' = if (featureSettings.realTimeVisibilityDetection.enabled) {
  name: '${deploymentNamePrefix}-real-time-visibility-detection-sub-deployment-${deploymentNameSuffix}'
  scope: subscription(crowdstrikeInfraSubscriptionId)
  params: {
    targetScope: targetScope
    defaultSubscriptionId: crowdstrikeInfraSubscriptionId // DO NOT CHANGE
    subscriptionIds: distinctSubscriptionIds
    deploymentNamePrefix: deploymentNamePrefix
    deploymentNameSuffix: deploymentNameSuffix
    featureSettings: featureSettings.realTimeVisibilityDetection
    location: location
    tags: tags
  }
}
