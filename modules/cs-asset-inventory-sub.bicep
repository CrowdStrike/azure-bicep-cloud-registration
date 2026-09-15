targetScope = 'subscription'

/*
  This Bicep template deploys infrastructure to enable CrowdStrike Asset Inventory
  Copyright (c) 2025 CrowdStrike, Inc.
*/

@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string

@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string

@description('List of Azure subscription IDs to monitor. These subscriptions will be configured for CrowdStrike monitoring.')
param subscriptionIds array

@description('Principal ID of the CrowdStrike application registered in Entra ID. This service principal will be granted necessary permissions.')
param azurePrincipalId string

@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Maximum number of subscriptions per batch for Asset Inventory role assignment deployment.')
param batchSize int

var environment = length(env) > 0 ? '-${env}' : env
var numberOfBatches = (length(subscriptionIds) + batchSize - 1) / batchSize

module deploymentForSubs 'asset-inventory/assetInventorySubBatch.bicep' = [
  for i in range(0, numberOfBatches): {
    name: '${resourceNamePrefix}cs-inv-batch-${i}${environment}${resourceNameSuffix}'
    params: {
      subscriptionIds: take(skip(subscriptionIds, i * batchSize), batchSize)
      azurePrincipalId: azurePrincipalId
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      env: env
      batchNumber: i
    }
  }
]

output customRoleNameForSubs array = [
  for (sub, i) in subscriptionIds: deploymentForSubs[i / batchSize].outputs.customRoleNames[i % batchSize]
]
