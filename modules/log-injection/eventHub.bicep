import {DiagnosticLogSettings} from '../../models/real-time-visibility-detection.bicep'

param activityLogSettings DiagnosticLogSettings
param entraLogSettings DiagnosticLogSettings
param authorizationRuleName string = 'rule-cslievhns-${env}-${region}'
param falconIpAddresses array
param prefix string
param suffix string
param region string
param env string
param tags object

var defaultSettings = {
  eventHubNamespace: 'evhns-csli-${env}-${region}'
  activityLogEventHubName: 'evh-csliactivity-${env}-${region}'
  entraLogEventHubName: 'evh-cslientid-${env}-${region}'
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = if (!activityLogSettings.useExistingEventHub || !entraLogSettings.useExistingEventHub ) {
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
resource eventHubNamespaceNetworkRuleSet 'Microsoft.EventHub/namespaces/networkRuleSets@2024-01-01' = if (!activityLogSettings.useExistingEventHub || !entraLogSettings.useExistingEventHub ) {
  name: 'default'
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

resource existingActivityLogEventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' existing = if (activityLogSettings.useExistingEventHub) {
  name: activityLogSettings.eventHubNamespaceName
  scope: resourceGroup(activityLogSettings.eventHubSubscriptionId, activityLogSettings.eventHubResourceGroupName)
}

resource existingEntraLogEventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' existing = if (entraLogSettings.useExistingEventHub) {
  name: entraLogSettings.eventHubNamespaceName
  scope: resourceGroup(entraLogSettings.eventHubSubscriptionId, entraLogSettings.eventHubResourceGroupName)
}

resource activityLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = if (!activityLogSettings.useExistingEventHub) {
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

resource existingActivityLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' existing = if (activityLogSettings.useExistingEventHub) {
  name: activityLogSettings.eventHubName
  parent: existingActivityLogEventHubNamespace
}

resource entraLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = if (!entraLogSettings.useExistingEventHub) {
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

resource existingEntraLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' existing = if (entraLogSettings.useExistingEventHub) {
  name: entraLogSettings.eventHubName
  parent: existingEntraLogEventHubNamespace
}

resource authorizationRule 'Microsoft.EventHub/namespaces/authorizationRules@2024-01-01' = if (!activityLogSettings.useExistingEventHub || !entraLogSettings.useExistingEventHub ) {
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
