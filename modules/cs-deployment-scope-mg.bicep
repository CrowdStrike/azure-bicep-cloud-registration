targetScope='managementGroup'

@description('List of Azure management group IDs to monitor. These management groups will be configured for CrowdStrike monitoring.')
param managementGroupIds array

@description('List of Azure subscription IDs to monitor. These subscriptions will be configured for CrowdStrike monitoring.')
param subscriptionIds array

@description('Resource ID of the user-assigned managed identity that will execute deployment scripts. This identity needs appropriate permissions.')
param scriptRunnerIdentityId string

@minLength(36)
@maxLength(36)
@description('Subscription ID where CrowdStrike infrastructure resources will be deployed. This subscription hosts shared resources like Event Hubs.')
param csInfraSubscriptionId string

@description('Name of the resource group where CrowdStrike infrastructure resources will be deployed.')
param resourceGroupName string

@maxLength(10)
@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string = ''

@maxLength(10)
@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string = ''

@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string

@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Tags to be applied to all deployed resources. Used for resource organization, governance, and cost tracking.')
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
