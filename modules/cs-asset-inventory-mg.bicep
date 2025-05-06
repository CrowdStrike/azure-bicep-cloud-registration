targetScope='managementGroup'

/*
  This Bicep template deploys infrastructure to enable CrowdStrike
  Indicator of Misconfiguration (IOM)
  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('The prefix to be added to the deployment name.')
param prefix string

@description('The suffix to be added to the deployment name.')
param suffix string

@minLength(36)
@maxLength(36)
@description('Subscription Id of the default Azure Subscription.')
param csInfraSubscriptionId string

@description('List of Azure management group IDs to monitor')
param managementGroupIds array

@description('List of Azure subscription IDs to monitor')
param subscriptionIds array

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string

@description('Type of the Principal')
param azurePrincipalType string

@description('Azure region for the resources deployed in this solution.')
param region string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string

@description('Tags to be applied to all resources.')
param tags object 

var resourceGroupName = '${prefix}rg-csai-${env}${suffix}'

module resourceGroup 'common/resourceGroup.bicep' = {
  name: '${prefix}cs-ai-rg-${env}${suffix}'
  scope: subscription(csInfraSubscriptionId)
  params: {
    resourceGroupName: resourceGroupName
    region: region
    tags: tags
  }
}

module scriptRunnerIdentity 'common/managedIdentity.bicep' = {
  name: '${prefix}cs-ai-id-script-runner-${env}${suffix}'
  scope: az.resourceGroup(csInfraSubscriptionId, resourceGroupName)
  params: {
    name: '${prefix}id-csscriptrunner-${env}${suffix}'
    region: region
    tags: tags
  }
  dependsOn: [
    resourceGroup
  ]
}

/* Define required permissions at Azure Subscription scope */
module customRoleForSubs 'asset-inventory/customRoleForSub.bicep' = {
  name: '${prefix}cs-ai-reader-role-sub-${env}${suffix}'
  scope: subscription(csInfraSubscriptionId)
  params: {
    subscriptionIds: subscriptionIds
    prefix: prefix
    suffix: suffix
    env: env
  }
}

module roleAssignmentToSubs 'asset-inventory/roleAssignmentToSub.bicep' =[for subId in subscriptionIds: {
  name: '${prefix}cs-ai-ra-sub-${subId}-${env}${suffix}'
  scope: subscription(subId)
  params: {
    azurePrincipalId: azurePrincipalId
    azurePrincipalType: azurePrincipalType
    customRoleDefinitionId: customRoleForSubs.outputs.id
    csInfraSubscriptionId: csInfraSubscriptionId
    prefix: prefix
    suffix: suffix
    env: env
  }
}]

/* Define required permissions at Azure Management Group scope */
module customRoleForMGs 'asset-inventory/customRoleForMgmtGroup.bicep' = [for mgmtGroupId in managementGroupIds: {
  name: '${prefix}cs-ai-website-reader-role-mg-${mgmtGroupId}-${env}${suffix}'
  scope: managementGroup(mgmtGroupId)
  params: {
    prefix: prefix
    suffix:suffix
    env: env
  }
}]

module roleAssignmentToMGs 'asset-inventory/roleAssignmentToMgmtGroup.bicep' =[for (mgmtGroupId, i) in managementGroupIds: {
  name: '${prefix}cs-ai-ra-mg-${mgmtGroupId}-${env}${suffix}'
  scope: managementGroup(mgmtGroupId)
  params: {
    scriptRunnerIdentityId:scriptRunnerIdentity.outputs.principalId
    azurePrincipalId: azurePrincipalId
    azurePrincipalType: azurePrincipalType
    customRoleDefinitionId: customRoleForMGs[i].outputs.id
    prefix: prefix
    suffix: suffix
  }
}]

/* Get all enabled Azure subscriptions in the current specified management groups */
module deploymentScope 'common/resolveDeploymentScope.bicep' = [for mgmtGroupId in managementGroupIds: {
  name: '${prefix}cs-ai-deployment-scope-${mgmtGroupId}-${env}${suffix}'
  scope: az.resourceGroup(csInfraSubscriptionId, resourceGroupName)
  params: {
    scriptRunnerIdentityId: scriptRunnerIdentity.outputs.id
    managementGroupId: mgmtGroupId
    env: env
    region: region
    tags: tags
  }
  dependsOn: [
    resourceGroup
  ]
}]

output managementGroupsToSubscriptions array = [for (mgmtGroupId, i) in managementGroupIds: deploymentScope[i].outputs.activeSubscriptions]
output customRoleNameForSubs string = customRoleForSubs.outputs.name
output customRoleNameForMGs array = [for (mgmtGroupId, i) in managementGroupIds: customRoleForMGs[i].outputs.name]