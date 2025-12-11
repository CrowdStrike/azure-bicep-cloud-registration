targetScope = 'subscription'

/*
  This Bicep template deploys CrowdStrike Resource Group in specified subscriptions
  Copyright (c) 2025 CrowdStrike, Inc.
*/

/* Parameters */
@description('List of Azure subscription IDs to deploy resource group in.')
param subscriptionIds array

@description('List of Azure subscription IDs from subscriptionIds to ignore.')
param ignoredSubscriptionIds array

@description('Azure location (aka region) where resource groups will be deployed.')
param location string

@maxLength(4)
@description('Environment label (for example, prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string = 'prod'

@description('Tags to be applied to all deployed resources. Used for resource organization and governance.')
param tags object = {
  CSTagVendor: 'CrowdStrike'
}
@description('Name of the resource group where CrowdStrike infrastructure resources will be deployed.')
param resourceGroupName string

@maxLength(10)
@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string = ''

@maxLength(10)
@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string = ''

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env
var filteredSubscriptionIds = filter(
  subscriptionIds,
  subscriptionId => !contains(ignoredSubscriptionIds, subscriptionId)
)

module resourceGroups 'common/resourceGroup.bicep' = [
  for subscriptionId in filteredSubscriptionIds: {
    name: '${resourceNamePrefix}cs-rg-${uniqueString(subscriptionId)}${environment}${resourceNameSuffix}'
    scope: subscription(subscriptionId)
    params: {
      resourceGroupName: resourceGroupName
      location: location
      tags: tags
    }
  }
]
