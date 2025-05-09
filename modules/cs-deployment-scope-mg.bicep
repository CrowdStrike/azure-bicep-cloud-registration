targetScope='managementGroup'

@description('List of Azure management group IDs to monitor')
param managementGroupIds array

@description('List of Azure subscription IDs to monitor')
param subscriptionIds array

@description('Managed identity Id of the script runner')
param scriptRunnerIdentityId string

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

/* Get all enabled Azure subscriptions in the current specified management groups */
module deploymentScope 'deployment-scope/resolveDeploymentScope.bicep' = {
  name: '${resourceNamePrefix}cs-deployment-scope${environment}${resourceNameSuffix}'
  scope: az.resourceGroup(csInfraSubscriptionId, resourceGroupName)
  params: {
    scriptRunnerIdentityId: scriptRunnerIdentityId
    managementGroupIds: managementGroupIds
    env: env
    location: location
    tags: tags
  }
}

output subscriptionsByManagementGroup array = [for (mgmtGroupId, i) in managementGroupIds: {
  managementGroupId: mgmtGroupId
  activeSubscriptionIds: deploymentScope.outputs.subscriptionsByManageGroups[i]
}]
output allSubscriptions array = union(flatten(deploymentScope.outputs.subscriptionsByManageGroups), subscriptionIds)
