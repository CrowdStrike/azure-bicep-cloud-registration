targetScope = 'subscription'

/*
  This Bicep template creates the CrowdStrike resource group in a batch of subscriptions
  to stay under the 800 resource and 4 MB deployment size limits for large numbers of subscriptions.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

@export()
@description('Maximum number of subscriptions per resource group batch, sized to stay within Azure Resource Manager deployment limits. Keep the @maxLength of subscriptionIds equal to it.')
var maxResourceGroupBatchSize = 800

/* Parameters */
@maxLength(800)
@description('Batched list of Azure subscription IDs to create the resource group in. (max: 800)')
param subscriptionIds array

@description('Azure location (aka region) where resource groups will be deployed.')
param location string

@maxLength(4)
@description('Environment label (for example, prod, stag, dev). Used only in the per-subscription deployment names.')
param env string

@description('Tags to be applied to all deployed resources. Used for resource organization and governance.')
param tags object

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

module resourceGroups 'resourceGroup.bicep' = [
  for subscriptionId in subscriptionIds: {
    name: '${resourceNamePrefix}cs-rg-${uniqueString(subscriptionId)}${environment}${resourceNameSuffix}'
    scope: subscription(subscriptionId)
    params: {
      resourceGroupName: resourceGroupName
      location: location
      tags: tags
    }
  }
]
