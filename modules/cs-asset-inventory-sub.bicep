targetScope='subscription'

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

var resourceGroupName = '${prefix}rg-cs-${env}${suffix}'

module resourceGroup 'common/resourceGroup.bicep' = {
  name: '${prefix}cs-ai-rg-${env}${suffix}'
  scope: subscription(csInfraSubscriptionId)
  params: {
    resourceGroupName: resourceGroupName
    region: region
    tags: tags
  }
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

output customRoleName string = customRoleForSubs.outputs.name

