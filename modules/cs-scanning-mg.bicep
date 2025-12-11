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

@description('Controls whether to deploy NAT Gateway for scanning environment.')
param agentlessScanningDeployNatGateway bool = true

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env

module scanningSub 'scanning-environment/scanningForSub.bicep' = [
  for sub in scanningEnvironmentLocationsPerSubscriptionMap: {
    name: '${resourceNamePrefix}cs-scanning-sub${environment}${resourceNameSuffix}'
    scope: subscription(sub.subscriptionId)
    params: {
      falconClientId: falconClientId
      falconClientSecret: falconClientSecret
      scanningPrincipalId: scanningPrincipalId
      scanningEnvironmentLocations: sub.locations
      agentlessScanningDeployNatGateway: agentlessScanningDeployNatGateway
      resourceGroupName: resourceGroupName
      resourceNamePrefix: resourceNamePrefix
      resourceNameSuffix: resourceNameSuffix
      env: env
      tags: tags
    }
  }
]
