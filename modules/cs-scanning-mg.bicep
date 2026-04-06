targetScope = 'managementGroup'

/*
  This Bicep template deploys infrastructure to enable CrowdStrike Scanning
  Copyright (c) 2025 CrowdStrike, Inc.
*/

/* Parameters */
@description('Client ID for the Falcon API.')
param falconClientId string

@description('Client secret for the Falcon API.')
@secure()
param falconClientSecret string

@description('Principal ID of the CrowdStrike application registered in Entra ID. This ID is used for role assignments and access control.')
param scanningPrincipalId string

@description('Azure locations (regions) where scanning environments will be deployed as subscription ID to locations map.')
param scanningEnvironmentLocationsPerSubscriptionMap array = []

@description('Name of the resource group where CrowdStrike infrastructure resources will be deployed.')
param resourceGroupName string

@maxLength(10)
@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string = ''

@maxLength(10)
@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string = ''

@maxLength(4)
@description('Environment label (for example, prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Tags to be applied to all deployed resources. Used for resource organization and governance.')
param tags object

@description('Subscription ID where CrowdStrike infrastructure resources will be deployed. Used as the deployment scope for batch modules.')
param csInfraSubscriptionId string

@description('Controls whether to deploy NAT Gateway for scanning environment.')
param agentlessScanningDeployNatGateway bool = true

@description('Azure agentless scanning host subscription ID.')
param agentlessScanningHostSubscriptionId string = ''

@description('Controls whether to enable DSPM.')
param inputEnableDspm bool = false

@description('Azure locations (regions) where DSPM will be deployed.')
param inputAgentlessScanningLocations array = []

@description('Azure locations (regions) where DSPM will be deployed as subscription ID to locations map.')
param inputAgentlessScanningLocationsPerSubscription object = {}

@description('Per-region custom VNet configuration for agentless scanning.')
param inputAgentlessScanningCustomVnetConfiguration object = {}

@description('Maximum number of subscriptions per batch for scanning deployment. Default is 750 to stay safely under the 800 limit.')
@minValue(1)
@maxValue(800)
param batchSize int = 750

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env
var isCrossSubscriptionDeployment = !empty(agentlessScanningHostSubscriptionId)
var crossHostSubscriptionEntry = isCrossSubscriptionDeployment
  ? filter(
      scanningEnvironmentLocationsPerSubscriptionMap,
      sub => sub.subscriptionId == agentlessScanningHostSubscriptionId
    )
  : []
var nonCrossHostSubscriptionEntries = isCrossSubscriptionDeployment
  ? filter(
      scanningEnvironmentLocationsPerSubscriptionMap,
      sub => sub.subscriptionId != agentlessScanningHostSubscriptionId
    )
  : scanningEnvironmentLocationsPerSubscriptionMap
var verifiedCrossHostSubscriptionEntry = isCrossSubscriptionDeployment && length(crossHostSubscriptionEntry) == 0
  ? fail('"agentlessScanningHostSubscriptionId" must match a subscription in the scanning environment subscriptions map')
  : crossHostSubscriptionEntry

// Cross-account mode: deploy full infra to host subscription first
module scanningHostSub 'scanning-environment/scanningForSub.bicep' = if (isCrossSubscriptionDeployment && length(verifiedCrossHostSubscriptionEntry) > 0) {
  name: '${resourceNamePrefix}cs-scanning-host${environment}${resourceNameSuffix}'
  // Note: Azure will resolve this subscription regardless of the condition, so we need to provide a valid subscription ID
  scope: subscription(isCrossSubscriptionDeployment
    ? agentlessScanningHostSubscriptionId
    : scanningEnvironmentLocationsPerSubscriptionMap[0].subscriptionId)
  params: {
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    scanningPrincipalId: scanningPrincipalId
    scanningEnvironmentLocations: verifiedCrossHostSubscriptionEntry[0].locations
    agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
    agentlessScanningHostSubscriptionId: agentlessScanningHostSubscriptionId
    inputEnableDspm: inputEnableDspm
    inputAgentlessScanningLocations: inputAgentlessScanningLocations
    inputAgentlessScanningLocationsPerSubscription: inputAgentlessScanningLocationsPerSubscription
    inputAgentlessScanningCustomVnetConfiguration: inputAgentlessScanningCustomVnetConfiguration
    resourceGroupName: resourceGroupName
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    env: env
    tags: tags
  }
}

// Per-account mode: deploy full infra to every subscription
// Cross-account mode: deploy role assignments only to non-host subscriptions
// Deploy in batches to handle 800+ subscriptions
var totalSubscriptions = length(nonCrossHostSubscriptionEntries)
var numberOfBatches = totalSubscriptions == 0 ? 0 : (totalSubscriptions + batchSize - 1) / batchSize
module scanningSub 'scanning-environment/scanningSubBatch.bicep' = [
  for i in range(0, numberOfBatches): {
    name: '${resourceNamePrefix}cs-scanning-batch-${i}${environment}${resourceNameSuffix}'
    scope: subscription(csInfraSubscriptionId)
    params: {
      subscriptionEntries: take(skip(nonCrossHostSubscriptionEntries, i * batchSize), batchSize)
      falconClientId: falconClientId
      falconClientSecret: falconClientSecret
      scanningPrincipalId: scanningPrincipalId
      scanningManagedIdentityPrincipalId: isCrossSubscriptionDeployment
        ? scanningHostSub!.outputs.scanningManagedIdentityPrincipalId
        : ''
      agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
      agentlessScanningHostSubscriptionId: agentlessScanningHostSubscriptionId
      inputEnableDspm: inputEnableDspm
      inputAgentlessScanningLocations: inputAgentlessScanningLocations
      inputAgentlessScanningLocationsPerSubscription: inputAgentlessScanningLocationsPerSubscription
      inputAgentlessScanningCustomVnetConfiguration: inputAgentlessScanningCustomVnetConfiguration
      resourceGroupName: resourceGroupName
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      env: env
      tags: tags
    }
  }
]
