![CrowdStrike Falcon](https://raw.githubusercontent.com/CrowdStrike/falconpy/main/docs/asset/cs-logo.png)

# Falcon Cloud Security Registration with Azure Bicep

The Azure Bicep templates in this repository allow for an easy and seamless registration of Azure environments into CrowdStrike Falcon Cloud Security for asset inventory and real-time visibility and detection.

## Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Required permissions](#required-permissions)
4. [Template Parameters](#template-parameters)
5. [Resource Names](#resource-names)
6. [Deployment](#deployment)
7. [Troubleshooting](#troubleshooting)
8. [Contributing](#contributing)
9. [Support](#support)
10. [License Information](#license-information)

## Overview

You can use the Bicep files in this repo to register either or both of these types of Azure entities to Falcon Cloud Security:
- Azure management groups and all subscriptions in those management groups 
- Individual Azure subscriptions 

The Bicep templates perform the following actions:

- Create a resource group named `rg-cs-prod` (with a custom prefix or suffix, if specified) in the specified subscription `csInfraSubscriptionId`. 
- Assign the `Reader` Azure RBAC permission to the created app registration with a scope of either the management groups or individual subscriptions, depending on which Bicep file is being used.
- If registering a management group, a user-assigned managed identity with `Reader` permissions on the specified management groups is created to list enabled subscriptions.
- Assign the **role-csreader-\<subscription ID\>/\<management group ID\>** custom role on the management group or subscription with the following actions:
  - Microsoft.Web/sites/Read
  - Microsoft.Web/sites/config/Read
  - Microsoft.Web/sites/config/list/Action
  - Microsoft.Web/sites/publish/action
- If the `enableRealTimeVisibility` parameter is set to true, the templates also:
   - Deploy an Azure Event Hubs namespace, two event hubs, and additional infrastructure to the subscription that has been designated as the default subscription, which is done via the `csInfraSubscriptionId` parameter. CrowdStrike uses this infrastructure to stream Entra ID sign-in and audit logs, as well as Azure activity logs, to Falcon Cloud Security.
   - Create a Microsoft Entra ID diagnostic setting that forwards sign-in and audit logs to the newly-created event hub.
   - Individual subscription deployments only:
      - Create an Azure activity log diagnostic setting in the subscription being registered with Falcon Cloud Security that forwards activity logs to the newly-created event hub.
   - If registering a management group:
      - Create an Azure activity log diagnostic setting in all active subscriptions that forwards activity logs to the newly-created event hub.
      - When `logIngestionSettings.activityLogSettings.deployRemediationPolicy` is set to `true`, create an Azure policy definition and management group assignment that will create Azure activity log diagnostic settings for new subscriptions to forward activity logs to the newly-created event hub.
- If one of `enableDspm`/`enableVulnerabilityScanning` parameters are set to true:
   - If `agentlessScanningLocationsPerSubscription` is specified, per subscription from the map, otherwise per subscription within specified registration scope:
      - Create a resource group with Key vault and Managed Identity in global resources location.
      - Create and assign a custom Scanning access role at subscription scope.
      - Create and assign a custom Scanning access role at resource group scope.
      - When `enableDspm` is set to true, create and assign a custom Scanner role at a subscription scope.
      - When `enableVulnerabilityScanning` is set to true, create and assign a custom Scanner role at a resource group scope.
      - Assign built-in "Reader" role at resource group scope to the Scanner Managed Identity.
      - Assign built-in "Key Vault Secrets User" role at created Key vault scope to the Scanner Managed Identity for key access.
   - Per location in `agentlessScanningLocations` or `agentlessScanningLocationsPerSubscription` in each deployed resource group:
      - Deploy regional scanning resources like Virtual Network, Key vault's Private Endpoint, and optionally NAT Gateway with Public IP when `agentlessScanningDeployNatGateway` is set to true (default).


> [!NOTE]
> The user-assigned managed identity created during management group deployment is only used to get a list of all active subscriptions in the specified management groups and can be safely removed after a successful registration. The underlying resources using the user-assigned managed identity are removed automatically.

## Prerequisites

1. Create a registration for your Azure tenant on Falcon Cloud Security and grant admin consent to Falcon Cloud Security App
   - [US-1](https://falcon.crowdstrike.com/cloud-security/registration-v2/azure)
   - [US-2](https://falcon.us-2.crowdstrike.com/cloud-security/registration-v2/azure)
   - [EU-1](https://falcon.eu-1.crowdstrike.com/cloud-security/registration-v2/azure)
2. Ensure you have a CrowdStrike API URL, client ID, and client secret for Falcon Cloud Security with `Cloud security Azure registration (Write)` scope. If you don't already have API credentials, you can set them up in the Falcon console. You must be a Falcon Administrator to access the API clients page:
   - [US-1](https://falcon.crowdstrike.com/api-clients-and-keys/)
   - [US-2](https://falcon.us-2.crowdstrike.com/api-clients-and-keys/)
   - [EU-1](https://falcon.eu-1.crowdstrike.com/api-clients-and-keys/clients)

3. Install the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/) on your local computer or use `Azure Cloud Shell` in the Azure portal.

4. If you're registering a management group and `enableRealTimeVisibility` is set to `true`, ensure the `Microsoft.Management` resource provider is registered in the `csInfraSubscriptionId` subscription. This allows the template to discover active subscriptions under the specified management groups. You can register it using either of these methods:

   **Using Azure CLI:**
   ```
   az provider register --namespace Microsoft.Management --subscription <csInfraSubscriptionId>
   ```

   **Using Azure Portal:**
   1. Sign in to the Azure Portal.
   2. Navigate to the subscription specified in `csInfraSubscriptionId`.
   3. In the left menu, select **Settings** > **Resource providers**.
   4. Search for `Microsoft.Management` in the filter box.
   5. Select `Microsoft.Management` and click **Register** at the top of the page.
   6. Wait for the status to change from "Registering" to "Registered".


## Required permissions

- **Owner** role for the Azure management groups and subscriptions to be integrated into Falcon Cloud Security

## Template parameters

You can use any of these methods to pass parameters:

- Generate a parameter file: [generate-params](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-cli#generate-params)
- Deploy the Bicep file using the parameters file: [Deploy bicep file with parameters file](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameter-files?tabs=Bicep#deploy-bicep-file-with-parameters-file)
- Pass the parameters as arguments: [Inline parameters](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-cli#inline-parameters)

| Parameter name                                                                | Required | Description                                                                                                                                                                                                                                                                                                                                            |
|-------------------------------------------------------------------------------|----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `csInfraSubscriptionId`                                                       | no       | Subscription ID where CrowdStrike infrastructure resources will be deployed. This subscription hosts shared resources like Event Hubs. Required when `enableRealTimeVisibility`, `enableDspm` or `enableVulnerabilityScanning` are set to `true`.                                                                                                      |
| `managementGroupIds`                                                          | no       | List of management groups to be integrated into Falcon Cloud Security. Only used to register management groups.                                                                                                                                                                                                                                        |
| `subscriptionIds`                                                             | no       | List of individual subscriptions to be integrated into Falcon Cloud Security.                                                                                                                                                                                                                                                                          |
| `location`                                                                    | no       | Azure location (region) where global resources will be deployed. Default is the deployment location.                                                                                                                                                                                                                                                   |
| `resourceNamePrefix`                                                          | no       | Optional prefix added to all resource names for organization and identification purposes.                                                                                                                                                                                                                                                              |
| `resourceNameSuffix`                                                          | no       | Optional suffix added to all resource names for organization and identification purposes.                                                                                                                                                                                                                                                              |
| `falconIpAddresses`                                                           | no       | Falcon public IP addresses. Only used when `logIngestionSettings.enabled` is set to `true`. These will be configured to public network access list of EventHubs. For the list of IP addresses for your Falcon region, refer to https://falcon.crowdstrike.com/documentation/page/re07d589/add-crowdstrike-ip-addresses-to-cloud-provider-allowlists-0. |
| `falconApiFqdn`                                                               | no       | Falcon API FQDN for your CrowdStrike environment (`api.crowdstrike.com`, `api.us-2.crowdstrike.com`, or `api.eu-1.crowdstrike.com`). Required when `enableRealTimeVisibility` is set to `true`.                                                                                                                                                        |
| `falconClientId`                                                              | no       | Falcon API Client ID with CSPM Registration Read and Write scopes. Required when `enableRealTimeVisibility`, `enableDspm` or `enableVulnerabilityScanning` are set to `true`.                                                                                                                                                                          |
| `falconClientSecret`                                                          | no       | Falcon API Client Secret for the provided Client ID. Required when `enableRealTimeVisibility`, `enableDspm` or `enableVulnerabilityScanning` are set to `true`.                                                                                                                                                                                        |
| `azurePrincipalId`                                                            | yes      | Principal ID of Falcon Cloud Security App in Entra ID.                                                                                                                                                                                                                                                                                                 |
| `env`                                                                         | no       | Environment label (For example, prod, stag, or dev) used for resource naming and tagging. Default is `prod`.                                                                                                                                                                                                                                           |
| `tags`                                                                        | no       | Tags to be applied to all deployed resources. Used for resource organization and governance.                                                                                                                                                                                                                                                           |
| `isInitialRegistration`                                                       | no       | Indicates whether this is the initial registration. Default is `true`.                                                                                                                                                                                                                                                                                 |
| `enableRealTimeVisibility`                                                    | no       | Main toggle for the log ingestion module. When set to true, all related resources will be deployed. Default is `false`.                                                                                                                                                                                                                                |
| `logIngestionSettings.activityLogSettings.enabled`                            | no       | Controls whether activity log diagnostic settings are deployed to monitored Azure subscriptions. Default is `true`.                                                                                                                                                                                                                                    |
| `logIngestionSettings.activityLogSettings.deployRemediationPolicy`            | no       | Controls whether to deploy a policy that automatically configures activity log diagnostic settings on new subscriptions. Default is `true`. Not available when `logIngestionSettings.activityLogSettings.existingEventhub.use` is set to `true`                                                                                                        |
| `logIngestionSettings.entraIdLogSettings.enabled`                             | no       | Controls whether Entra ID log diagnostic settings are deployed. When false, Entra ID logs are not collected. Default is `true`.                                                                                                                                                                                                                        |
| `logIngestionSettings.activityLogSettings.existingEventhub`                   | no       | Collection of settings used to configure an existing event hub instead of creating a new one for activity logs.                                                                                                                                                                                                                                        |
| `logIngestionSettings.activityLogSettings.existingEventhub.use`               | no       | When set to true, an existing event hub will be used instead of creating a new one. Default is `false`.                                                                                                                                                                                                                                                |
| `logIngestionSettings.activityLogSettings.existingEventhub.subscriptionId`    | no       | Subscription ID where the existing event hub is located.                                                                                                                                                                                                                                                                                               |
| `logIngestionSettings.activityLogSettings.existingEventhub.resourceGroupName` | no       | Resource group name where the existing event hub is located.                                                                                                                                                                                                                                                                                           |
| `logIngestionSettings.activityLogSettings.existingEventhub.namespaceName`     | no       | Name of the existing event hub namespace.                                                                                                                                                                                                                                                                                                              |
| `logIngestionSettings.activityLogSettings.existingEventhub.name`              | no       | Name of the existing event hub instance to use.                                                                                                                                                                                                                                                                                                        |
| `logIngestionSettings.activityLogSettings.existingEventhub.consumerGroupName` | no       | Consumer group name in the existing event hub instance to use.                                                                                                                                                                                                                                                                                         |
| `logIngestionSettings.entraIdLogSettings.existingEventhub`                    | no       | Configuration for using an existing event hub instead of creating a new one for Entra ID Logs.                                                                                                                                                                                                                                                         |
| `logIngestionSettings.entraIdLogSettings.existingEventhub.use`                | no       | When set to true, an existing event hub will be used instead of creating a new one. Default is `false`.                                                                                                                                                                                                                                                |
| `logIngestionSettings.entraIdLogSettings.existingEventhub.subscriptionId`     | no       | Subscription ID where the existing event hub is located.                                                                                                                                                                                                                                                                                               |
| `logIngestionSettings.entraIdLogSettings.existingEventhub.resourceGroupName`  | no       | Resource group name where the existing event hub is located.                                                                                                                                                                                                                                                                                           |
| `logIngestionSettings.entraIdLogSettings.existingEventhub.namespaceName`      | no       | Name of the existing Azure Event Hubs namespace.                                                                                                                                                                                                                                                                                                       |
| `logIngestionSettings.entraIdLogSettings.existingEventhub.name`               | no       | Name of the existing event hub instance to use.                                                                                                                                                                                                                                                                                                        |
| `logIngestionSettings.entraIdLogSettings.existingEventhub.consumerGroupName`  | no       | Consumer group name in the existing event hub instance to use.                                                                                                                                                                                                                                                                                         |
| `enableDspm`                                                                  | no       | Main toggle for Data Security Posture Management (DSPM).                                                                                                                                                                                                                                                                                               |
| `enableVulnerabilityScanning`                                                 | no       | Main toggle for agentless vulnerability scanning.                                                                                                                                                                                                                                                                                                      |
| `agentlessScanningLocations`                                                  | no       | List of locations (regions) to deploy agentless scanning environment (DSPM/Vulnerability scanning).                                                                                                                                                                                                                                                    |
| `agentlessScanningLocationsPerSubscription`                                   | no       | A map of subscriptions to list of locations where agentless scanning environment will be deployed (DSPM/Vulnerability scanning).                                                                                                                                                                                                                       |
| `agentlessScanningDeployNatGateway`                                           | no       | Indicates Agentless Scanning environment will be deployed with NAT Gateway. Default is `true`.                                                                                                                                                                                                                                                         |
| `agentlessScanningHostSubscriptionId`                                         | no       | Azure agentless scanning host subscription ID. When set, cross-subscription mode is enabled and scanning infrastructure is deployed only to this subscription.                                                                                                                                                                                         |
| `deploymentScriptSettings.storageAccountId`                                  | no       | Resource ID of an existing storage account for deployment scripts to use instead of the auto-provisioned one. Required if the target tenant's Azure Policy disallows public network access on auto-created storage accounts. See [Storage account requirements](#storage-account-requirements-for-deploymentscriptsettings) for constraints this storage account must meet. When `deploymentScriptSettings` is set, the template automatically grants the `Storage File Data Privileged Contributor` role on this storage account to the script-runner managed identity - Azure requires this role for a deployment script to use an existing storage account, in addition to (or, when `deploymentScriptSettings.subnetId` is set, instead of) the storage account key. The deploying principal needs permission to create role assignments on the storage account (see [Required permissions](#required-permissions)). |
| `deploymentScriptSettings.storageAccountKey`                                 | no       | Access key for the existing storage account referenced by `deploymentScriptSettings.storageAccountId`. Required unless `deploymentScriptSettings.subnetId` is also set - when the deployment script runs inside a virtual network, Azure Container Instances can mount the storage account using the script-runner identity's `Storage File Data Privileged Contributor` role (granted automatically) instead of a key.                                                                                                                                                                           |
| `deploymentScriptSettings.subnetId`                                          | no       | Resource ID of a subnet, delegated to `Microsoft.ContainerInstance/containerGroups`, that the deployment script container will run in. Required only if the storage account referenced by `deploymentScriptSettings.storageAccountId` is not reachable from a public or service-endpoint-allowed network path. See [Storage account requirements](#storage-account-requirements-for-deploymentscriptsettings) for subnet subscription constraints. |

## Bicep parameter file example
```bicep
using './cs-deployment-management-group.bicep'

// Required: Client ID for the Falcon API.
param falconClientId = '<Falcon API Client ID>'
// Required: Client Secret for the Falcon API. Input the value of the secret.
param falconClientSecret = readEnvironmentVariable('FALCON_CLIENT_SECRET', '')

// Required: Falcon API FQDN for your CrowdStrike environment
param falconApiFqdn = '<Falcon API FQDN>'
// Required: Principal Id of Falcon Cloud Security App in Entra ID.
param azurePrincipalId = '<Service principal ID of the Falcon Cloud Security App in Entra ID>'
// Azure resources to monitor - You can use subscriptions, management groups, or both.
// If both are empty list, the entire tenant will be monitored
param managementGroupIds = []
param subscriptionIds = []
// Required: Azure subscription that will host CrowdStrike infrastructure
param csInfraSubscriptionId = '<subscription ID>'
// Optional: CrowdStrike IP addresses for network security
param falconIpAddresses = ['10.1.1.1', '10.1.1.2']
param isInitialRegistration = true
param enableRealTimeVisibility = true
// Optional: Configure log ingestion settings
param logIngestionSettings = {
  activityLogSettings: {
    enabled: true
    // deployRemediationPolicy is not available if using existing Event Hub settings
    deployRemediationPolicy: true
    existingEventhub: {
      use: true
      subscriptionId: '<subscription ID of the Event Hub>'
      resourceGroupName: '<resource group name of the Event Hub>'
      namespaceName: '<Event Hub namespace>'
      name: '<Event Hub instance name>'
      consumerGroupName: '<consumer group name>'
    }
  }
  entraIdLogSettings: {
    enabled: true
    existingEventhub: {
      use: true
      subscriptionId: '<subscription ID of the Event Hub>'
      resourceGroupName: '<resource group name of the Event Hub>'
      namespaceName: '<Event Hub namespace>'
      name: '<Event Hub instance name>'
      consumerGroupName: '<consumer group name>'
    }
  }
}
// Optional: Resource naming customization
param resourceNamePrefix = 'pfx-'
param resourceNameSuffix = '-sux'
param env = 'prod'

// Optional
param tags = {
  key: 'value'
}

// Optional: Resource region
param location = 'westeurope'

// Optional: Use an existing, policy-compliant storage account for deployment scripts
// instead of the auto-provisioned one. Must be in the same subscription as csInfraSubscriptionId.
// See "Template parameters" and "Troubleshooting" for details, including a platform
// limitation around Shared Key access.
// param deploymentScriptSettings = {
//   storageAccountId: '<resource ID of an existing storage account in the csInfraSubscriptionId subscription>'
//   subnetId: '<subnet resource ID in the csInfraSubscriptionId subscription, only if the storage account is reachable only via private endpoint>'
//   // storageAccountKey is required unless subnetId (above) is set:
//   storageAccountKey: readEnvironmentVariable('DEPLOYMENT_SCRIPT_STORAGE_ACCOUNT_KEY', '')
// }
```

## Deployment

### Preparation

1. Download this repo to your local computer.
2. Open a new Terminal window and change directory to point at the downloaded repo.
3. Run `az login` to log into Azure via the Azure CLI. Be sure to log into a subscription that is in the tenant you want to register with Falcon Cloud Security.
4. Run the appropriate deployment command provided below.

### Deployment command for registering management groups and/or individual subscriptions

```sh
az stack mg create --name '<deployment stack name you want to use>' --location westus \
  --management-group-id '<management group id that the deployment stack to be created at>' \
  --template-file cs-deployment-management-group.bicep \
  --parameters '<file path of the Bicep parameter file storing all the input parameters>' \
  --action-on-unmanage deleteAll \
  --deny-settings-mode None \
  --only-show-errors
```

> [!NOTE]
> The `cs-deployment-management-group.bicep` template can be used to register a list of management groups (and all subscriptions in those management groups) and/or a list of individual subscriptions to CrowdStrike Falcon Cloud Security.

To track progress of the deployment or if you encounter issues and want to see detailed error messages:
   - Open the Azure Portal.
   - Go to **Management Groups** > **[management group of the deployment stack]**.
   - In the left menu, select **Governance** > **Deployment stacks**.
   - You will find the name you specified in the above command.


#### Remediate existing subscriptions using Azure Policy

> [!NOTE]
> This section is only applicable when `logIngestionSettings.activityLogSettings.deployRemediationPolicy` is set to `true`.

If the default deployment of Azure activity log diagnostic settings to all active subscriptions has been disabled, you can use a remediation task as part of Azure Policy to deploy Azure activity log diagnostic settings to existing subscriptions in a tenant to enable `Real Time Visibility and Detection (RTV&D)`.

> [!NOTE]
> After an Azure Policy assignment has been created, it takes time for Azure Policy to evaluate the compliance state of existing subscriptions. There is no predefined expectation of when the evaluation cycle completes. For more information, see [Azure Policy Evaluation Triggers](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/get-compliance-data#evaluation-triggers).

To start a manual remediation task:

1. In the Azure portal, navigate to **Management Groups** and select the tenant root group.
2. Go to **Governance** > **Policy** and select **Authoring** > **Assignments**.
3. Click the **CrowdStrike Activity Log Collection** assignment and then remediate the assignment by [creating a remediation task from a non-compliant policy assignment](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources?tabs=azure-portal#option-2-create-a-remediation-task-from-a-non-compliant-policy-assignment).


### Deployment command for registering individual subscriptions

```sh
az stack sk create --name '<deployment stack name you want to use>' --location westus \
  --template-file cs-deployment-subscription.bicep \
  --parameters '<file path of the Bicep parameter file storing all the input parameters>' \
  --action-on-unmanage deleteAll \
  --deny-settings-mode None \
  --only-show-errors
```

To track progress of the deployment or if you encounter issues and want to see detailed error messages:
   - Open the Azure Portal.
   - Go to **Subscriptions** and select the Subscription where you ran the deployment command.
   - In the left menu, select **Settings** > **Deployment stacks**.
   - You will find the name you specified in the above command.

### Deployment command for registering the whole tenant

To deploy Falcon Cloud Security integration for the entire tenant, you can use the management group deployment template with empty lists for both `managementGroupIds` and `subscriptionIds` parameters:

```sh
az stack mg create --name '<deployment stack name you want to use>' --location westus \
  --management-group-id '<tenant root management group id>' \
  --template-file cs-deployment-management-group.bicep \
  --parameters '<file path of the Bicep parameter file storing all the input parameters>' \
  --action-on-unmanage deleteAll \
  --deny-settings-mode None \
  --only-show-errors
```

In your parameters file, ensure both `managementGroupIds` and `subscriptionIds` are set to empty arrays:

```bicep
param managementGroupIds = []
param subscriptionIds = []
```

This configuration deploys the Falcon Cloud Security integration at the tenant root level, effectively covering all management groups and subscriptions in your Azure tenant.

To track progress of the deployment:
   - Open the Azure Portal.
   - Go to **Management Groups** > **[tenant root management group]**.
   - In the left menu, select **Governance** > **Deployment stacks**.
   - You will find the name you specified in the above command.

## Troubleshooting

### SSL certificate verification failure
Some customers may encounter an error message when trying to run the deployment command, similar to: `Error while attempting to retrieve the latest Bicep version: HTTPSConnectionPool(host='aka.ms', port=443): Max retries exceeded with url: /BicepLatestRelease (Caused by SSLError(SSLCertVerificationError(1, '[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:1000)')))`

This is usually caused by the presence of a web proxy on your network using self-signed certificates. The Azure CLI has a dependency on Python and Python is not using the correct certificates to make requests. The easiest solution is to download the Bicep tools independently of the Azure CLI and then tell the Azure CLI to use that version of Bicep tools when needed. Here's how:
1. Follow [Microsoft's instructions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#install-manually) on how to manually install the Bicep tools on your local computer.
2. Open a new terminal window on your computer and run the following command, which tells Azure CLI to use the manually downloaded version of Bicep tools instead of trying to install the tools as part of Azure CLI: `az config set bicep.use_binary_from_path=True`
3. Follow the deployment instructions again. This time, it should work without issue.

### Real-time visibility and detection appears inactive for discovered subscriptions after registering an Azure management group

After registering a management group and manually remediating the `CrowdStrike Activity Log Collection` policy assignment, real-time visibility and detection can remain inactive for some discovered subscriptions. This can happen when the diagnostic settings are not configured in the registered subscriptions.

The evaluation of the assigned Azure policy responsible for the diagnostic settings creation can take some time to properly evaluate which resources need to be remediated. For details, see [Evaluation Triggers](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/get-compliance-data#evaluation-triggers).

Make sure that all the existing subscriptions are properly listed under [resources to remediate](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources?tabs=azure-portal#step-2-specify-remediation-task-details) when creating the remediation tasks.

### Deleting the deployment stack fails if Microsoft Entra ID Log is enabled in log ingestion module

When Microsoft Entra ID Log is enabled and not using an existing Event Hubs instance in the Log Ingestion module, the deletion of the deployment stack may fail with the following error:

```
(DeploymentStackDeleteResourcesFailed) One or more resources could not be deleted. Correlation id: '...'.
Code: DeploymentStackDeleteResourcesFailed
Message: One or more resources could not be deleted. Correlation id: '...'.
Exception Details: (DeploymentStackDeleteResourcesFailed) An error occurred while deleting resources. 
These resources are still present in the stack but can be deleted manually. 
Please see the FailedResources property for specific error information. 
Deletion failures that are known limitations are documented here: https://aka.ms/DeploymentStacksKnownLimitations
```

This occurs because the Entra ID diagnostic settings resource has dependencies that prevent automatic deletion through the deployment stack.

To delete the deployment stack successfully, follow these steps:

1. Attempt to delete the deployment stack with the following command. The deletion will fail with the above error:
   ```
   az stack sub delete --name <deployment-stack-name> --action-on-unmanage deleteAll
   ```
   or for management group deployments:
   ```
   az stack mg delete --name <deployment-stack-name> --management-group-id <management-group-id> --action-on-unmanage deleteAll
   ```

2. In the Azure portal, navigate to the deployment stack:
   - For subscription deployments: Go to **Subscriptions** > **[your subscription]** > **Settings** > **Deployment stacks**
   - For management group deployments: Go to **Management Groups** > **[your management group]** > **Governance** > **Deployment stacks**

3. Select the deployment stack that failed to delete.

4. In the deployment stack details, find the list of failed resources and click the name of the Entra ID log diagnostic settings resource.

5. Click **Delete** to manually delete this resource.

6. After the diagnostic settings resource is successfully deleted, detach the deployment stack:
   ```
   az stack sub delete --name <deployment-stack-name> --action-on-unmanage detachAll
   ```
   or for management group deployments:
   ```
   az stack mg delete --name <deployment-stack-name> --management-group-id <management-group-id> --action-on-unmanage detachAll
   ```

### Deployment fails because the auto-created deployment script storage account violates policy

If your Azure tenant enforces a policy such as "Storage accounts should disable public network access," deployment can fail with a `DeploymentScriptOperationFailed` error, or a policy-disallowed error, referencing an auto-generated storage account (for example, a name ending in `zscripts`).

This happens because `Microsoft.Resources/deploymentScripts` auto-provisions a storage account with public network access enabled whenever no storage account is explicitly specified. This auto-provisioned account violates policies that require public network access to be disabled.

To resolve this, set `deploymentScriptSettings` to point at an existing, policy-compliant storage account (and `deploymentScriptSettings.subnetId` if the account is only reachable via a private endpoint) instead of relying on auto-provisioning. See the `deploymentScriptSettings.*` rows in the [Template parameters](#template-parameters) table.

> [!NOTE]
> **`allowSharedKeyAccess` must be `true` on the storage account, regardless of whether `deploymentScriptSettings.subnetId` is set or a key is supplied.**
>
> This is a known Microsoft platform limitation, not specific to this template - tracked at [Azure/bicep-types-az#2199](https://github.com/Azure/bicep-types-az/issues/2199) and [Azure/bicep#16604](https://github.com/Azure/bicep/issues/16604). Confirmed by testing: with `allowSharedKeyAccess: false`, deployment fails with `DeploymentScriptACIProvisioningTimeout` even when using `deploymentScriptSettings.subnetId` with the RBAC role granted automatically below and no key value supplied - the underlying Azure Container Instance never starts provisioning.
>
> If your tenant enforces a policy requiring `allowSharedKeyAccess` to be disabled, there's currently no supported way to run deployment scripts against that storage account; request a scoped policy exemption instead.
>
> See [Storage account requirements](#storage-account-requirements-for-deploymentscriptsettings) below for the full set of requirements.

### Storage account requirements for `deploymentScriptSettings`

An existing storage account supplied via `deploymentScriptSettings.storageAccountId` must meet all of the following requirements:

- Must be in the same subscription as `csInfraSubscriptionId` - `Microsoft.Resources/deploymentScripts` only accepts an existing storage account from its own subscription.
- `allowSharedKeyAccess` must be `true`, regardless of whether `deploymentScriptSettings.subnetId` is set or a key is supplied - see the [note above](#deployment-fails-because-the-auto-created-deployment-script-storage-account-violates-policy) for tracked Azure issues and details.
- `networkAcls.defaultAction` must be `Allow` (or `networkAcls` omitted entirely) - storage account firewall rules aren't supported by deployment scripts, independent of `publicNetworkAccess`. Use `publicNetworkAccess: 'Disabled'` instead to block public access.
- If `deploymentScriptSettings.subnetId` is set, that subnet must also be in the `csInfraSubscriptionId` subscription - Azure Container Instances require the delegated subnet to be in the same subscription as the container group.

See Microsoft's [Access a private virtual network from a Bicep deployment script](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-script-vnet-private-endpoint) for the reference architecture this feature is based on.

## Contributing

If you want to develop new content or improve on this collection, please open an issue or create a pull request. All contributions are welcome!

## Support

This is a community-driven, open source project aimed to register Falcon Cloud Security with Azure using Bicep. While not an official CrowdStrike product, this repository is maintained by CrowdStrike and supported in collaboration with the open source developer community.

For additional information, please refer to the [SUPPORT.md](SUPPORT.md) file.

## License Information

See the [LICENSE](LICENSE) for more information.
