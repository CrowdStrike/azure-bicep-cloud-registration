@description('List of Azure management group IDs to monitor')
param managementGroupIds array

@description('Managed identity Id of the script runner')
param scriptRunnerIdentityId string

@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string

@description('Tags to be applied to all resources.')
param tags object


resource subscriptionsInManagementGroup 'Microsoft.Resources/deploymentScripts@2023-08-01' = [for mgmtGroupId in managementGroupIds: {
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
}]


output subscriptionsByManageGroups array = [for (mgmtGroupId, i) in managementGroupIds: subscriptionsInManagementGroup[i].properties.outputs.activeSubscriptions]
