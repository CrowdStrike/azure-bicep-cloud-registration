targetScope = 'subscription'

/*
  This Bicep template handles batched Asset Inventory role assignment deployment
  to overcome the 800 iteration limit for large numbers of subscriptions.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

/* Parameters */
@maxLength(800)
@description('List of Azure subscription IDs to monitor. These subscriptions will be configured for CrowdStrike monitoring. (max: 800)')
param subscriptionIds array

@description('Principal ID of the CrowdStrike application registered in Entra ID. This service principal will be granted necessary permissions.')
param azurePrincipalId string

@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string

@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string

@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Batch number for unique naming')
param batchNumber int

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env

/* Deploy Asset Inventory role assignments for subscriptions in this batch */
module deploymentForSubs 'assetInventoryForSub.bicep' = [
  for subId in subscriptionIds: {
    name: '${resourceNamePrefix}cs-inv-deployment-sub-${batchNumber}-${uniqueString(subId)}${environment}${resourceNameSuffix}'
    scope: subscription(subId)
    params: {
      azurePrincipalId: azurePrincipalId
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      env: env
    }
  }
]

/* Outputs */
output customRoleNames array = [for (subId, i) in subscriptionIds: deploymentForSubs[i].outputs.customRoleName]
