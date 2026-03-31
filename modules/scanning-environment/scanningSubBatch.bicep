targetScope = 'subscription'

/*
  This Bicep template handles batched scanning subscription deployment
  to overcome the 800 iteration limit for large numbers of subscriptions.
  Copyright (c) 2025 CrowdStrike, Inc.
*/

/* Parameters */
@maxLength(800)
@description('Batched list of subscription entries with their scanning locations. Each entry contains subscriptionId and locations array. (max: 800)')
param subscriptionEntries array

@description('Client ID for the Falcon API.')
param falconClientId string

@description('Client secret for the Falcon API.')
@secure()
param falconClientSecret string

@description('Principal ID of the CrowdStrike application registered in Entra ID. This ID is used for role assignments and access control.')
param scanningPrincipalId string

@description('Principal ID of the scanning managed identity from the host subscription. Used in cross-account mode for non-host subscriptions.')
param scanningManagedIdentityPrincipalId string = ''

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

@description('Per-region custom VNet configuration for agentless scanning.')
param inputAgentlessScanningCustomVnetConfiguration object = {}

@description('Batch number for unique naming')
param batchNumber int

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env

/* Deploy scanning infrastructure for subscriptions in this batch */
module scanningSub 'scanningForSub.bicep' = [
  for sub in subscriptionEntries: {
    name: '${resourceNamePrefix}cs-scan-${uniqueString(sub.subscriptionId)}${environment}${resourceNameSuffix}'
    scope: subscription(sub.subscriptionId)
    params: {
      falconClientId: falconClientId
      falconClientSecret: falconClientSecret
      scanningPrincipalId: scanningPrincipalId
      scanningEnvironmentLocations: sub.locations
      scanningManagedIdentityPrincipalId: scanningManagedIdentityPrincipalId
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

/* Outputs */
output subscriptionsProcessed int = length(subscriptionEntries)
output batchNumber int = batchNumber
