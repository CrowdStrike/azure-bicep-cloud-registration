targetScope = 'subscription'

@description('Azure subscription Ids to configure Activity Log diagnostic settings.')
param subscriptionIds array

@description('Event Hub Authorization Rule Id.')
param eventHubAuthorizationRuleId string

@description('Event Hub Name.')
param eventHubName string

module activityDiagnosticSettings 'activityLog.bicep' = [
  for subscriptionId in subscriptionIds: {
    name: 'cs-ioa-activityLogDiagnosticSettings'
    scope: subscription(subscriptionId)
    params: {
      eventHubAuthorizationRuleId: eventHubAuthorizationRuleId
      eventHubName: eventHubName
    }
  }
]
