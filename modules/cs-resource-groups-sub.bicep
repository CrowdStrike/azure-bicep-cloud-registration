import { maxResourceGroupBatchSize } from 'common/resourceGroupBatch.bicep'

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

@description('Maximum number of subscriptions per batch for resource group deployment. Capped at maxResourceGroupBatchSize.')
@minValue(1)
param batchSize int

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env
var filteredSubscriptionIds = filter(
  subscriptionIds,
  subscriptionId => !contains(ignoredSubscriptionIds, subscriptionId)
)

var resourceGroupBatchSize = min(batchSize, maxResourceGroupBatchSize)
var numberOfBatches = (length(filteredSubscriptionIds) + resourceGroupBatchSize - 1) / resourceGroupBatchSize

module resourceGroupBatches 'common/resourceGroupBatch.bicep' = [
  for i in range(0, numberOfBatches): {
    name: '${resourceNamePrefix}cs-rg-batch-${i}${environment}${resourceNameSuffix}'
    params: {
      subscriptionIds: take(skip(filteredSubscriptionIds, i * resourceGroupBatchSize), resourceGroupBatchSize)
      resourceGroupName: resourceGroupName
      location: location
      env: env
      tags: tags
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
    }
  }
]
