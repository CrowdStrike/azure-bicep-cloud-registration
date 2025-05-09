/*
  This Bicep template resolves Azure management groups to their constituent subscriptions for deployment scope determination.
  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('List of Azure management group IDs to monitor. These management groups will be configured for CrowdStrike monitoring.')
param managementGroupIds array

@description('Resource ID of the user-assigned managed identity that will execute deployment scripts. This identity needs appropriate permissions.')
param scriptRunnerIdentityId string

@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string

@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Tags to be applied to all deployed resources. Used for resource organization, governance, and cost tracking.')
param tags object

resource subscriptionsInManagementGroup 'Microsoft.Resources/deploymentScripts@2023-08-01' = [
  for mgmtGroupId in managementGroupIds: {
    name: guid('resolveManagementGroupToSubscription', mgmtGroupId, resourceGroup().id, env)
    location: location
    kind: 'AzurePowerShell'
    tags: tags
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${scriptRunnerIdentityId}': {}
      }
    }
    properties: {
      azPowerShellVersion: '12.3'
      arguments: '-AzureTenantId ${tenant().tenantId} -ManagementGroupId "${mgmtGroupId}"'
      scriptContent: loadTextContent('../../scripts/Resolve-Deployment-Scope.ps1')
      retentionInterval: 'PT1H'
      cleanupPreference: 'OnSuccess'
    }
  }
]

output subscriptionsByManageGroups array = [
  for (mgmtGroupId, i) in managementGroupIds: subscriptionsInManagementGroup[i].properties.outputs.activeSubscriptions
]
