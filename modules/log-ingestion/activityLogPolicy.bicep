targetScope = 'managementGroup'

/*
  This Bicep template creates and assigns an Azure Policy used to ensure
  that Activity Log data is forwarded to CrowdStrike for Indicator of Attack (IOA)
  assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string

@minLength(36)
@maxLength(36)
@description('Azure subscription ID that host the target Event Hub for activity log')
param eventhubSubscriptionId string

@description('Azure resource group name that host the target Event Hub for activity log')
param eventhubResourceGroupName string

@description('Event Hub ID for activity log')
param eventhubId string

@description('Event Hub Authorization Rule Id.')
param eventHubAuthorizationRuleId string

@description('Diagnostic settings name of activity log')
param activityLogDiagnosticSettingsName string

@description('Event Hub Name.')
param eventHubName string

@description('The prefix to be added to the resource name.')
param resourceNamePrefix string

@description('The suffix to be added to the resource name.')
param resourceNameSuffix string

/* Variables */
var policyDefinition = json(loadTextContent('../../policies/real-time-visibility-detection/policy.json'))

/* Resources */
resource csRTVDPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: '${resourceNamePrefix}policy-cslogact${resourceNameSuffix}'
  properties: {
    displayName: policyDefinition.properties.displayName
    description: policyDefinition.properties.description
    policyType: policyDefinition.properties.policyType
    metadata: policyDefinition.properties.metadata
    mode: policyDefinition.properties.mode
    parameters: policyDefinition.properties.parameters
    policyRule: policyDefinition.properties.policyRule
  }
}

resource csRTVDPolicyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'pas-cslogact' // The maximum length is 24 characters
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    assignmentType: 'Custom'
    description: 'Ensures that Activity Log data is send to CrowdStrike for Real Time Visibility and Detection assessment.'
    displayName: 'CrowdStrike Real Time Visibility and Detection'
    enforcementMode: 'Default'
    policyDefinitionId: csRTVDPolicyDefinition.id
    parameters: {
      eventHubAuthorizationRuleId: {
        value: eventHubAuthorizationRuleId
      }
      eventHubName: {
        value: eventHubName
      }
      eventHubSubscriptionId: {
        value: eventhubSubscriptionId
      }
      diagnosticSettingName: {
        value: activityLogDiagnosticSettingsName
      }
    }
  }
}

resource csRTVDPolicyRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleDefinitionId in [
    '749f88d5-cbae-40b8-bcfc-e573ddc772fa' // Monitoring Contributor
    '2a5c394f-5eb7-4d4f-9c8e-e8eae39faebc' // Lab Services Reader
    'f526a384-b230-433a-b45c-95f59c4a2dec' // Azure Event Hubs Data Owner
  ]: {
    name: guid(csRTVDPolicyAssignment.id, roleDefinitionId)
    properties: {
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
      principalId: csRTVDPolicyAssignment.identity.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

module eventHubRoleAssignment 'eventHubRoleAssignment.bicep' = {
  name: '${resourceNamePrefix}cs-log-pas-ra-${managementGroup().name}${resourceNameSuffix}'
  scope: az.resourceGroup(eventhubSubscriptionId, eventhubResourceGroupName)
  params: {
    eventHubId: eventhubId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'f526a384-b230-433a-b45c-95f59c4a2dec') // Azure Event Hubs Data Owner
    azurePrincipalId: csRTVDPolicyAssignment.identity.principalId
  }
}
