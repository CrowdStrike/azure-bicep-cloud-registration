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

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string = ''

@description('Type of the Principal, defaults to ServicePrincipal.')
param azurePrincipalType string = 'ServicePrincipal'

@description('Location for the resources deployed in this solution.')
param region string = deployment().location

@description('Tags to be applied to all resources.')
param tags object = {
  CSTagVendor: 'Crowdstrike'
}

module resourceGroup 'common/resourceGroup.bicep' = {
  name: '${deploymentNamePrefix}-cs-rg-${region}-${deploymentNameSuffix}'
  scope: subscription(defaultSubscriptionId)
  params: {
    resourceGroupName: '${deploymentNamePrefix}-cs-rg-${region}-${deploymentNameSuffix}'
    region: region
    tags: tags
  }
}

module scriptRunnerIdentity 'common/managedIdentity.bicep' = {
  name: '${deploymentNamePrefix}-cs-id-script-runner-${region}-${deploymentNameSuffix}'
  scope: az.resourceGroup(defaultSubscriptionId, resourceGroup.name)
  params: {
    name: '${deploymentNamePrefix}-cs-id-script-runner-${region}-${deploymentNameSuffix}'
    region: region
    tags: tags
  }
}

/* Define required permissions at Azure Subscription scope */
module customRoleForSubs 'global/customRoleForSub.bicep' = {
  name: guid('${deploymentNamePrefix}-cs-webiste-reader-role-sub-${deploymentNameSuffix}')
  scope: subscription(defaultSubscriptionId)
  params: {
    subscriptionIds: subscriptionIds
    deploymentNamePrefix: deploymentNamePrefix
    deploymentNameSuffix: deploymentNameSuffix
  }
}

module roleAssignmentToSubs 'global/roleAssignmentToSub.bicep' =[for subId in subscriptionIds: {
  name: guid('${deploymentNamePrefix}-cs-role-assignment-sub-${subId}-${deploymentNameSuffix}')
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
module customRoleForMGs 'global/customRoleForMgmtGroup.bicep' = [for mgmtGroupId in managementGroupIds: {
  name: guid('${deploymentNamePrefix}-cs-website-reader-role-mg-${mgmtGroupId}-${deploymentNameSuffix}')
  scope: managementGroup(mgmtGroupId)
  params: {
    deploymentNamePrefix: deploymentNamePrefix
    deploymentNameSuffix:deploymentNameSuffix
  }
}]

module roleAssignmentToMGs 'global/roleAssignmentToMgmtGroup.bicep' =[for (mgmtGroupId, i) in managementGroupIds: {
  name: guid('${deploymentNamePrefix}-cs-role-assignment-mg-${mgmtGroupId}-${deploymentNameSuffix}')
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
  name: '${deploymentNamePrefix}-cs-deployment-scope-${mgmtGroupId}-${deploymentNameSuffix}'
  scope: az.resourceGroup(defaultSubscriptionId, resourceGroup.name)
  params: {
    scriptRunnerIdentityId: scriptRunnerIdentity.outputs.id
    managementGroupId: managementGroup().id
  }
}]

output managementGroupsToSubsctiptions array = [for (mgmtGroupId, i) in managementGroupIds: deploymentScope[i].outputs.activeSubscriptions]
