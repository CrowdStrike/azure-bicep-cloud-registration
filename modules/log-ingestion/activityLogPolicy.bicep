targetScope = 'managementGroup'

/*
  This Bicep template creates and assigns an Azure Policy used to ensure
  that Activity Log data is forwarded to CrowdStrike for Indicator of Attack (IOA)
  assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('The Azure region for the resources deployed in this solution.')
param region string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string

@description('Event Hub Authorization Rule Id.')
param eventHubAuthorizationRuleId string

@description('Event Hub Name.')
param eventHubName string

@description('Settings for creating policy for Real Time Visibility and Detection')
param csRTVDPolicySettings object = {
  name: 'Activity Logs must be sent to CrowdStrike for Real Time Visibility and Detection assessment'
  policyDefinition: json(loadTextContent('../../policies/real-time-visibility-detection/policy.json'))
  parameters: {}
  identity: true
}

@description('The prefix to be added to the deployment name.')
param prefix string

@description('The suffix to be added to the deployment name.')
param suffix string

/* Variables */
var roleDefinitionIds = [
  '749f88d5-cbae-40b8-bcfc-e573ddc772fa' // Monitoring Contributor
  '2a5c394f-5eb7-4d4f-9c8e-e8eae39faebc' // Lab Services Reader
  'f526a384-b230-433a-b45c-95f59c4a2dec' // Azure Event Hubs Data Owner
]

/* Resources */
resource csRTVDPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: guid(csRTVDPolicySettings.name)
  properties: {
    displayName: csRTVDPolicySettings.policyDefinition.properties.displayName
    description: csRTVDPolicySettings.policyDefinition.properties.description
    policyType: csRTVDPolicySettings.policyDefinition.properties.policyType
    metadata: csRTVDPolicySettings.policyDefinition.properties.metadata
    mode: csRTVDPolicySettings.policyDefinition.properties.mode
    parameters: csRTVDPolicySettings.policyDefinition.properties.parameters
    policyRule: csRTVDPolicySettings.policyDefinition.properties.policyRule
  }
}

resource csRTVDPolicyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: '${prefix}pas-csli-${env}${suffix}' // The maximum length is 24 characters
  location: region
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
    }
  }
}

resource csRTVDPolicyRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleDefinitionId in roleDefinitionIds: {
    name: guid(csRTVDPolicyAssignment.id, roleDefinitionId)
    properties: {
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
      principalId: csRTVDPolicyAssignment.identity.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

/* Create remediation task for the IOA policy assignment */
resource csRTVDPolicyRemediation 'Microsoft.PolicyInsights/remediations@2021-10-01' = {
  name: guid('Remediate', csRTVDPolicyDefinition.id, managementGroup().id)
  properties: {
    failureThreshold: {
      percentage: 1
    }
    resourceCount: 500
    policyAssignmentId: csRTVDPolicyAssignment.id
    policyDefinitionReferenceId: csRTVDPolicyDefinition.id
    parallelDeployments: 10
    resourceDiscoveryMode: 'ExistingNonCompliant'
  }
}
