import {DiagnosticLogSettings} from '../../models/real-time-visibility-detection.bicep'

@description('Settings for configuring Event Hub for activity log')
param activityLogSettings DiagnosticLogSettings

@description('Settings for configuring Event Hub for Entra ID log')
param entraLogSettings DiagnosticLogSettings

@description('Name of authorization rule allowing sending activity and Entra ID logs to Event Hub')
param authorizationRuleName string = 'rule-cslievhns-${env}-${region}'

@description('List of IP addresses of Crowdstrike Falcon service. Please refer to https://falcon.crowdstrike.com/documentation/page/re07d589/add-crowdstrike-ip-addresses-to-cloud-provider-allowlists-0 for the IP address list of your Falcon region.')
param falconIpAddresses array

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string

@description('Type of the Principal')
param azurePrincipalType string

@description('Toggle if the eventhub for activity log should be deployed')
param activityLogEnabled bool

@description('Toggle if the eventhub for Entra ID log should be deployed')
param entraLogEnabled bool

@description('The prefix to be added to the deployment name.')
param prefix string

@description('The suffix to be added to the deployment name.')
param suffix string

@description('Azure region for the resources deployed in this solution.')
param region string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string

@description('Tags to be applied to all resources.')
param tags object

var defaultSettings = {
  eventHubNamespace: 'evhns-csli-${env}-${region}'
  activityLogEventHubName: 'evh-csliactivity-${env}-${region}'
  entraLogEventHubName: 'evh-cslientid-${env}-${region}'
}
var shouldDeployActivityLog = activityLogEnabled && !activityLogSettings.useExistingEventHub
var shouldDeployEntraLog = entraLogEnabled && !entraLogSettings.useExistingEventHub

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = if (shouldDeployActivityLog || shouldDeployEntraLog) {
  name: '${prefix}${defaultSettings.eventHubNamespace}${suffix}'
  location: region
  tags: tags
  sku: {
    capacity: 2
    name: 'Standard'
    tier: 'Standard'
  }
  identity: {
    type: 'None'
  }
  properties: {
    disableLocalAuth: true
    isAutoInflateEnabled: true
    maximumThroughputUnits: 10
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// Allow Crowdstrike Falcon to access the Eventhub
resource eventHubNamespaceNetworkRuleSet 'Microsoft.EventHub/namespaces/networkRuleSets@2024-01-01' = if (shouldDeployActivityLog || shouldDeployEntraLog) {
  name: 'default' // This is fixed
  parent: eventHubNamespace
  properties: {
    defaultAction: 'Deny'
    ipRules: [for ip in falconIpAddresses: {
        action: 'Allow'
        ipMask: '${ip}'
      }
    ]
    publicNetworkAccess: 'Enabled'
    trustedServiceAccessEnabled: true
  }
}

// Azure Event Hubs Data Receiver
var eventHubsDataReceiverRole = 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde'
resource activityLogIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (shouldDeployActivityLog || shouldDeployEntraLog) {
  name: guid(azurePrincipalId, eventHubsDataReceiverRole, resourceGroup().id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', eventHubsDataReceiverRole)
    principalId: azurePrincipalId
    principalType: azurePrincipalType
  }
}

resource existingActivityLogEventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' existing = if (!shouldDeployActivityLog) {
  name: activityLogSettings.eventHubNamespaceName
  scope: resourceGroup(activityLogSettings.eventHubSubscriptionId, activityLogSettings.eventHubResourceGroupName)
}

resource existingEntraLogEventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' existing = if (!shouldDeployEntraLog) {
  name: entraLogSettings.eventHubNamespaceName
  scope: resourceGroup(entraLogSettings.eventHubSubscriptionId, entraLogSettings.eventHubResourceGroupName)
}

resource activityLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = if (shouldDeployActivityLog) {
  name: '${prefix}${defaultSettings.activityLogEventHubName}${suffix}'
  parent: eventHubNamespace
  properties: {
    partitionCount: 16
    retentionDescription: {
      cleanupPolicy: 'Delete'
      retentionTimeInHours: 24
    }
  }
}

resource existingActivityLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' existing = if (!shouldDeployActivityLog) {
  name: activityLogSettings.eventHubName
  parent: existingActivityLogEventHubNamespace
}

resource entraLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = if (shouldDeployEntraLog) {
  name: '${prefix}${defaultSettings.entraLogEventHubName}${suffix}'
  parent: eventHubNamespace
  properties: {
    partitionCount: 16
    retentionDescription: {
      cleanupPolicy: 'Delete'
      retentionTimeInHours: 24
    }
  }
}

resource existingEntraLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' existing = if (!shouldDeployEntraLog) {
  name: entraLogSettings.eventHubName
  parent: existingEntraLogEventHubNamespace
}

resource authorizationRule 'Microsoft.EventHub/namespaces/authorizationRules@2024-01-01' = if (shouldDeployActivityLog || shouldDeployEntraLog) {
  name: '${prefix}${authorizationRuleName}${suffix}'
  parent: eventHubNamespace
  properties: {
    rights: [
      'Send'
    ]
  }
}

output eventhubs object = {
  activityLog: {
    eventHubNamespaceName: activityLogEnabled ? (activityLogSettings.useExistingEventHub ? existingActivityLogEventHubNamespace.name : eventHubNamespace.name) : ''
    eventHubName: activityLogEnabled ? (activityLogSettings.useExistingEventHub ? existingActivityLogEventHub.name : activityLogEventHub.name) : ''
    eventHubId: activityLogEnabled ? (activityLogSettings.useExistingEventHub ? existingActivityLogEventHub.id : activityLogEventHub.id) : ''
    eventHubNamespaceServiceBusEndpoint: activityLogEnabled ? (activityLogSettings.useExistingEventHub ? existingActivityLogEventHubNamespace.properties.serviceBusEndpoint : eventHubNamespace.properties.serviceBusEndpoint) : ''
    eventHubAuthorizationRuleId: activityLogEnabled ? (activityLogSettings.useExistingEventHub ? activityLogSettings.eventHubAuthorizationRuleId : authorizationRule.id) : ''
  }
  entraLog: {
    eventHubNamespaceName: entraLogEnabled ? (entraLogSettings.useExistingEventHub ? existingEntraLogEventHubNamespace.name : eventHubNamespace.name) : ''
    eventHubName: entraLogEnabled ? (entraLogSettings.useExistingEventHub ? existingEntraLogEventHub.name : activityLogEventHub.name) : ''
    eventHubId: entraLogEnabled ? (entraLogSettings.useExistingEventHub ? existingEntraLogEventHub.id : activityLogEventHub.id) : ''
    eventHubNamespaceServiceBusEndpoint: entraLogEnabled ? (entraLogSettings.useExistingEventHub ? existingEntraLogEventHubNamespace.properties.serviceBusEndpoint : eventHubNamespace.properties.serviceBusEndpoint) : ''
    eventHubAuthorizationRuleId: entraLogEnabled ? (entraLogSettings.useExistingEventHub ? entraLogSettings.eventHubAuthorizationRuleId : authorizationRule.id) : ''
  }
}
