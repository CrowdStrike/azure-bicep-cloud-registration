targetScope = 'managementGroup'

/*
  This Bicep template deploys scanning infrastructure for all subscriptions within a
  single management group. It handles batching internally to overcome the 800 iteration limit.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

/* Parameters */
@description('Subscription entries with their scanning locations for this management group.')
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

@description('Role definition ID for subscription access role from management group scope.')
param subscriptionAccessRoleId string = ''

@description('Role definition ID for scanner role from management group scope.')
param scannerRoleId string = ''

@description('Role definition ID for resource group access role from management group scope.')
param resourceGroupAccessRoleId string = ''

@description('Maximum number of subscriptions per batch for scanning deployment. Default is 750 to stay safely under the 800 limit.')
@minValue(1)
@maxValue(800)
param batchSize int = 750

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env
var totalSubscriptions = length(subscriptionEntries)
var numberOfBatches = totalSubscriptions == 0 ? 0 : (totalSubscriptions + batchSize - 1) / batchSize

/* Deploy scanning infrastructure in batches */
module scanningSub 'scanningSubBatch.bicep' = [
  for i in range(0, numberOfBatches): {
    name: '${resourceNamePrefix}cs-scanning-batch-${i}${environment}${resourceNameSuffix}'
    scope: subscription(csInfraSubscriptionId)
    params: {
      subscriptionEntries: take(skip(subscriptionEntries, i * batchSize), batchSize)
      falconClientId: falconClientId
      falconClientSecret: falconClientSecret
      scanningPrincipalId: scanningPrincipalId
      scanningManagedIdentityPrincipalId: scanningManagedIdentityPrincipalId
      agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
      agentlessScanningHostSubscriptionId: agentlessScanningHostSubscriptionId
      inputEnableDspm: inputEnableDspm
      inputAgentlessScanningLocations: inputAgentlessScanningLocations
      inputAgentlessScanningLocationsPerSubscription: inputAgentlessScanningLocationsPerSubscription
      inputAgentlessScanningCustomVnetConfiguration: inputAgentlessScanningCustomVnetConfiguration
      subscriptionAccessRoleId: subscriptionAccessRoleId
      scannerRoleId: scannerRoleId
      resourceGroupAccessRoleId: resourceGroupAccessRoleId
      resourceGroupName: resourceGroupName
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      env: env
      tags: tags
    }
  }
]
