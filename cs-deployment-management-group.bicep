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

@description('Settings of feature modules')
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
var defaultSubscriptionId = length(crowdstrikeInfraSubscriptionId) > 0 ? crowdstrikeInfraSubscriptionId : (length(subscriptionIds) > 0 ? subscriptionIds[0] : '')
var distinctSubscriptionIds = union(subscriptionIds, [defaultSubscriptionId]) // remove duplicated values
var distinctManagementGroupIds = union(managementGroupIds, []) // remove duplicated values

module assetInventory 'modules/cs-asset-inventory-mg.bicep' = {
  name: '${deploymentNamePrefix}-asset-inventory-mg-deployment-${deploymentNameSuffix}'
  params: {
    defaultSubscriptionId: defaultSubscriptionId
    managementGroupIds: distinctManagementGroupIds
    subscriptionIds: distinctSubscriptionIds
    azurePrincipalId: azurePrincipalId
    deploymentNamePrefix: deploymentNamePrefix
    deploymentNameSuffix: deploymentNameSuffix
    featureSettings: featureSettings.assetInventory
    location: location
    tags: tags
  }
}

module realTimeVisibilityDetection 'modules/cs-real-time-visibility-detection-mg.bicep' = if (featureSettings.realTimeVisibilityDetection.enabled && targetScope == 'ManagementGroup') {
    name: '${deploymentNamePrefix}-ioa-activityLogDiagnosticSettingsDeployment-${deploymentNameSuffix}'
    params: {
      targetScope: targetScope
      managementGroupIds: distinctManagementGroupIds
      subscriptionIds: distinctSubscriptionIds
      defaultSubscriptionId: defaultSubscriptionId
      managementGroupsToSubsctiptions: assetInventory.outputs.managementGroupsToSubsctiptions
      featureSettings: featureSettings.realTimeVisibilityDetection
      deploymentNamePrefix: deploymentNamePrefix
      deploymentNameSuffix: deploymentNameSuffix
      location: location
      tags: tags
    }
}
