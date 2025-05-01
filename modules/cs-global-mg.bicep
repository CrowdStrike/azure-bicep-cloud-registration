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

param csInfraSubscriptionId string

param managementGroupIds array

param subscriptionIds array

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string

@description('Type of the Principal')
param azurePrincipalType string

@description('Location for the resources deployed in this solution.')
param region string

param env string

@description('Tags to be applied to all resources.')
param tags object 

module resourceGroup 'common/resourceGroup.bicep' = {
  name: '${prefix}rg-cs-${env}${suffix}'
  scope: subscription(csInfraSubscriptionId)
  params: {
    resourceGroupName: '${prefix}rg-cs-${env}${suffix}'
    region: region
    tags: tags
  }
}

module scriptRunnerIdentity 'common/managedIdentity.bicep' = {
  name: '${prefix}cs-id-script-runner-${env}-${region}${suffix}'
  scope: az.resourceGroup(csInfraSubscriptionId, resourceGroup.name)
  params: {
    name: '${prefix}id-csscriptrunner-${env}-${region}${suffix}'
    region: region
    tags: tags
  }
  dependsOn: [
    resourceGroup
  ]
}

/* Define required permissions at Azure Subscription scope */
module customRoleForSubs 'global/customRoleForSub.bicep' = {
  name: guid('${prefix}cs-website-reader-role-sub${suffix}')
  scope: subscription(csInfraSubscriptionId)
  params: {
    subscriptionIds: subscriptionIds
    prefix: prefix
    suffix: suffix
  }
}

module roleAssignmentToSubs 'global/roleAssignmentToSub.bicep' =[for subId in subscriptionIds: {
  name: guid('${prefix}cs-role-assignment-sub-${subId}${suffix}')
  scope: subscription(subId)
  params: {
    azurePrincipalId: azurePrincipalId
    azurePrincipalType: azurePrincipalType
    customRoleDefinitionId: customRoleForSubs.outputs.id
    prefix: prefix
    suffix: suffix
  }
}]

/* Define required permissions at Azure Management Group scope */
module customRoleForMGs 'global/customRoleForMgmtGroup.bicep' = [for mgmtGroupId in managementGroupIds: {
  name: guid('${prefix}cs-website-reader-role-mg-${mgmtGroupId}${suffix}')
  scope: managementGroup(mgmtGroupId)
  params: {
    prefix: prefix
    suffix:suffix
  }
}]

module roleAssignmentToMGs 'global/roleAssignmentToMgmtGroup.bicep' =[for (mgmtGroupId, i) in managementGroupIds: {
  name: guid('${prefix}cs-role-assignment-mg-${mgmtGroupId}${suffix}')
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
  name: '${prefix}cs-deployment-scope-${mgmtGroupId}${suffix}'
  scope: az.resourceGroup(csInfraSubscriptionId, resourceGroup.name)
  params: {
    scriptRunnerIdentityId: scriptRunnerIdentity.outputs.id
    managementGroupId: mgmtGroupId
    env: env
  }
  dependsOn: [
    resourceGroup
  ]
}]

output managementGroupsToSubsctiptions array = [for (mgmtGroupId, i) in managementGroupIds: deploymentScope[i].outputs.activeSubscriptions]
