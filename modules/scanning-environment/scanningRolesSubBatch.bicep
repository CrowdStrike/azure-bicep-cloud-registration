targetScope = 'subscription'

/*
  This Bicep template creates the per-subscription CrowdStrike Scanning role definitions for a batch of subscriptions.
  Role definitions are deployed separately from the scanning infrastructure batch so that neither deployment exceeds 4 MB.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

/* Parameters */
// Same limit as maxScanningBatchSize in scanningSubBatch.bicep, which passes its own entries here
@maxLength(75)
@description('Batched list of subscription entries. Each entry contains subscriptionId and locations array. (max: 75)')
param subscriptionEntries array

@maxLength(10)
@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string = ''

@maxLength(10)
@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string = ''

@maxLength(4)
@description('Environment label (for example, prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Whether NAT Gateway is enabled. When false, public IP permissions are included for VM connectivity.')
param agentlessScanningDeployNatGateway bool = true

@description('Whether to create the resource group role definitions. Only needed for host subscriptions.')
param includeResourceGroupRoles bool = true

@description('Controls whether to enable DSPM.')
param inputEnableDspm bool = false

@description('Controls whether to enable vulnerability scanning.')
param inputEnableVulnerabilityScanning bool = false

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env

module subRoles 'scanningRolesForSub.bicep' = [
  for sub in subscriptionEntries: {
    name: '${resourceNamePrefix}cs-scanning-roles-${uniqueString(sub.subscriptionId)}${environment}${resourceNameSuffix}'
    scope: subscription(sub.subscriptionId)
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

/* Outputs */
@description('Role definition IDs per subscription, in the order of subscriptionEntries.')
output roles array = [
  for (sub, i) in subscriptionEntries: {
    accessRoleId: subRoles[i].outputs.accessRoleId
    scannerRoleId: subRoles[i].outputs.scannerRoleId
    resourceGroupAccessRoleId: subRoles[i].outputs.resourceGroupAccessRoleId
    resourceGroupScannerRoleId: subRoles[i].outputs.resourceGroupScannerRoleId
  }
]
