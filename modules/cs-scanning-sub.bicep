targetScope = 'subscription'

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

@description('Tags to be applied to all deployed resources. Used for resource organization, governance, and cost tracking.')
param tags object

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

@description('Optional existing custom scanners subnet ID to use instead of creating a new one.')
param customScannersSubnet string = ''

@description('Optional existing custom clones subnet ID to use instead of creating a new one.')
param customClonesSubnet string = ''


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
var useCustomSubnets = !empty(customClonesSubnet) && !empty(customScannersSubnet) && !empty(customVaultSubnet)

// Validate that all custom subnets are in the same VNet
var scannersVnetId = useCustomSubnets ? '${split(customScannersSubnet, '/')[0]}/${split(customScannersSubnet, '/')[1]}/${split(customScannersSubnet, '/')[2]}/${split(customScannersSubnet, '/')[3]}/${split(customScannersSubnet, '/')[4]}/${split(customScannersSubnet, '/')[5]}/${split(customScannersSubnet, '/')[6]}/${split(customScannersSubnet, '/')[7]}/${split(customScannersSubnet, '/')[8]}' : ''
var clonesVnetId = useCustomSubnets ? '${split(customClonesSubnet, '/')[0]}/${split(customClonesSubnet, '/')[1]}/${split(customClonesSubnet, '/')[2]}/${split(customClonesSubnet, '/')[3]}/${split(customClonesSubnet, '/')[4]}/${split(customClonesSubnet, '/')[5]}/${split(customClonesSubnet, '/')[6]}/${split(customClonesSubnet, '/')[7]}/${split(customClonesSubnet, '/')[8]}' : ''

var validatedCustomSubnets = useCustomSubnets && (scannersVnetId != clonesVnetId || clonesVnetId != vaultVnetId)
  ? fail('All custom subnets (customScannersSubnet, customClonesSubnet, customVaultSubnet) must be in the same VNet')
  : true

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
    resourceGroupName: resourceGroupName
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    env: env
    tags: tags
  }
}

// Per-account mode: deploy full infra to every subscription
// Cross-account mode: deploy role assignments only to non-host subscriptions
module scanningSub 'scanning-environment/scanningForSub.bicep' = [
  for sub in nonCrossHostSubscriptionEntries: {
    name: '${resourceNamePrefix}cs-scanning-sub${environment}${resourceNameSuffix}'
    scope: subscription(sub.subscriptionId)
    params: {
      falconClientId: falconClientId
      falconClientSecret: falconClientSecret
      scanningPrincipalId: scanningPrincipalId
      scanningEnvironmentLocations: sub.locations
      scanningManagedIdentityPrincipalId: isCrossSubscriptionDeployment
        ? scanningHostSub!.outputs.scanningManagedIdentityPrincipalId
        : ''
      agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
      agentlessScanningHostSubscriptionId: agentlessScanningHostSubscriptionId
      inputEnableDspm: inputEnableDspm
      inputAgentlessScanningLocations: inputAgentlessScanningLocations
      inputAgentlessScanningLocationsPerSubscription: inputAgentlessScanningLocationsPerSubscription
      customScannersSubnet: customScannersSubnet
      customClonesSubnet: customClonesSubnet
      resourceGroupName: resourceGroupName
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      env: env
      tags: tags
    }
  }
]
