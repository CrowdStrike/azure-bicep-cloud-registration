@export()
@description('Settings for real time visibility and detection module')
type RealTimeVisibilityDetectionSettings = {
  @description('The main feature toggle of the real time visibility and detection module')
  enabled: bool

  @description('Deploy Activity Log Diagnostic Settings to all active Azure subscriptions. Defaults to true')
  deployActivityLogDiagnosticSettings: bool

  @description('Deploy Activity Log Diagnostic Settings policy. Defaults to true')
  deployActivityLogDiagnosticSettingsPolicy: bool

  @description('Deploy Entra Log Diagnostic Settings. Defaults to true')
  deployEntraLogDiagnosticSettings: bool

  @description('Enable Application Insights for additional logging of Function Apps. Defaults to false')
  enableAppInsights: bool
}

@export()
type DiagnosticLogSettings = {
  useExistingEventHub: bool
  eventHubNamespaceName: string
  eventHubName: string
  eventHubResourceGroupName: string
  eventHubSubscriptionId: string
  eventHubAuthorizationRuleId: string
  diagnosticSettingsName: string
}
