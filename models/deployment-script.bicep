/*
  This Bicep template defines types and models for configuring an existing storage account for
  CrowdStrike deployment scripts.
  Copyright (c) 2025 CrowdStrike, Inc.
*/

@export()
@description('Configuration to use an existing, policy-compliant storage account for deployment scripts instead of the auto-provisioned one. Required when the target tenant enforces a policy disallowing public network access on newly created storage accounts.')
type DeploymentScriptSettings = {
  @description('Resource ID of the existing storage account deployment scripts will use. Must be in the same subscription as "csInfraSubscriptionId", since deployment scripts only support an existing storage account from their own subscription.')
  storageAccountId: string

  @description('Access key for the existing storage account.')
  @secure()
  storageAccountKey: string

  @description('Resource ID of a subnet (delegated to Microsoft.ContainerInstance/containerGroups) the deployment script container will run in. Required only if the storage account is not reachable from a public or service-endpoint-allowed network path.')
  subnetId: string?
}
