import {
  RealTimeVisibilityDetectionSettings
  DiagnosticLogSettings
} from '../models/real-time-visibility-detection.bicep'

targetScope = 'subscription'

/*
  This Bicep template deploys infrastructure to enable CrowdStrike 
  Indicator of Attack (IOA) assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('Targetscope of the IOM integration.')
@allowed([
  'ManagementGroup'
  'Subscription'
])
param targetScope string

@description('The location for the resources deployed in this solution.')
param location string = deployment().location

@description('The prefix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs-ioa'

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = ''

@description('Tags to be applied to all resources.')
param tags object = {
  'cstag-vendor': 'crowdstrike'
}

param featureSettings RealTimeVisibilityDetectionSettings = {
  enabled: true
  deployActivityLogDiagnosticSettings: true
  deployEntraLogDiagnosticSettings: true 
  deployActivityLogDiagnosticSettingsPolicy: true
  enableAppInsights: false
  resourceGroupName: 'cs-ioa-group' // DO NOT CHANGE - used for registration validation
}

@minLength(36)
@maxLength(36)
param defaultSubscriptionId string // DO NOT CHANGE - used for registration validation

param subscriptionIds array

module deploymentForSubs 'real-time-visibility-detection/realTimeVisibilityDetectionForSub.bicep' = {
  name: '${deploymentNamePrefix}-realTimeVisibilityDetectionForSubs-${deploymentNameSuffix}'
  params: {
    targetScope: targetScope
    defaultSubscriptionId: defaultSubscriptionId // DO NOT CHANGE
    subscriptionIds: subscriptionIds
    deploymentNamePrefix: deploymentNamePrefix
    deploymentNameSuffix: deploymentNameSuffix
    featureSettings: featureSettings
    location: location
    tags: tags
  }
}

