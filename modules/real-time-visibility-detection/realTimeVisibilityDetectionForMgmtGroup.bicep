import {RealTimeVisibilityDetectionSettings} from '../../models/real-time-visibility-detection.bicep'

targetScope = 'managementGroup'

/*
  This Bicep template deploys Azure Activity Log Diagnostic Settings
  to existing Azure subscriptions in the current Entra Id tenant
  to enable CrowdStrike Indicator of Attack (IOA) assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('Targetscope of the Falcon Cloud Security integration.')
@allowed([
  'ManagementGroup'
  'Subscription'
])
param targetScope string = 'ManagementGroup'

@minLength(36)
@maxLength(36)
@description('Subscription Id of the default Azure Subscription.')
param defaultSubscriptionId string

@description('The prefix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs'

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = ''

@description('Id of the user-assigned Managed Identity with Reader access to all Azure Subscriptions.')
param activityLogIdentityId string

@description('Event Hub Authorization Rule Id.')
param eventHubAuthorizationRuleId string

@description('Event Hub Name.')
param eventHubName string

param featureSettings RealTimeVisibilityDetectionSettings = {
  enabled: true
  deployActivityLogDiagnosticSettings: true
  deployEntraLogDiagnosticSettings: true
  deployActivityLogDiagnosticSettingsPolicy: true
  enableAppInsights: false
  resourceGroupName: 'cs-ioa-group'
}

@description('Location for the resources deployed in this solution.')
param location string = deployment().location

@description('Tags to be applied to all resources.')
param tags object = {
  'cstag-vendor': 'crowdstrike'
  'stack-managed': 'true'
}

/* Variables */
var scope = az.resourceGroup(defaultSubscriptionId, resourceGroup.name)

/* Resource Deployment */
resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: featureSettings.resourceGroupName
  scope: subscription(defaultSubscriptionId)
}

/* Get all enabled Azure subscriptions in the current Entra Id tenant */
module deploymentScope '../common/resolveDeploymentScope.bicep' = {
  name: '${deploymentNamePrefix}-deploymentScope-${managementGroup().name}-${deploymentNameSuffix}'
  scope: scope
  params: {
    scriptRunnerIdentityId: activityLogIdentityId
    managementGroupId: managementGroup().id
  }
}

module activityLogDiagnosticSettings 'activityLogDiagnosticSettings.bicep' = if(featureSettings.deployActivityLogDiagnosticSettings) {
  name: '${deploymentNamePrefix}-activityLog-${managementGroup().name}-${deploymentNameSuffix}'
  scope: subscription(defaultSubscriptionId)
  params: {
    subscriptionIds: deploymentScope.outputs.activeSubscriptions
    eventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    eventHubName: eventHubName
  }
}

module activityLogDiagnosticSettingsPolicyAssignment 'activityLogPolicy.bicep' = if (featureSettings.deployActivityLogDiagnosticSettingsPolicy) {
  name: '${deploymentNamePrefix}-azurePolicyAssignment-${deploymentNameSuffix}'
  params: {
    eventHubName: eventHubName
    eventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    location: location
  }
}
