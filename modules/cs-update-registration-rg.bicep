@description('Base URL of the Falcon API.')
param falconApiFqdn string

@description('Client ID for the Falcon API.')
param falconClientId string

@description('Client secret for the Falcon API.')
@secure()
param falconClientSecret string

@description('Resource ID of the Event Hub instance to use for activity log')
param activityLogEventHubId string

@description('Consumer group of the Event Hub instance to use for activity log')
param activityLogEventHubConsumerGroupName string

@description('Resource ID of the Event Hub instance to use for Entra ID log')
param entraLogEventHubId string

@description('Consumer group of the Event Hub instance to use for Entra ID log')
param entraLogEventHubConsumerGroupName string

@maxLength(10)
@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string = ''

@maxLength(10)
@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string = ''

@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string

@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Tags to be applied to all deployed resources. Used for resource organization, governance, and cost tracking.')
param tags object

@description('Indicates whether this is the initial registration')
param isInitialRegistration bool

var environment = length(env) > 0 ? '-${env}' : env

module deploymentScope 'update-registration/updateRegistration.bicep' = {
  name: '${resourceNamePrefix}cs-update-reg-rg${environment}${resourceNameSuffix}'
  params: {
    falconApiFqdn: falconApiFqdn
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    isInitialRegistration: isInitialRegistration
    eventHubs: concat(
      activityLogEventHubId != ''
        ? [
            {
              purpose: 'activity_logs'
              event_hub_id: activityLogEventHubId
              consumer_group: activityLogEventHubConsumerGroupName
            }
          ]
        : [],
      entraLogEventHubId != ''
        ? [
            {
              purpose: 'entra_logs'
              event_hub_id: entraLogEventHubId
              consumer_group: entraLogEventHubConsumerGroupName
            }
          ]
        : []
    )
    env: env
    location: location
    tags: tags
  }
}
