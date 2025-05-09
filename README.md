![CrowdStrike Falcon](https://raw.githubusercontent.com/CrowdStrike/falconpy/main/docs/asset/cs-logo.png)

# Falcon Cloud Security Registration with Azure Bicep

The Azure Bicep templates in this repository allow for an easy and seamless integration of Azure environments into CrowdStrike Falcon Cloud Security for Asset Inventory and Real Time Visibility and Detection.

## Table of Contents
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

The Bicep files in this repo register Azure management groups (and all Subscriptions in those management groups) and/or individual Azure Subscriptions to CrowdStrike Falcon Cloud Security by performing the following actions:

- Create resource group `rg-cs-prod` (or with custom prefix/suffix if specified) in the specified subscription `csInfraSubscriptionId`
- Assigns the following Azure RBAC permissions to the created app registration with a scope of either the management groups or individual Subscriptions, depending on which bicep file is being used:
  - Reader
- Management group level deployment:
    - Creates a user-assigned managed identity with `Reader` permissions on the specified management groups to list enabled subscriptions
- Assigns the **role-csreader-sub/\<management group name\>** custom role on the management group/subscription with the following actions:
  - Microsoft.Web/sites/Read
  - Microsoft.Web/sites/config/Read
  - Microsoft.Web/sites/config/list/Action
- If the `featureSettings.realTimeVisibilityDetection.enabled` parameter is set to true, the file also:
   - Deploys an Event Hub Namespace, two Event Hubs, and additional infrastructure to the subscription that has been designated as the default subscription (which is done via the `csInfraSubscriptionId` parameter). This infrastructure is used to stream Entra ID Sign In and Audit Logs, as well as Azure Activity logs, to Falcon Cloud Security.
   - Creates a Microsoft Entra ID diagnostic setting that forwards Sign In and Audit Logs to the newly-created Event Hub
   - Individual subscription deployments only:
      - Creates an Azure Activity Log diagnostic setting in the subscription being registered with Falcon Cloud Security that forwards Activity Logs to the newly-created Event Hub
   - Management group deployments only:
      - Creates an Azure Activity Log diagnostic setting in all active subscriptions that forwards Activity Logs to the newly-created Event Hub
      - Creates an Azure policy definition and management group assignment that will create an Azure Activity Log diagnostic settings for new subscriptions that forwards Activity Logs to the newly-created Event Hub (only when `featureSettings.realTimeVisibilityDetection.activityLogSettings.deployRemediationPolicy` is set to `true`)

> [!NOTE]
> The user-assigned managed identity created during management group deployment is only used to get a list of all active subscriptions in the specified management groups and can be safely removed after a successful registration. The underlying resources using the user-assigned managed identity are removed automatically.

## Prerequisites

1. Ensure you create a registration for your Azure tenant on Falcon Cloud Security, and grant admin consent to Falcon Cloud Security App
   - [US-1](https://falcon.crowdstrike.com/cloud-security/registration-v2/azure)
   - [US-2](https://falcon.us-2.crowdstrike.com/cloud-security/registration-v2/azure)
   - [EU-1](https://falcon.eu-1.crowdstrike.com/cloud-security/registration-v2/azure)
2. Ensure you have a CrowdStrike API URL, client ID and client secret for Falcon Cloud Security with the CSPM Registration Read and Write scopes. If you don't already have API credentials, you can set them up in the Falcon console (you must be a Falcon Admin to access the API clients page):
   - [US-1](https://falcon.crowdstrike.com/api-clients-and-keys/)
   - [US-2](https://falcon.us-2.crowdstrike.com/api-clients-and-keys/)
   - [EU-1](https://falcon.eu-1.crowdstrike.com/api-clients-and-keys/clients)

3. [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/) must be installed on your local machine
> [!IMPORTANT]
> This Bicep template can only be deployed via Azure CLI running on a local machine. You cannot deploy using Azure CLI in Azure Cloud Shell.


## Required permissions

- **Owner** role for the Azure management groups and subscriptions to be integrated into Falcon Cloud Security

## Template Parameters

You can use any of these methods to pass parameters:

- Generate a parameter file: [generate-params](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-cli#generate-params)
- Deploy the Bicep file using the parameters file: [deploy bicep file with parameters file](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameter-files?tabs=Bicep#deploy-bicep-file-with-parameters-file)
- Pass the parameters as arguments: [inline-parameters](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-cli#inline-parameters)

| Parameter name                                                                          | Required | Description                                                                                                                                                                             |
|-----------------------------------------------------------------------------------------|----------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `csInfraSubscriptionId`                                                                 | yes      | Subscription Id of the default Azure Subscription.                                                                                                                                      |
| `managementGroupIds`                                                                    | yes      | List of management groups to be integrated into Falcon Cloud Security. Only used in management group level deployment.                                                                  |
| `subscriptionIds`                                                                       | yes      | List of individual subscriptions to be integrated into Falcon Cloud Security                                                                                                            |
| `location`                                                                              | no       | Azure location (aka region) where global resources will be deployed. Default is the deployment location.                                                                                |
| `resourceNamePrefix`                                                                    | no       | Optional prefix added to all resource names for organization and identification purposes.                                                                                               |
| `resourceNameSuffix`                                                                    | no       | Optional suffix added to all resource names for organization and identification purposes.                                                                                               |
| `falconIpAddresses`                                                                     | yes      | Falcon public IP addresses. Only used when `featureSettings.realTimeVisibilityDetection.enabled` is set to `true`. These will be configured to public network access list of EventHubs. |
| `azurePrincipalId`                                                                      | yes      | Principal Id of Falcon Cloud Security App in Entra ID.                                                                                                                                  |
| `env`                                                                                   | no       | Environment label (e.g., prod, stag or dev) used for resource naming and tagging. Default set to `prod`                                                                                |
| `tags`                                                                                  | no       | Tags to be applied to all deployed resources. Used for resource organization and governance.                                                                                            |
| `featureSettings.realTimeVisibilityDetection.enabled`                                   | no       | Deploy `Real Time Visibility and Detection(RTVD)` integration. Defaults to `true`.                                                                                                      |
| `featureSettings.realTimeVisibilityDetection.activityLogSettings.enabled`               | no       | Controls whether Activity Log Diagnostic Settings are deployed to monitored Azure subscriptions. Defaults to `true`.                                                                     |
| `featureSettings.realTimeVisibilityDetection.activityLogSettings.deployRemediationPolicy` | no     | Controls whether to deploy a policy that automatically configures Activity Log Diagnostic Settings on new subscriptions. Defaults to `true`.                                             |
| `featureSettings.realTimeVisibilityDetection.entraIdLogSettings.enabled`                | no       | Controls whether Entra ID Log Diagnostic Settings are deployed. Defaults to `true`.                                                                                                     |
| `featureSettings.realTimeVisibilityDetection.activityLogSettings.existingEventhub`      | no       | Configuration for using an existing Event Hub instead of creating a new one for Activity Logs.|
| `featureSettings.realTimeVisibilityDetection.activityLogSettings.existingEventhub.use`  | no       | When set to true, an existing Event Hub will be used instead of creating a new one. Defaults to `false`.|
| `featureSettings.realTimeVisibilityDetection.activityLogSettings.existingEventhub.subscriptionId` | no | Subscription ID where the existing Event Hub is located.|
| `featureSettings.realTimeVisibilityDetection.activityLogSettings.existingEventhub.resourceGroupName` | no | Resource group name where the existing Event Hub is located.|
| `featureSettings.realTimeVisibilityDetection.activityLogSettings.existingEventhub.namespaceName` | no | Name of the existing Event Hub Namespace.|
| `featureSettings.realTimeVisibilityDetection.activityLogSettings.existingEventhub.name` | no | Name of the existing Event Hub instance to use.|
| `featureSettings.realTimeVisibilityDetection.entraIdLogSettings.existingEventhub`       | no       | Configuration for using an existing Event Hub instead of creating a new one for Entra ID Logs.|
| `featureSettings.realTimeVisibilityDetection.entraIdLogSettings.existingEventhub.use`  | no       | When set to true, an existing Event Hub will be used instead of creating a new one. Defaults to `false`.|
| `featureSettings.realTimeVisibilityDetection.entraIdLogSettings.existingEventhub.subscriptionId` | no | Subscription ID where the existing Event Hub is located.|
| `featureSettings.realTimeVisibilityDetection.entraIdLogSettings.existingEventhub.resourceGroupName` | no | Resource group name where the existing Event Hub is located.|
| `featureSettings.realTimeVisibilityDetection.entraIdLogSettings.existingEventhub.namespaceName` | no | Name of the existing Event Hub Namespace.|
| `featureSettings.realTimeVisibilityDetection.entraIdLogSettings.existingEventhub.name` | no | Name of the existing Event Hub instance to use.|

## Deployment

### Preparation

1. Download this repo to your local machine
2. Open a new Terminal window and change directory to point at the downloaded repo
3. Run `az login` to log into Azure via the Azure CLI. Be sure to log into a subscription that is in the tenant you want to register with Falcon Cloud Security.
4. Run the appropriate deployment command provided below.

### Deployment Command for Registering Management Groups and/or Individual Subscriptions

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
> The cs-deployment-management-group.bicep template can be used to register a list of management groups (and all subscriptions in those management groups) and/or a list of individual subscriptions to CrowdStrike Falcon Cloud Security.

To track progress of the deployment or if you encounter issues and want to see detailed error messages:
   - Open the Azure Portal
   - Go to **Management Groups** > **[management group of the deployment stack]**
   - Select **Governance** > **Deployment stacks** from the left menu.
   - You will find the name you specified in the above command


#### Remediate existing subscriptions using Azure Policy

> [!NOTE]
> This section is only applicable when `featureSettings.realTimeVisibilityDetection.activityLogSettings.deployRemediationPolicy` is set to `true`.

If the default deployment of Azure Activity Log diagnostic settings to all active subscriptions has been disabled, you can use a remeditation task as part of Azure Policy to deploy Azure Activity Log diagnostic settings to existing subscriptions in a tenant to enable `Real Time Visibility and Detection (RTVD)`.

> [!NOTE]
> Once an Azure Policy assignment has been created it takes time for Azure Policy to evaluate the compliance state of existing subscriptions. There is no predefined expectation of when the evaluation cycle completes. Please see [Azure Policy Evaluation Triggers](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/get-compliance-data#evaluation-triggers) for more information.

To start a manual remediation task:

1. In the Azure portal, navigate to **Management Groups** and select the tenant root group.
2. Go to **Governance** > **Policy** and select **Authoring** > **Assignments**.
3. Click the **CrowdStrike Real Time Visibility and Detection** assignment and then remediate the assignment by [creating a remediation task from a non-compliant policy assignment](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources?tabs=azure-portal#option-2-create-a-remediation-task-from-a-non-compliant-policy-assignment).


### Deployment Command for Registering Individual Subscriptions

```sh
az stack sk create --name '<deployment stack name you want to use>' --location westus \
  --template-file cs-deployment-subscription.bicep \
  --parameters '<file path of the Bicep parameter file storing all the input parameters>' \
  --action-on-unmanage deleteAll \
  --deny-settings-mode None \
  --only-show-errors
```

To track progress of the deployment or if you encounter issues and want to see detailed error messages:
   - Open the Azure Portal
   - Go to **Subscriptions** and select the Subscription you run the deployment command
   - Select **Settings** > **Deployment stacks** from the left menu.
   - You will find the name you specified in the above command

## Troubleshooting

### SSL Certificate Verification Failure
Some customers may encounter an error message when trying to run the deployment command that says something similar to: `Error while attempting to retrieve the latest Bicep version: HTTPSConnectionPool(host='aka.ms', port=443): Max retries exceeded with url: /BicepLatestRelease (Caused by SSLError(SSLCertVerificationError(1, '[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:1000)')))`

This is usually caused by the presence of a web proxy on your network using self-signed certificates. The Azure CLI has a dependency on Python and Python is not using the correct certificates to make requests. The easiest solution is to download the Bicep Tools independently of the Azure CLI and then tell the Azure CLI to use that version of Bicep Tools when needed. Here's how:
1. Follow [Microsoft's instructions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#install-manually) on how to manually install the Bicep Tools on your local machine
2. Open a new terminal window on your machine and run the following command, which tells Azure CLI to use the manually downloaded version of Bicep Tools instead of trying to install the tools as part of Azure CLI: `az config set bicep.use_binary_from_path=True`
3. Follow the deployment instructions again. This time it should work without issue.

### Real Time Visibility and Detection appears inactive for discovered subscriptions after registering an Azure management group

After registering a management group and manually remediating the CrowdStrike Real Time Visibility and Detection Azure policy assignment, Real Time Visibility and Detection can remain inactive for some discovered subscriptions. This can happen when the diagnostic settings are not configured in the registered subscriptions.

The evaluation of the assigned Azure policy responsible for the diagnostic settings creation can take some time to properly evaluate which resources need to be remediated (See [Evaluation Triggers](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/get-compliance-data#evaluation-triggers)).

Make sure that all the existing subscriptions are properly listed under [resources to remediate](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources?tabs=azure-portal#step-2-specify-remediation-task-details) when creating the remediation tasks.

## Contributing

If you want to develop new content or improve on this collection, please open an issue or create a pull request. All contributions are welcome!

## Support

This is a community-driven, open source project aimed to register Falcon Cloud Security with Azure using Bicep. While not an official CrowdStrike product, this repository is maintained by CrowdStrike and supported in collaboration with the open source developer community.

For additional information, please refer to the [SUPPORT.md](SUPPORT.md) file.

## License Information

See the [LICENSE](LICENSE) for more information.
