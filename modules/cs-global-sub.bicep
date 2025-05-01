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

param csInfraSubscriptionId string

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
  name: '${prefix}cs-rg-${env}${suffix}'
  scope: subscription(csInfraSubscriptionId)
  params: {
    resourceGroupName: '${prefix}rg-cs-${env}${suffix}'
    region: region
    tags: tags
  }
}

/* Define required permissions at Azure Subscription scope */
module customRoleForSubs 'global/customRoleForSub.bicep' = {
  name: guid('${prefix}cs-webiste-reader-role-sub${suffix}')
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

