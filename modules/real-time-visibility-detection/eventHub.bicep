import {DiagnosticLogSettings} from '../../models/real-time-visibility-detection.bicep'

param defaultSubscriptionId string
param activityLogSettings DiagnosticLogSettings
param entraLogSettings DiagnosticLogSettings
param authorizationRuleName string = 'cs-eventhub-monitor-auth-rule'
param location string = resourceGroup().location
param tags object = {}

var defaultSettings = {
  eventHubNamespace: 'cs-horizon-ns-${defaultSubscriptionId}' // DO NOT CHANGE - used for registration validation
  activityLogEventHubName: 'cs-eventhub-monitor-activity-logs'
  entraLogEventHubName: 'cs-eventhub-monitor-aad-logs'
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = if (!activityLogSettings.useExistingEventHub || !entraLogSettings.useExistingEventHub ) {
  name: defaultSettings.eventHubNamespace
  location: location
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

resource existingActivityLogEventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' existing = if (activityLogSettings.useExistingEventHub) {
  name: activityLogSettings.eventHubNamespaceName
  scope: resourceGroup(activityLogSettings.eventHubSubscriptionId, activityLogSettings.eventHubResourceGroupName)
}

resource existingEntraLogEventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' existing = if (entraLogSettings.useExistingEventHub) {
  name: entraLogSettings.eventHubNamespaceName
  scope: resourceGroup(entraLogSettings.eventHubSubscriptionId, entraLogSettings.eventHubResourceGroupName)
}

// resource eventHubNamespaceNetworkRuleSet 'Microsoft.EventHub/namespaces/networkRuleSets@2024-01-01' = if (!activityLogSettings.useExistingEventHub || !entraLogSettings.useExistingEventHub ) {
//   name: 'default'
//   parent: eventHubNamespace
//   properties: {
//     defaultAction: 'Deny'
//     ipRules: []
//     publicNetworkAccess: 'Enabled'
//     trustedServiceAccessEnabled: true
//   }
// }

resource activityLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = if (!activityLogSettings.useExistingEventHub) {
  name: defaultSettings.activityLogEventHubName
  parent: eventHubNamespace
  properties: {
    partitionCount: 16
    retentionDescription: {
      cleanupPolicy: 'Delete'
      retentionTimeInHours: 24
    }
  }
}

resource existingActivityLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' existing = if (activityLogSettings.useExistingEventHub) {
  name: activityLogSettings.eventHubName
  parent: existingActivityLogEventHubNamespace
}

resource entraLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = if (!entraLogSettings.useExistingEventHub) {
  name: defaultSettings.entraLogEventHubName
  parent: eventHubNamespace
  properties: {
    partitionCount: 16
    retentionDescription: {
      cleanupPolicy: 'Delete'
      retentionTimeInHours: 24
    }
  }
}

resource existingEntraLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' existing = if (entraLogSettings.useExistingEventHub) {
  name: entraLogSettings.eventHubName
  parent: existingEntraLogEventHubNamespace
}

resource authorizationRule 'Microsoft.EventHub/namespaces/authorizationRules@2024-01-01' = if (!activityLogSettings.useExistingEventHub || !entraLogSettings.useExistingEventHub ) {
  name: authorizationRuleName
  parent: eventHubNamespace
  properties: {
    rights: [
      'Send'
    ]
  }
}

output eventhubs object = {
  activityLog: {
    eventHubNamespaceName: activityLogSettings.useExistingEventHub ? existingActivityLogEventHubNamespace.name : eventHubNamespace.name
    eventHubName: activityLogSettings.useExistingEventHub ? existingActivityLogEventHub.name : activityLogEventHub.name
    eventHubNamespaceServiceBusEndpoint: activityLogSettings.useExistingEventHub ? existingActivityLogEventHubNamespace.properties.serviceBusEndpoint : eventHubNamespace.properties.serviceBusEndpoint
    eventHubAuthorizationRuleId: activityLogSettings.useExistingEventHub ? activityLogSettings.eventHubAuthorizationRuleId : authorizationRule.id
  }
  entraLog: {
    eventHubNamespaceName: activityLogSettings.useExistingEventHub ? existingEntraLogEventHubNamespace.name : eventHubNamespace.name
    eventHubName: activityLogSettings.useExistingEventHub ? existingEntraLogEventHub.name : activityLogEventHub.name
    eventHubNamespaceServiceBusEndpoint: activityLogSettings.useExistingEventHub ? existingEntraLogEventHubNamespace.properties.serviceBusEndpoint : eventHubNamespace.properties.serviceBusEndpoint
    eventHubAuthorizationRuleId: entraLogSettings.useExistingEventHub ? entraLogSettings.eventHubAuthorizationRuleId : authorizationRule.id
  }
}
