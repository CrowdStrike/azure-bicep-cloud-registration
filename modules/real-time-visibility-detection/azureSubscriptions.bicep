@description('Id of the user-assigned Managed Identity with Reader access to all Azure Subscriptions.')
param activityLogIdentityId string

resource azureSubscriptions 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'cs-ioa-azureSubscriptions-${tenant().tenantId}'
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${activityLogIdentityId}': {}
    }
  }
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '12.3'
    arguments: '-AzureTenantId ${tenant().tenantId}'
    scriptContent: '''
      param([string] $AzureTenantId)
      $DeploymentScriptOutputs = @{}
      $activeSubscriptions = Get-AzSubscription | ? {($_.State -eq "Enabled") -and ($_.TenantId -eq $AzureTenantId)} | Select-Object -ExpandProperty Id
      $DeploymentScriptOutputs['subscriptions'] = $activeSubscriptions
    '''
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
  }
}

output activeAzureSubscriptions array = azureSubscriptions.properties.outputs.subscriptions
