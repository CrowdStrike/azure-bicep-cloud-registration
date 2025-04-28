import {AssetInventorySettings} from '../models/asset-inventory.bicep'

targetScope='subscription'

/*
  This Bicep template deploys infrastructure to enable CrowdStrike
  Indicator of Misconfiguration (IOM)
  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('The prefix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs'

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = ''

param defaultSubscriptionId string

param subscriptionIds array

@description('Principal Id of the Application Registration in Entra ID.')
param azurePrincipalId string = ''

@description('Type of the Principal, defaults to ServicePrincipal.')
param azurePrincipalType string = 'ServicePrincipal'

@description('Location for the resources deployed in this solution.')
param location string = deployment().location

@description('Tags to be applied to all resources.')
param tags object = {
  CSTagVendor: 'CrowdStrike'
}

@description('Settings of asset inventory')
param featureSettings AssetInventorySettings = {
  assignAzureSubscriptionPermissions: true
  resourceGroupName: 'cs-iom-group' // DO NOT CHANGE
}


module resourceGroup 'common/resourceGroup.bicep' = {
  name: '${deploymentNameSuffix}-ai-rg-${location}-${deploymentNameSuffix}'
  scope: subscription(defaultSubscriptionId)
  params: {
    resourceGroupName: '${deploymentNameSuffix}-ai-rg-${location}-${deploymentNameSuffix}'
    location: location
    tags: tags
  }
}

/* Define required permissions at Azure Subscription scope */
module customRoleForSubs 'asset-inventory/customRoleForSub.bicep' = if (featureSettings.assignAzureSubscriptionPermissions) {
  name: guid('${deploymentNamePrefix}-assetInventorySubscriptionCustomRole-${deploymentNameSuffix}')
  scope: subscription(defaultSubscriptionId)
  params: {
    subscriptionIds: subscriptionIds
    deploymentNamePrefix: deploymentNamePrefix
    deploymentNameSuffix: deploymentNameSuffix
  }
}

module roleAssignmentToSubs 'asset-inventory/roleAssignmentToSub.bicep' =[for subId in subscriptionIds: if (featureSettings.assignAzureSubscriptionPermissions) {
  name: guid('${deploymentNamePrefix}-assetInventorySubscriptionRoleAssignment-${subId}-${deploymentNameSuffix}')
  scope: subscription(subId)
  params: {
    azurePrincipalId: azurePrincipalId
    azurePrincipalType: azurePrincipalType
    customRoleDefinitionId: customRoleForSubs.outputs.id
    deploymentNamePrefix: deploymentNamePrefix
    deploymentNameSuffix: deploymentNameSuffix
  }
}]

