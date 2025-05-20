import { ActivityLogSettings, EntraIdLogSettings } from '../../models/log-ingestion.bicep'

/*
  This Bicep template deploys Event Hub resources for collecting Azure Activity Logs and Entra ID logs
  for CrowdStrike.
  Copyright (c) 2025 CrowdStrike, Inc.
*/

@description('Configuration settings for Azure Activity Log collection, including whether to use existing Event Hubs')
param activityLogSettings ActivityLogSettings

@description('Configuration settings for Entra ID log collection, including whether to use existing Event Hubs')
param entraLogSettings EntraIdLogSettings

@description('List of CrowdStrike Falcon service IP addresses that need network access to the Event Hub. These IPs will be allowed through the Event Hub firewall.')
param falconIpAddresses array

@description('Principal ID of the CrowdStrike application registered in Entra ID. Used to grant data receiver permissions on Event Hubs.')
param azurePrincipalId string

@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string

@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string

@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string

@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Tags to be applied to all deployed Event Hub resources. Used for resource organization and governance.')
param tags object

var environment = length(env) > 0 ? '-${env}' : env
var defaultSettings = {
  eventHubNamespace: 'evhns-cslog${environment}-${location}'
  activityLogEventHubName: 'evh-cslogact${environment}-${location}'
  entraLogEventHubName: 'evh-cslogentid${environment}-${location}'
}
var shouldDeployActivityLog = activityLogSettings.enabled && !(activityLogSettings.?existingEventhub.use ?? false)
var shouldUseExistingEventHubForActivityLog = activityLogSettings.enabled && (activityLogSettings.?existingEventhub.use ?? false)
var shouldDeployEntraLog = entraLogSettings.enabled && !(entraLogSettings.?existingEventhub.use ?? false)
var shouldUseExistingEventHubForEntraLog = entraLogSettings.enabled && (entraLogSettings.?existingEventhub.use ?? false)
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
    ipRules: [
      for ip in falconIpAddresses: {
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

resource authorizationRule 'Microsoft.EventHub/namespaces/authorizationRules@2024-01-01' = if (shouldDeployEventHubNamespace) {
  name: '${resourceNamePrefix}rule-cslogevhns${environment}-${location}${resourceNameSuffix}'
  parent: eventHubNamespace
  properties: {
    rights: [
      'Send'
    ]
  }
}

resource existingActivityLogEventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' existing = if (shouldUseExistingEventHubForActivityLog) {
  name: activityLogSettings.?existingEventhub.?namespaceName ?? ''
  scope: resourceGroup(
    activityLogSettings.?existingEventhub.?subscriptionId ?? '',
    activityLogSettings.?existingEventhub.?resourceGroupName ?? ''
  )
}

resource existingEntraLogEventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' existing = if (shouldUseExistingEventHubForEntraLog) {
  name: entraLogSettings.?existingEventhub.?namespaceName ?? ''
  scope: resourceGroup(
    entraLogSettings.?existingEventhub.?subscriptionId ?? '',
    entraLogSettings.?existingEventhub.?resourceGroupName ?? ''
  )
}

resource existingActivityLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' existing = if (shouldUseExistingEventHubForActivityLog) {
  name: activityLogSettings.?existingEventhub.?name ?? ''
  parent: existingActivityLogEventHubNamespace
}

resource existingEntraLogEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' existing = if (shouldUseExistingEventHubForEntraLog) {
  name: entraLogSettings.?existingEventhub.?name ?? ''
  parent: existingEntraLogEventHubNamespace
}

// Azure Event Hubs Data Receiver
var eventHubsDataReceiverRole = resourceId(
  'Microsoft.Authorization/roleDefinitions',
  'a638d3c7-ab3a-418d-83e6-5f17a39d4fde'
)
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
  scope: az.resourceGroup(
    activityLogSettings.?existingEventhub.?subscriptionId ?? '',
    activityLogSettings.?existingEventhub.?resourceGroupName ?? ''
  )
  params: {
    eventHubId: existingActivityLogEventHub.id
    roleDefinitionId: eventHubsDataReceiverRole
    azurePrincipalId: azurePrincipalId
  }
}

module existingEntraLogEventHubRoleAssignment 'eventHubRoleAssignment.bicep' = if (shouldUseExistingEventHubForEntraLog) {
  name: guid(azurePrincipalId, eventHubsDataReceiverRole, activityLogEventHub.id)
  scope: az.resourceGroup(
    entraLogSettings.?existingEventhub.?subscriptionId ?? '',
    entraLogSettings.?existingEventhub.?resourceGroupName ?? ''
  )
  params: {
    eventHubId: existingEntraLogEventHub.id
    roleDefinitionId: eventHubsDataReceiverRole
    azurePrincipalId: azurePrincipalId
  }
}

output eventhubs object = {
  activityLog: {
    eventHubNamespaceName: shouldUseExistingEventHubForActivityLog
      ? existingActivityLogEventHubNamespace.name
      : (shouldDeployActivityLog ? eventHubNamespace.name : '')
    eventHubName: shouldUseExistingEventHubForActivityLog
      ? existingActivityLogEventHub.name
      : (shouldDeployActivityLog ? activityLogEventHub.name : '')
    eventHubId: shouldUseExistingEventHubForActivityLog
      ? existingActivityLogEventHub.id
      : (shouldDeployActivityLog ? activityLogEventHub.id : '')
    eventHubNamespaceServiceBusEndpoint: shouldUseExistingEventHubForActivityLog
      ? existingActivityLogEventHubNamespace.properties.serviceBusEndpoint
      : (shouldDeployActivityLog ? eventHubNamespace.properties.serviceBusEndpoint : '')
    eventHubAuthorizationRuleId: shouldDeployActivityLog ? authorizationRule.id : ''
    eventHubConsumerGrouopName: shouldDeployActivityLog
      ? '$Default'
      : activityLogSettings.?existingEventhub.?consumerGroupName ?? ''
  }
  entraLog: {
    eventHubNamespaceName: shouldUseExistingEventHubForEntraLog
      ? existingEntraLogEventHubNamespace.name
      : (shouldDeployEntraLog ? eventHubNamespace.name : '')
    eventHubName: shouldUseExistingEventHubForEntraLog
      ? existingEntraLogEventHub.name
      : (shouldDeployEntraLog ? activityLogEventHub.name : '')
    eventHubId: shouldUseExistingEventHubForEntraLog
      ? existingEntraLogEventHub.id
      : (shouldDeployEntraLog ? activityLogEventHub.id : '')
    eventHubNamespaceServiceBusEndpoint: shouldUseExistingEventHubForEntraLog
      ? existingEntraLogEventHubNamespace.properties.serviceBusEndpoint
      : (shouldDeployEntraLog ? eventHubNamespace.properties.serviceBusEndpoint : '')
    eventHubAuthorizationRuleId: shouldDeployEntraLog ? authorizationRule.id : ''
    eventHubConsumerGrouopName: shouldDeployEntraLog
      ? '$Default'
      : entraLogSettings.?existingEventhub.?consumerGroupName ?? ''
  }
}
