import {ActivityLogSettings, EntraIdLogSettings} from '../../models/real-time-visibility-detection.bicep'

@description('Settings for configuring Event Hub for activity log')
param activityLogSettings ActivityLogSettings

@description('Settings for configuring Event Hub for Entra ID log')
param entraLogSettings EntraIdLogSettings

@description('List of IP addresses of Crowdstrike Falcon service. Please refer to https://falcon.crowdstrike.com/documentation/page/re07d589/add-crowdstrike-ip-addresses-to-cloud-provider-allowlists-0 for the IP address list of your Falcon region.')
param falconIpAddresses array

@description('Principal Id of the Crowdstrike Application in Entra ID')
param azurePrincipalId string

@description('The prefix to be added to the resource name.')
param resourceNamePrefix string

@description('The suffix to be added to the resource name.')
param resourceNameSuffix string

@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string

@description('Custom label indicating the environment to be monitored, such as prod, stag or dev.')
param env string

@description('Tags to be applied to all resources.')
param tags object


var environment = length(env) > 0 ? '-${env}' : env
var defaultSettings = {
  eventHubNamespace: 'evhns-cslog${environment}-${location}'
  activityLogEventHubName: 'evh-cslogact${environment}-${location}'
  entraLogEventHubName: 'evh-cslogentid${environment}-${location}'
}
var shouldDeployActivityLog = activityLogSettings.enabled && !activityLogSettings.existingEventhub.use
var shouldUseExistingEventHubForActivityLog = activityLogSettings.enabled && activityLogSettings.existingEventhub.use
var shouldDeployEntraLog = entraLogSettings.enabled && !entraLogSettings.existingEventhub.use
var shouldUseExistingEventHubForEntraLog = entraLogSettings.enabled && entraLogSettings.existingEventhub.use
var shouldDeployEventHubNamespace = shouldDeployActivityLog || shouldDeployEntraLog

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = if (shouldDeployEventHubNamespace) {
  name: '${resourceNamePrefix}${defaultSettings.eventHubNamespace}${resourceNameSuffix}'
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

// Allow Crowdstrike Falcon to access the Eventhub
resource eventHubNamespaceNetworkRuleSet 'Microsoft.EventHub/namespaces/networkRuleSets@2024-01-01' = if (shouldDeployEventHubNamespace) {
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



resource activityLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = if (shouldDeployActivityLog) {
  name: '${resourceNamePrefix}${defaultSettings.activityLogEventHubName}${resourceNameSuffix}'
  parent: eventHubNamespace
  properties: {
    partitionCount: 16
    retentionDescription: {
      cleanupPolicy: 'Delete'
      retentionTimeInHours: 24
    }
  }
}

resource entraLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = if (shouldDeployEntraLog) {
  name: '${resourceNamePrefix}${defaultSettings.entraLogEventHubName}${resourceNameSuffix}'
  parent: eventHubNamespace
  properties: {
    partitionCount: 16
    retentionDescription: {
      cleanupPolicy: 'Delete'
      retentionTimeInHours: 24
    }
  }
}

resource authorizationRule 'Microsoft.EventHub/namespaces/authorizationRules@2024-01-01' = if(shouldDeployEventHubNamespace) {
  name: '${resourceNamePrefix}rule-cslogevhns${environment}-${location}${resourceNameSuffix}'
  parent: eventHubNamespace
  properties: {
    rights: [
      'Send'
    ]
  }
}

resource existingActivityLogEventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' existing = if (shouldUseExistingEventHubForActivityLog) {
  name: activityLogSettings.existingEventhub.namespaceName
  scope: resourceGroup(activityLogSettings.existingEventhub.subscriptionId, activityLogSettings.existingEventhub.resourceGroupName)
}

resource existingEntraLogEventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' existing = if (shouldUseExistingEventHubForEntraLog) {
  name: entraLogSettings.existingEventhub.namespaceName
  scope: resourceGroup(entraLogSettings.existingEventhub.subscriptionId, entraLogSettings.existingEventhub.resourceGroupName)
}

