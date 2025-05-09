targetScope='subscription'

/*
  This Bicep template deploys infrastructure to enable CrowdStrike
  Indicator of Misconfiguration (IOM)
  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('The prefix to be added to the deployment name.')
param resourceNamePrefix string

@description('The suffix to be added to the deployment name.')
param resourceNameSuffix string

@minLength(36)
@maxLength(36)
@description('Subscription Id of the default Azure Subscription.')
param csInfraSubscriptionId string

@description('List of Azure subscription IDs to monitor')
param subscriptionIds array

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string

var environment = length(env) > 0 ? '-${env}' : env

/* Define required permissions at Azure Subscription scope */
module customRoleForSubs 'asset-inventory/customRoleForSub.bicep' = {
  name: '${resourceNamePrefix}cs-inv-reader-role-sub${environment}${resourceNameSuffix}'
  scope: subscription(csInfraSubscriptionId)
  params: {
    subscriptionIds: subscriptionIds
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    env: env
  }
}

module roleAssignmentToSubs 'asset-inventory/roleAssignmentToSub.bicep' =[for subId in subscriptionIds: {
  name: '${resourceNamePrefix}cs-inv-ra-sub-${subId}${environment}${resourceNameSuffix}'
  scope: subscription(subId)
  params: {
    azurePrincipalId: azurePrincipalId
    customRoleDefinitionId: customRoleForSubs.outputs.id
    env: env
  }
}]

output customRoleName string = customRoleForSubs.outputs.name

