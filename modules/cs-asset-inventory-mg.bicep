import {AssetInventorySettings} from '../models/asset-inventory.bicep'

targetScope='managementGroup'

/*
  This Bicep template deploys infrastructure to enable CrowdStrike
  Indicator of Misconfiguration (IOM)
  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('The prefix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs'

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = ''

param managementGroupIds array

param subscriptionIds array

@description('Principal Id of the Application Registration in Entra ID.')
param azurePrincipalId string = ''

@description('Type of the Principal, defaults to ServicePrincipal.')
param azurePrincipalType string = 'ServicePrincipal'

@description('Location for the resources deployed in this solution.')
param location string = deployment().location

@description('Tags to be applied to all resources.')
param tags object = {
  'cstag-vendor': 'crowdstrike'
}

@description('Settings of asset inventory')
param featureSettings AssetInventorySettings = {
  enabled: true
  assignAzureSubscriptionPermissions: true
  resourceGroupName: 'cs-iom-group' // DO NOT CHANGE
}

/* Define required permissions at Azure Subscription scope */
module customRoleForSubs 'asset-inventory/customRoleForSub.bicep' = if (featureSettings.assignAzureSubscriptionPermissions && length(subscriptionIds) > 0) {
  name: guid('${deploymentNamePrefix}-assetInventorySubscriptionCustomRole-${deploymentNameSuffix}')
  scope: subscription(subscriptionIds[0])
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

/* Define required permissions at Azure Management Group scope */
module customRoleForMGs 'asset-inventory/customRoleForMgmtGroup.bicep' = [for mgmtGroupId in managementGroupIds: if(featureSettings.assignAzureSubscriptionPermissions) {
  name: guid('${deploymentNamePrefix}-assetInventoryManagementGroupCustomRole-${deploymentNameSuffix}')
  scope: managementGroup(mgmtGroupId)
  params: {
    deploymentNamePrefix: deploymentNamePrefix
    deploymentNameSuffix:deploymentNameSuffix
  }
}]

module roleAssignmentToMGs 'asset-inventory/roleAssignmentToMgmtGroup.bicep' =[for (mgmtGroupId, i) in managementGroupIds: if (featureSettings.assignAzureSubscriptionPermissions) {
  name: guid('${deploymentNamePrefix}-assetInventoryManagementGroupRoleAssignment-${mgmtGroupId}-${deploymentNameSuffix}')
  scope: managementGroup(mgmtGroupId)
  params: {
    azurePrincipalId: azurePrincipalId
    azurePrincipalType: azurePrincipalType
    customRoleDefinitionId: customRoleForMGs[i].outputs.id
    deploymentNamePrefix: deploymentNamePrefix
    deploymentNameSuffix: deploymentNameSuffix
  }
}]
