/*
  This Bicep template defines types and models for the CrowdStrike Real Time Visibility and Detection feature.
  Copyright (c) 2024 CrowdStrike, Inc.
*/

@export()
@description('Configuration settings for the real-time visibility and detection module, which enables monitoring of Azure activity and Entra ID logs')
type RealTimeVisibilityDetectionSettings = {
  @description('Master toggle for the real-time visibility and detection module. When set to false, all related resources will not be deployed.')
  enabled: bool

  @description('Configuration settings for Azure Activity Log collection and monitoring')
  activityLogSettings: ActivityLogSettings

  @description('Configuration settings for Entra ID log collection and monitoring')
  entraIdLogSettings: EntraIdLogSettings
}

@export()
type ActivityLogSettings = {
  @description('Controls whether Activity Log Diagnostic Settings are deployed to monitored Azure subscriptions. When false, activity logs will not be collected.')
  enabled: bool

  @description('Controls whether to deploy a policy that automatically configures Activity Log Diagnostic Settings on new subscriptions')
  deployRemediationPolicy: bool

  @description('Configuration for using an existing Event Hub instead of creating a new one for Activity Logs')
  existingEventhub: ExistingEventHub
}

@export()
type EntraIdLogSettings = {
  @description('Controls whether Entra ID Log Diagnostic Settings are deployed. When false, Entra ID logs will not be collected.')
  enabled: bool

  @description('Configuration for using an existing Event Hub instead of creating a new one for Entra ID Logs')
  existingEventhub: ExistingEventHub
}

type ExistingEventHub = {
  @description('When set to true, an existing Event Hub will be used instead of creating a new one')
  use: bool

  @description('Subscription ID where the existing Event Hub is located')
  subscriptionId: string

  @description('Resource group name where the existing Event Hub is located')
  resourceGroupName: string

  @description('Name of the existing Event Hub Namespace')
  namespaceName: string

  @description('Name of the existing Event Hub instance to use')
  name: string
}
