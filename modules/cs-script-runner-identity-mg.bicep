targetScope='managementGroup'

@description('List of Azure management group IDs to monitor')
param managementGroupIds array

@minLength(36)
@maxLength(36)
@description('Subscription Id of the default Azure Subscription.')
param csInfraSubscriptionId string

@description('Resource group name for the Crowdstrike infrastructure resources')
param resourceGroupName string

@maxLength(10)
@description('The prefix to be added to the resource name.')
param resourceNamePrefix string = ''

@maxLength(10)
@description('The suffix to be added to the resource name.')
param resourceNameSuffix string = ''

@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string

@description('Tags to be applied to all resources.')
param tags object

var environment = length(env) > 0 ? '-${env}' : env

module scriptRunnerIdentity 'common/managedIdentity.bicep' = {
  name: '${resourceNamePrefix}cs-id-script-runner${environment}${resourceNameSuffix}'
  scope: az.resourceGroup(csInfraSubscriptionId, resourceGroupName)
  params: {
    name: '${resourceNamePrefix}id-csscriptrunner${environment}${resourceNameSuffix}'
    location: location
    tags: tags
  }
}

module roleAssignmentToMGs 'script-runner-identity/roleAssignmentToMgmtGroup.bicep' =[for (mgmtGroupId, i) in managementGroupIds: {
  name: '${resourceNamePrefix}cs-inv-ra-mg-${mgmtGroupId}-${env}${resourceNameSuffix}'
  scope: managementGroup(mgmtGroupId)
  params: {
    scriptRunnerIdentityId:scriptRunnerIdentity.outputs.principalId
    env: env
  }
}]

output id string = scriptRunnerIdentity.outputs.id
