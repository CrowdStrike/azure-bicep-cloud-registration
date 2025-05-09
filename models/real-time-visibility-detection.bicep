@export()
@description('Settings for real time visibility and detection module')
type RealTimeVisibilityDetectionSettings = {
  @description('The main feature toggle of the real time visibility and detection module')
  enabled: bool

  @description('Detail settings of activity log')
  activityLogSettings: ActivityLogSettings

  @description('Detail settings of Entra ID log')
  entraIdLogSettings: EntraIdLogSettings
}

@export()
type ActivityLogSettings = {
    @description('Deploy Activity Log Diagnostic Settings to all active Azure subscriptions. Defaults to true')
    enabled: bool

    @description('Deploy Activity Log Diagnostic Settings policy. Defaults to true')
    deployRemediationPolicy: bool

    @description('Settings for using existing Eventhub')
    existingEventhub: ExistingEventHub
}

@export()
type EntraIdLogSettings = {
    @description('Deploy Entra Log Diagnostic Settings. Defaults to true')
    enabled: bool

    @description('Settings for using existing Eventhub')
    existingEventhub: ExistingEventHub
}

type ExistingEventHub = {
    @description('Use existing Eventhub to send/receive activity log')
    use: bool

    @description('Subscription ID hosting the Eventhub')
    subscriptionId: string

    @description('Resource group name hosting the Eventhub')
    resourceGroupName: string
    
    @description('Name of Eventhub namespace')
    namespaceName: string

    @description('Name of the Eventhub instance')
    name: string

    
}
