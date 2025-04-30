import {DiagnosticLogSettings} from '../../models/real-time-visibility-detection.bicep'

param activityLogSettings DiagnosticLogSettings
param entraLogSettings DiagnosticLogSettings
param authorizationRuleName string = 'cs-li-evh-monitor-auth-rule'
param deploymentNamePrefix string = 'cs'
param deploymentNameSuffix string = ''
param region string = resourceGroup().location
param tags object = {}

var defaultSettings = {
  eventHubNamespace: 'cs-li-evhns-${region}' // DO NOT CHANGE - used for registration validation
  activityLogEventHubName: 'cs-li-evh-monitor-activity-logs'
  entraLogEventHubName: 'cs-li-evh-monitor-aad-logs'
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = if (!activityLogSettings.useExistingEventHub || !entraLogSettings.useExistingEventHub ) {
  name: '${deploymentNamePrefix}-${defaultSettings.eventHubNamespace}-${deploymentNameSuffix}'
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

resource existingActivityLogEventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' existing = if (activityLogSettings.useExistingEventHub) {
  name: activityLogSettings.eventHubNamespaceName
  scope: resourceGroup(activityLogSettings.eventHubSubscriptionId, activityLogSettings.eventHubResourceGroupName)
}

resource existingEntraLogEventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' existing = if (entraLogSettings.useExistingEventHub) {
  name: entraLogSettings.eventHubNamespaceName
  scope: resourceGroup(entraLogSettings.eventHubSubscriptionId, entraLogSettings.eventHubResourceGroupName)
}

resource activityLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = if (!activityLogSettings.useExistingEventHub) {
  name: '${deploymentNamePrefix}-${defaultSettings.activityLogEventHubName}-${deploymentNameSuffix}'
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
  name: '${deploymentNamePrefix}-${defaultSettings.entraLogEventHubName}-${deploymentNameSuffix}'
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
  name: '${deploymentNamePrefix}-${authorizationRuleName}-${deploymentNameSuffix}'
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