resource existingActivityLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' existing = if (shouldUseExistingEventHubForActivityLog) {
  name: activityLogSettings.existingEventhub.name
  parent: existingActivityLogEventHubNamespace
}

resource existingEntraLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' existing = if (shouldUseExistingEventHubForEntraLog) {
  name: entraLogSettings.existingEventhub.name
  parent: existingEntraLogEventHubNamespace
}

// Azure Event Hubs Data Receiver
var eventHubsDataReceiverRole = resourceId('Microsoft.Authorization/roleDefinitions', 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde')
module eventHubRoleAssignment 'eventHubRoleAssignment.bicep' = if (shouldDeployActivityLog || shouldDeployEntraLog) {
  name: guid(azurePrincipalId, eventHubsDataReceiverRole, activityLogEventHub.id)
  params: {
    eventHubId: activityLogEventHub.id
    roleDefinitionId: eventHubsDataReceiverRole
    azurePrincipalId: azurePrincipalId
  }
}

module existingActivityLogEventHubRoleAssignment 'eventHubRoleAssignment.bicep' = if (shouldUseExistingEventHubForActivityLog) {
  name: guid(azurePrincipalId, eventHubsDataReceiverRole, activityLogEventHub.id)
  scope: az.resourceGroup(activityLogSettings.existingEventhub.subscriptionId, activityLogSettings.existingEventhub.resourceGroupName)
  params: {
    eventHubId: existingActivityLogEventHub.id
    roleDefinitionId: eventHubsDataReceiverRole
    azurePrincipalId: azurePrincipalId
  }
}

module existingEntraLogEventHubRoleAssignment 'eventHubRoleAssignment.bicep' = if (shouldUseExistingEventHubForEntraLog) {
  name: guid(azurePrincipalId, eventHubsDataReceiverRole, activityLogEventHub.id)
  scope: az.resourceGroup(entraLogSettings.existingEventhub.subscriptionId, entraLogSettings.existingEventhub.resourceGroupName)
  params: {
    eventHubId: existingEntraLogEventHub.id
    roleDefinitionId: eventHubsDataReceiverRole
    azurePrincipalId: azurePrincipalId
  }
}

output eventhubs object = {
  activityLog: {
    eventHubNamespaceName: shouldUseExistingEventHubForActivityLog ? existingActivityLogEventHubNamespace.name : (shouldDeployActivityLog ? eventHubNamespace.name : '')
    eventHubName: shouldUseExistingEventHubForActivityLog ? existingActivityLogEventHub.name : (shouldDeployActivityLog ? activityLogEventHub.name : '')
    eventHubId: shouldUseExistingEventHubForActivityLog ? existingActivityLogEventHub.id : (shouldDeployActivityLog ? activityLogEventHub.id : '')
    eventHubNamespaceServiceBusEndpoint: shouldUseExistingEventHubForActivityLog ? existingActivityLogEventHubNamespace.properties.serviceBusEndpoint : (shouldDeployActivityLog ? eventHubNamespace.properties.serviceBusEndpoint : '')
    eventHubAuthorizationRuleId: shouldDeployActivityLog ? authorizationRule.id : ''
  }
  entraLog: {
    eventHubNamespaceName: shouldUseExistingEventHubForEntraLog ? existingEntraLogEventHubNamespace.name : (shouldDeployEntraLog ? eventHubNamespace.name : '')
    eventHubName: shouldUseExistingEventHubForEntraLog ? existingEntraLogEventHub.name : (shouldDeployEntraLog ? activityLogEventHub.name : '')
    eventHubId: shouldUseExistingEventHubForEntraLog ? existingEntraLogEventHub.id : (shouldDeployEntraLog ? activityLogEventHub.id : '')
    eventHubNamespaceServiceBusEndpoint: shouldUseExistingEventHubForEntraLog ? existingEntraLogEventHubNamespace.properties.serviceBusEndpoint : (shouldDeployEntraLog ? eventHubNamespace.properties.serviceBusEndpoint : '')
    eventHubAuthorizationRuleId: shouldDeployEntraLog ? authorizationRule.id : ''
  }
}
