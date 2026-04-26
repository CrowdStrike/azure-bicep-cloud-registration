targetScope = 'managementGroup'

/*
  This Bicep template deploys infrastructure to enable CrowdStrike Scanning
  Copyright (c) 2026 CrowdStrike, Inc.
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

@description('Per-management-group active subscription IDs from deployment scope. Each entry contains managementGroupId and activeSubscriptionIds array.')
param subscriptionsByManagementGroup array = []

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
var verifiedCrossHostSubscriptionEntry = isCrossSubscriptionDeployment && length(crossHostSubscriptionEntry) == 0
  ? fail('"agentlessScanningHostSubscriptionId" must match a subscription in the scanning environment subscriptions map')
  : crossHostSubscriptionEntry

// Intersect MG subscription IDs with the scanning map to get per-MG scanning entries
var scanningEntriesByManagementGroup = map(subscriptionsByManagementGroup, mgEntry => {
  managementGroupId: mgEntry.managementGroupId
  subscriptionEntries: filter(
    scanningEnvironmentLocationsPerSubscriptionMap,
    entry => contains(mgEntry.activeSubscriptionIds, entry.subscriptionId)
  )
})

// Filter to MGs that have scanning subscriptions
var mgEntriesWithSubscriptions = filter(
  scanningEntriesByManagementGroup,
  entry => length(entry.subscriptionEntries) > 0
)

// MGs containing the host subscription vs all other MGs
var hostMgEntries = isCrossSubscriptionDeployment
  ? filter(
      mgEntriesWithSubscriptions,
      entry =>
        !empty(filter(entry.subscriptionEntries, sub => sub.subscriptionId == agentlessScanningHostSubscriptionId))
    )
  : []
var nonHostMgEntries = isCrossSubscriptionDeployment
  ? filter(
      mgEntriesWithSubscriptions,
      entry =>
        empty(filter(entry.subscriptionEntries, sub => sub.subscriptionId == agentlessScanningHostSubscriptionId))
    )
  : mgEntriesWithSubscriptions

// Standalone subs (in scanning map but NOT under any MG)
var allMgSubscriptionIds = flatten(map(
  scanningEntriesByManagementGroup,
  entry => map(entry.subscriptionEntries, sub => sub.subscriptionId)
))
var standaloneSubscriptionEntries = filter(
  scanningEnvironmentLocationsPerSubscriptionMap,
  entry => !contains(allMgSubscriptionIds, entry.subscriptionId)
)

// Cross-account: exclude host from standalone batch (host is deployed separately)
var nonHostStandaloneEntries = isCrossSubscriptionDeployment
  ? filter(standaloneSubscriptionEntries, sub => sub.subscriptionId != agentlessScanningHostSubscriptionId)
  : standaloneSubscriptionEntries

// Is host sub standalone (not under any MG)?
var isHostSubStandalone = isCrossSubscriptionDeployment && !empty(filter(
  standaloneSubscriptionEntries,
  sub => sub.subscriptionId == agentlessScanningHostSubscriptionId
))

// Is host sub under a management group?
var isHostSubUnderMg = isCrossSubscriptionDeployment && !isHostSubStandalone

// Whether host sub uses custom VNet subnets (for custom VNet role creation)
var hostSubUseCustomSubnets = isCrossSubscriptionDeployment && length(verifiedCrossHostSubscriptionEntry) > 0
  ? length(filter(
      verifiedCrossHostSubscriptionEntry[0].locations,
      location => !empty(location.customScannersSubnet) && !empty(location.customClonesSubnet)
    )) > 0
  : false

/* Define custom roles at host MG scope (cross-account, host sub under MG) */
module scanningHostMgRoles 'scanning-environment/scanningRolesForMg.bicep' = if (isHostSubUnderMg) {
  name: '${resourceNamePrefix}cs-scanning-host-mg-roles-${uniqueString(hostMgEntries[0].managementGroupId)}${environment}${resourceNameSuffix}'
  scope: managementGroup(isHostSubUnderMg ? hostMgEntries[0].managementGroupId : managementGroup().name)
  params: {
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
    includeResourceGroupAccessRole: true
    useCustomSubnets: hostSubUseCustomSubnets
  }
}

/* Define custom roles at each non-host management group scope */
module scanningRoles 'scanning-environment/scanningRolesForMg.bicep' = [
  for mgEntry in nonHostMgEntries: {
    name: '${resourceNamePrefix}cs-scanning-roles-${uniqueString(mgEntry.managementGroupId)}${environment}${resourceNameSuffix}'
    scope: managementGroup(mgEntry.managementGroupId)
    params: {
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
      includeResourceGroupAccessRole: !isCrossSubscriptionDeployment
    }
  }
]

