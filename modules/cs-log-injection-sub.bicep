import { DiagnosticLogSettings } from '../models/real-time-visibility-detection.bicep'
import { FeatureSettings } from '../models/common.bicep'

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

@description('The Azure region for the resources deployed in this solution.')
param region string

param env string

@description('The prefix to be added to the deployment name.')
param prefix string

@description('The suffix to be added to the deployment name.')
param suffix string

@description('Tags to be applied to all resources.')
param tags object

param featureSettings FeatureSettings

param falconIpAddresses array

@minLength(36)
@maxLength(36)
param csInfraSubscriptionId string // DO NOT CHANGE - used for registration validation

param subscriptionIds array

module deploymentForSubs 'log-injection/logInjectionForSub.bicep' = {
  name: '${prefix}realTimeVisibilityDetectionForSubs${suffix}'
  params: {
    targetScope: targetScope
    csInfraSubscriptionId: csInfraSubscriptionId // DO NOT CHANGE
    subscriptionIds: subscriptionIds
    prefix: prefix
    suffix: suffix
    featureSettings: featureSettings
    falconIpAddresses: falconIpAddresses
    region: region
    env: env
    tags: tags
  }
}

