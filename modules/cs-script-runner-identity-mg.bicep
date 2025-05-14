targetScope = 'managementGroup'

/*
  This Bicep template creates a user-assigned managed identity for executing deployment scripts
  and assigns necessary permissions at the management group level.
  Copyright (c) 2025 CrowdStrike, Inc.
*/

@description('List of Azure management group IDs to monitor. These management groups will be configured for CrowdStrike monitoring.')
param managementGroupIds array

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

module scriptRunnerIdentity 'common/managedIdentity.bicep' = {
  name: '${resourceNamePrefix}cs-id-script-runner${environment}${resourceNameSuffix}'
  scope: az.resourceGroup(csInfraSubscriptionId, resourceGroupName)
  params: {
    name: '${resourceNamePrefix}id-csscriptrunner${environment}${resourceNameSuffix}'
    location: location
    tags: tags
  }
}

module roleAssignmentToMGs 'script-runner-identity/roleAssignmentToMgmtGroup.bicep' = [
  for (mgmtGroupId, i) in managementGroupIds: {
    name: '${resourceNamePrefix}cs-inv-ra-mg${environment}${resourceNameSuffix}'
    scope: managementGroup(mgmtGroupId)
    params: {
      scriptRunnerIdentityId: scriptRunnerIdentity.outputs.principalId
      env: env
    }
  }
]

// Need to assign Reader role in infra subscription so that the script can set context to the subscription
// The reason why we need to do this is because that we can only guarantee "Microsoft.Management" resource provider is registered here.
module roleAssignmentToInfraSub 'script-runner-identity/roleAssignmentToSub.bicep' = {
  name: '${resourceNamePrefix}cs-inv-ra-infra-sub${environment}${resourceNameSuffix}'
  scope: subscription(csInfraSubscriptionId)
  params: {
    scriptRunnerIdentityId: scriptRunnerIdentity.outputs.principalId
    env: env
  }
}

output id string = scriptRunnerIdentity.outputs.id
