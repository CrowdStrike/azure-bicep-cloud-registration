import { filterLocationsPerSubscription } from '../../models/scanning.bicep'

targetScope = 'managementGroup'

/*
  This Bicep template deploys CrowdStrike Scanning roles and infrastructure to a batch of management groups
  to stay under the 4 MB deployment size limit for large numbers of management groups.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

@export()
@description('Maximum number of management groups per scanning batch, sized to stay within Azure Resource Manager deployment limits. Keep the @maxLength of managementGroupEntries equal to it.')
var maxScanningMgBatchSize = 25

/* Parameters */
@maxLength(25)
@description('Batched list of management group entries. Each entry contains managementGroupId and subscriptionEntries array. (max: 25)')
param managementGroupEntries array

@description('Client ID for the Falcon API.')
param falconClientId string

@description('Client secret for the Falcon API.')
@secure()
param falconClientSecret string

@description('Principal ID of the CrowdStrike application registered in Entra ID. This ID is used for role assignments and access control.')
param scanningPrincipalId string

@description('Principal ID of the scanning managed identity from the host subscription. Used in cross-account mode for non-host subscriptions.')
param scanningManagedIdentityPrincipalId string = ''

@description('Whether to create the resource group role definitions in the management group roles. Not needed in cross-account mode.')
param includeResourceGroupRoles bool = true

@description('Subscription ID where CrowdStrike infrastructure resources will be deployed. Used as the deployment scope for batch modules.')
param csInfraSubscriptionId string

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

@description('Controls whether to deploy NAT Gateway for scanning environment.')
param agentlessScanningDeployNatGateway bool = true

@description('Azure agentless scanning host subscription ID.')
param agentlessScanningHostSubscriptionId string = ''

@description('Controls whether to enable DSPM.')
param inputEnableDspm bool = false

@description('Controls whether to enable vulnerability scanning.')
param inputEnableVulnerabilityScanning bool = false

@description('Azure locations (regions) where DSPM will be deployed.')
param inputAgentlessScanningLocations array = []

@description('Azure locations (regions) where DSPM will be deployed as subscription ID to locations map. Covers only the subscriptions in this batch.')
param inputAgentlessScanningLocationsPerSubscription object = {}

@description('Per-region custom VNet configuration for agentless scanning.')
param inputAgentlessScanningCustomVnetConfiguration object = {}

@description('Maximum number of subscriptions per batch for scanning deployment.')
@minValue(1)
param batchSize int

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env

/* Define custom roles at each management group scope */
module scanningRoles 'scanningRolesForMg.bicep' = [
  for mgEntry in managementGroupEntries: {
    name: '${resourceNamePrefix}cs-scanning-roles-${uniqueString(mgEntry.managementGroupId)}${environment}${resourceNameSuffix}'
    scope: managementGroup(mgEntry.managementGroupId)
    params: {
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
      includeResourceGroupRoles: includeResourceGroupRoles
      inputEnableDspm: inputEnableDspm
      inputEnableVulnerabilityScanning: inputEnableVulnerabilityScanning
    }
  }
]

/* Deploy scanning infrastructure for the subscriptions of each management group */
module scanningPerMg 'scanningForMg.bicep' = [
  for (mgEntry, i) in managementGroupEntries: {
    name: '${resourceNamePrefix}cs-scanning-mg-${uniqueString(mgEntry.managementGroupId)}${environment}${resourceNameSuffix}'
    scope: managementGroup(mgEntry.managementGroupId)
    params: {
      subscriptionEntries: mgEntry.subscriptionEntries
      falconClientId: falconClientId
      falconClientSecret: falconClientSecret
      scanningPrincipalId: scanningPrincipalId
      scanningManagedIdentityPrincipalId: scanningManagedIdentityPrincipalId
      accessRoleId: scanningRoles[i].outputs.accessRoleId
      scannerRoleId: scanningRoles[i].outputs.scannerRoleId
      resourceGroupAccessRoleId: scanningRoles[i].outputs.resourceGroupAccessRoleId
      resourceGroupScannerRoleId: scanningRoles[i].outputs.resourceGroupScannerRoleId
      csInfraSubscriptionId: csInfraSubscriptionId
      agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
      agentlessScanningHostSubscriptionId: agentlessScanningHostSubscriptionId
      inputEnableDspm: inputEnableDspm
      inputEnableVulnerabilityScanning: inputEnableVulnerabilityScanning
      inputAgentlessScanningLocations: inputAgentlessScanningLocations
      inputAgentlessScanningLocationsPerSubscription: filterLocationsPerSubscription(
        inputAgentlessScanningLocationsPerSubscription,
        mgEntry.subscriptionEntries
      )
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
