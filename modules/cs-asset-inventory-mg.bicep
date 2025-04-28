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

param defaultSubscriptionId string

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
  assignAzureSubscriptionPermissions: true
  resourceGroupName: 'cs-iom-group' // DO NOT CHANGE
}

module resourceGroup 'common/resourceGroup.bicep' = {
  name: '${deploymentNamePrefix}-ai-rg-${location}-${deploymentNameSuffix}'
  scope: subscription(defaultSubscriptionId)
  params: {
    resourceGroupName: '${deploymentNamePrefix}-ai-rg-${location}-${deploymentNameSuffix}'
    location: location
    tags: tags
  }
}

module scriptRunnerIdentity 'asset-inventory/scriptRunnerIdentity.bicep' = {
  name: '${deploymentNamePrefix}-ai-script-runner-mi-${deploymentNameSuffix}'
  scope: az.resourceGroup(defaultSubscriptionId, resourceGroup.name)
  params: {
    name: '${deploymentNamePrefix}-ai-script-runner-mi-${deploymentNameSuffix}'
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
    scriptRunnerIdentityId:scriptRunnerIdentity.outputs.principalId
    azurePrincipalId: azurePrincipalId
    azurePrincipalType: azurePrincipalType
    customRoleDefinitionId: customRoleForMGs[i].outputs.id
    deploymentNamePrefix: deploymentNamePrefix
    deploymentNameSuffix: deploymentNameSuffix
  }
}]

/* Get all enabled Azure subscriptions in the current specified management groups */
module deploymentScope 'common/resolveDeploymentScope.bicep' = [for mgmtGroupId in managementGroupIds: {
  name: '${deploymentNamePrefix}-ai-deployment-scope-${mgmtGroupId}-${deploymentNameSuffix}'
  scope: az.resourceGroup(defaultSubscriptionId, featureSettings.resourceGroupName)
  params: {
    scriptRunnerIdentityId: scriptRunnerIdentity.outputs.id
    managementGroupId: managementGroup().id
  }
}]

output managementGroupsToSubsctiptions array = [for (mgmtGroupId, i) in managementGroupIds: deploymentScope[i].outputs.activeSubscriptions]