/* Create per-subscription roles for host sub when it's not under any MG */
module scanningHostRoles 'scanning-environment/scanningRolesForSub.bicep' = if (isHostSubStandalone) {
  name: '${resourceNamePrefix}cs-scanning-host-roles${environment}${resourceNameSuffix}'
  scope: subscription(agentlessScanningHostSubscriptionId)
  params: {
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
    includeResourceGroupAccessRole: true
    useCustomSubnets: hostSubUseCustomSubnets
  }
}

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
    accessRoleId: isHostSubUnderMg ? scanningHostMgRoles!.outputs.accessRoleId : scanningHostRoles!.outputs.accessRoleId
    scannerRoleId: isHostSubUnderMg
      ? scanningHostMgRoles!.outputs.scannerRoleId
      : scanningHostRoles!.outputs.scannerRoleId
    resourceGroupAccessRoleId: isHostSubUnderMg
      ? scanningHostMgRoles!.outputs.resourceGroupAccessRoleId
      : scanningHostRoles!.outputs.resourceGroupAccessRoleId
    customVnetSubnetRoleId: isHostSubUnderMg
      ? scanningHostMgRoles!.outputs.customVnetSubnetRoleId
      : scanningHostRoles!.outputs.customVnetSubnetRoleId
    resourceGroupName: resourceGroupName
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    env: env
    tags: tags
  }
}

/* Deploy scanning infrastructure for non-host subs in the host MG (cross-account) */
module scanningHostPerMg 'scanning-environment/scanningForMg.bicep' = if (isHostSubUnderMg) {
  name: '${resourceNamePrefix}cs-scanning-host-mg-${uniqueString(hostMgEntries[0].managementGroupId)}${environment}${resourceNameSuffix}'
  scope: managementGroup(isHostSubUnderMg ? hostMgEntries[0].managementGroupId : managementGroup().name)
  params: {
    subscriptionEntries: isHostSubUnderMg
      ? filter(hostMgEntries[0].subscriptionEntries, sub => sub.subscriptionId != agentlessScanningHostSubscriptionId)
      : []
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    scanningPrincipalId: scanningPrincipalId
    scanningManagedIdentityPrincipalId: scanningHostSub!.outputs.scanningManagedIdentityPrincipalId
    accessRoleId: scanningHostMgRoles!.outputs.accessRoleId
    scannerRoleId: scanningHostMgRoles!.outputs.scannerRoleId
    resourceGroupAccessRoleId: scanningHostMgRoles!.outputs.resourceGroupAccessRoleId
    csInfraSubscriptionId: csInfraSubscriptionId
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
    batchSize: batchSize
  }
}

/* Deploy scanning infrastructure for non-host management groups */
module scanningPerMg 'scanning-environment/scanningForMg.bicep' = [
  for (mgEntry, i) in nonHostMgEntries: {
    name: '${resourceNamePrefix}cs-scanning-mg-${uniqueString(mgEntry.managementGroupId)}${environment}${resourceNameSuffix}'
    scope: managementGroup(mgEntry.managementGroupId)
    params: {
      subscriptionEntries: mgEntry.subscriptionEntries
      falconClientId: falconClientId
      falconClientSecret: falconClientSecret
      scanningPrincipalId: scanningPrincipalId
      scanningManagedIdentityPrincipalId: isCrossSubscriptionDeployment
        ? scanningHostSub!.outputs.scanningManagedIdentityPrincipalId
        : ''
      accessRoleId: scanningRoles[i].outputs.accessRoleId
      scannerRoleId: scanningRoles[i].outputs.scannerRoleId
      resourceGroupAccessRoleId: scanningRoles[i].outputs.resourceGroupAccessRoleId
      csInfraSubscriptionId: csInfraSubscriptionId
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
      batchSize: batchSize
    }
  }
]

/* Deploy scanning for standalone subscriptions (not under any management group) */
var totalStandaloneSubs = length(nonHostStandaloneEntries)
var standaloneNumberOfBatches = totalStandaloneSubs == 0 ? 0 : (totalStandaloneSubs + batchSize - 1) / batchSize

module scanningStandaloneBatch 'scanning-environment/scanningSubBatch.bicep' = [
  for i in range(0, standaloneNumberOfBatches): {
    name: '${resourceNamePrefix}cs-scanning-standalone-${i}${environment}${resourceNameSuffix}'
    scope: subscription(csInfraSubscriptionId)
    params: {
      subscriptionEntries: take(skip(nonHostStandaloneEntries, i * batchSize), batchSize)
      falconClientId: falconClientId
      falconClientSecret: falconClientSecret
      scanningPrincipalId: scanningPrincipalId
      scanningManagedIdentityPrincipalId: isCrossSubscriptionDeployment
        ? scanningHostSub!.outputs.scanningManagedIdentityPrincipalId
        : ''
      accessRoleId: ''
      scannerRoleId: ''
      resourceGroupAccessRoleId: ''
      includeResourceGroupAccessRole: !isCrossSubscriptionDeployment
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
