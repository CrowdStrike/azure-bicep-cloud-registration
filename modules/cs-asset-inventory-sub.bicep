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

var environment = length(env) > 0 ? '-${env}' : env

module deploymentForSubs 'asset-inventory/assetInventoryForSub.bicep' = [
  for subId in subscriptionIds: {
    name: '${resourceNamePrefix}cs-inv-deployment-sub${environment}${resourceNameSuffix}'
    scope: subscription(subId)
    params: {
      azurePrincipalId: azurePrincipalId
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      env: env
    }
  }
]

output customRoleNameForSubs array = [for (sub, i) in subscriptionIds: deploymentForSubs[i].outputs.customRoleName]
