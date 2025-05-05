param scriptRunnerIdentityId string

@description('Management group ID to resolve')
param managementGroupId string

@description('Azure region for the resources deployed in this solution.')
param region string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string

@description('Tags to be applied to all resources.')
param tags object

resource resolveManagementGroupToSubscription 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: guid('resolveManagementGroupToSubscription', managementGroupId, resourceGroup().id, env)
  location: region
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
    arguments: '-AzureTenantId ${tenant().tenantId} -ManagementGroupId "${managementGroupId}"'
    scriptContent: loadTextContent('../../scripts/Resolve-Deployment-Scope.ps1')
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
  }
}

output activeSubscriptions array = resolveManagementGroupToSubscription.properties.outputs.activeSubscriptions
