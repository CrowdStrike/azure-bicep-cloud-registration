param scriptRunnerIdentityId string

@description('Management group ID to resolve')
param managementGroupId string

param location string = resourceGroup().location

@description('Tags to be applied to all resources.')
param tags object = {
  'cstag-vendor': 'crowdstrike'
  'stack-managed': 'true'
}

resource resolveManagementGroupToSubscription 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: guid('resolveManagementGroupToSubscription', managementGroupId, resourceGroup().id)
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
    arguments: '-AzureTenantId ${tenant().tenantId} -ManagementGroupId "${managementGroupId}"'
    scriptContent: loadTextContent('../../scripts/Resolve-Deployment-Scope.ps1')
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
  }
}

output activeSubscriptions array = resolveManagementGroupToSubscription.properties.outputs.activeSubscriptions
