![CrowdStrike Falcon](https://raw.githubusercontent.com/CrowdStrike/falconpy/main/docs/asset/cs-logo.png)

# Falcon Cloud Security Registration with Azure Bicep

The Azure Bicep templates in this repository allow for an easy and seamless integration of Azure environments into CrowdStrike Falcon Cloud Security.

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

The Bicep files in this repo register an Azure management group (and all Subscriptions in the management group) or an individual Azure Subscription, to CrowdStrike Falcon Cloud Security by performing the following actions:

- Creates an app registration in Microsoft Entra ID, including Microsoft Graph API permissions and administrative consent
- Makes the API calls necessary to register the management group/subscription with Falcon Cloud Security
- Assigns the following Azure RBAC permissions to the created app registration with a scope of either the management group or individual Subscription, depending on which bicep file is being used:
  - Reader
  - Security Reader
  - Key Vault Reader
  - Azure Kubernetes Service RBAC Reader
- Assigns the **cs-website-reader** custom role on the management group/subscription with the following actions:
  - Microsoft.Web/sites/Read
  - Microsoft.Web/sites/config/Read
  - Microsoft.Web/sites/config/list/Action
- If the `deployIOA` parameter is set to true, the file also:
   - Deploys an Event Hub Namespace, two Event Hubs, two App Service Plans, and additional infrastructure to the subscription that has been designated as the default subscription (which is done via the `defaultSubscriptionId` parameter). This infrastructure is used to stream Entra ID Sign In and Audit Logs, as well as Azure Activity logs, to Falcon Cloud Security.
   - Creates a Microsoft Entra ID diagnostic setting that forwards Sign In and Audit Logs to the newly-created Event Hub
   - Individual subscription deployments only:
      - Creates an Azure Activity Log diagnostic setting in the subscription being registered with Falcon Cloud Security that forwards Activity Logs to the newly-created Event Hub
   - Management group deployments only:
      - Creates a user-assigned managed identity with `Reader` permissions on the Tenant root group to list enabled subscriptions
      - Creates an Azure Activity Log diagnostic setting in all active subscriptions that forwards Activity Logs to the newly-created Event Hub
      - Creates an Azure policy definition and management group assignment that will create an Azure Activity Log diagnostic settings for new subscriptions that forwards Activity Logs to the newly-created Event Hub

> [!NOTE]
> The user-assigned managed identity created during management group deployment is only used to get a list of all active subscriptions in a tenant and can be safely removed after a successful registration. The underlying resources using the user-assigned managed identity are removed automatically. 
   
> [!IMPORTANT]
> Management Group Deployments only support registration at the Azure root management group (Tenant root group).

## Prerequisites

1. Ensure you have a CrowdStrike API client ID and client secret for Falcon Cloud Security with the CSPM Registration Read and Write scopes. If you don't already have API credentials, you can set them up in the Falcon console (you must be a Falcon Admin to access the API clients page):
   - [US-1](https://falcon.crowdstrike.com/api-clients-and-keys/)
   - [US-2](https://falcon.us-2.crowdstrike.com/api-clients-and-keys/)
   - [EU-1](https://falcon.eu-1.crowdstrike.com/api-clients-and-keys/clients)

2. [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/) must be installed on your local machine
> [!IMPORTANT]
> This Bicep template can only be deployed via Azure CLI running on a local machine. You cannot deploy using Azure CLI in Azure Cloud Shell.


## Required permissions

- **Application Developer**, **Cloud Application Administrator**, or **Application Administrator** role in Microsoft Entra ID to create the app registration in Microsoft Entra ID
- **Privileged Role Administrator** or **Global Administrator** role in Microsoft Entra ID to provide administrative consent to the requested Microsoft Graph API permissions.

> [!NOTE]
> Use the optional `grantAdminConsent` parameter to disable granting administrative consent to the requested Microsoft Graph API permissions automatically.

- **Owner** role for the Azure management group to be integrated into Falcon Cloud Security
- **Owner** role for the Azure subscription to be used for deployment of the infrastructure for Indicator of Attack (IOA) assessment

## Template Parameters

You can use any of these methods to pass parameters:

- Generate a parameter file: [generate-params](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-cli#generate-params)
- Deploy the Bicep file using the parameters file: [deploy bicep file with parameters file](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameter-files?tabs=Bicep#deploy-bicep-file-with-parameters-file)
- Pass the parameters as arguments: [inline-parameters](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-cli#inline-parameters)

| Parameter name                          | Required | Description                                                                                                                    |
|-----------------------------------------|----------|--------------------------------------------------------------------------------------------------------------------------------|
| `defaultSubscriptionId`                 | yes      | Subscription Id of the default Azure Subscription.                                                                             |
| `falconCID`                             | yes      | CID for the Falcon API.                                                                                                        |
| `falconClientId`                        | yes      | Client ID for the Falcon API.                                                                                                  |
| `falconClientSecret`                    | yes      | Client secret for the Falcon API.                                                                                              |
| `falconCloudRegion`                     | yes      | Falcon cloud region. Allowed values are `US-1`, `US-2`, or `EU-1`.                                                             |
| `useExistingAppRegistration`            | no       | Use an existing Application Registration. Defaults to `false`.                                                                 |
| `grantAppRegistrationAdminConsent`      | no       | Grant admin consent for Application Registration. Defaults to `true`.                                                          |
| `azureClientId`                         | no       | Application Id of an existing Application Registration in Entra ID. Only used with parameter `useExistingAppRegistration`.     |
| `azureClientSecret`                     | no       | Application Secret of an existing Application Registration in Entra ID. Only used with parameter `useExistingAppRegistration`. |
| `azurePrincipalId`                      | no       | Principal Id of the Application Registration in Entra ID. Only used with parameter `useExistingAppRegistration`.               |
| `azureAccountType`                      | no       | Type of the Azure account to integrate.                                                                                        |
| `location`                              | no       | Location for the resources deployed in this solution.                                                                          |
| `tags`                                  | no       | Tags to be applied to all resources.                                                                                           |
| `deployIOM`                             | no       | Deploy Indicator of Misconfiguration (IOM) integration. Defaults to `true`.                                                    |
| `assignAzureSubscriptionPermissions`    | no       | Assign required permissions on Azure Default Subscription automatically. Defaults to `false` when deploying to Management Group, defaults to `true` when deploying to indidvidual Subscription.|
| `assignAzureManagementGroupPermissions` | no       | Assign required permissions Azure Management Group automatically. Defaults to `true` when deploying to Management Group, defaults to `false` when deploying to indidvidual Subscription.|
| `deployIOA`                             | no       | Deploy Indicator of Attack (IOA) integration. Defaults to `true`.                                                              |
| `enableAppInsights`                     | no       | Enable Application Insights for additional logging of Function Apps. Defaults to `false`.                                      |
| `deployActivityLogDiagnosticSettings`   | no       | Deploy Activity Log Diagnostic Settings to all active Azure subscriptions. Defaults to `true`.                                 |
| `deployActivityLogDiagnosticSettingsPolicy`   | no       | Deploy Activity Log Diagnostic Settings policy. Defaults to `true`.'                                                     |
| `deployEntraLogDiagnosticSettings`      | no       | Deploy Entra Log Diagnostic Settings. Defaults to `true`.                                                                      |

## Resource Names
Do not change the names of the following Azure resources as they are used for registration validation and must remain unchanged. Other resource names in the files can be changed according to your internal naming convention.
- Diagnostic Setting in subscription:
   - Default name: cs-monitor-activity-to-eventhub
- IOA Resource Group:
   - Default name: cs-ioa-group
- Event Hub Namespace:
   - Default name: cs-horizon-ns-<sub_id>
- Event Hubs:
   - Default name: cs-eventhub-monitor-activity-logs
   - Default name: cs-eventhub-monitor-aad-logs
- Function apps:
   - Default name: cs-activity-func-<> (has to include activity-func)
   - Default name: cs-aad-func-<> (has to include aad-func)

## Deployment

### Preparation

1. Download this repo to your local machine
2. Open a new Terminal window and change directory to point at the downloaded repo
3. Run `az login` to log into Azure via the Azure CLI.
   - If registering a management group: Be sure to log into a subscription that is in the tenant whose root Management Group you want to register with Falcon Cloud Security.
   - If registering an individual subscription: Be sure to log into the subscription you want to register with Falcon Cloud SEcurity
5. Run the appropriate deployment command provided below.

### Deployment Command for Registering a Management Group

```sh
az deployment mg create --name 'cs-managementgroup-deployment' --location westus \
  --management-group-id $(az account show --query tenantId -o tsv) \
  --template-file cs-deployment-managementGroup.bicep \
  --only-show-errors
```

To track progress of the deployment or if you encounter issues and want to see detailed error messages:
   - Open the Azure Portal
   - Go to **Management Groups** > **Tenant Root Groups**
   - Select **Deployments** from the left menu.
   - You will see the deployment in progress, whose default name is `cs-managementgroup-deployment`


#### Remediate existing subscriptions using Azure Policy

If the default deployment of Azure Activity Log diagnostic settings to all active subscriptions has been disabled, you can use a remeditation task as part of Azure Policy to deploy Azure Activity Log diagnostic settings to existing subscriptions in a tenant to enable indicators of attack (IOAs).

> [!NOTE]
> Once an Azure Policy assignment has been created it takes time for Azure Policy to evaluate the compliance state of existing subscriptions. There is no predefined expectation of when the evaluation cycle completes. Please see [Azure Policy Evaluation Triggers](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/get-compliance-data#evaluation-triggers) for more information.

To start a manual remediation task:

1. In the Azure portal, navigate to **Management Groups** and select the tenant root group.
2. Go to **Governance** > **Policy** and select **Authoring** > **Assignments**.
3. Click the **CrowdStrike IOA** assignment and then remediate the assignment by [creating a remediation task from a non-compliant policy assignment](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources?tabs=azure-portal#option-2-create-a-remediation-task-from-a-non-compliant-policy-assignment).


### Deployment Command for Registering an Individual Subscription

```sh
az deployment sub create --name 'cs-subscription-deployment' --location westus \
  --template-file cs-deployment-subscription.bicep \
  --only-show-errors
```

To track progress of the deployment or if you encounter issues and want to see detailed error messages:
   - Open the Azure Portal
   - Go to **Subscriptions** and select the Subscription you are registering
   - Select **Deployments** from the left menu.
   - You will see the deployment in progress, whose default name is `cs-subscription-deployment`

> [!NOTE]
> The deployment command can be executed multiple times to register additional Azure subscriptions into CrowdStrike Falcon Cloud Security.

## Troubleshooting

### SSL Certificate Verification Failure
Some customers may encounter an error message when trying to run the deployment command that says something similar to: `Error while attempting to retrieve the latest Bicep version: HTTPSConnectionPool(host='aka.ms', port=443): Max retries exceeded with url: /BicepLatestRelease (Caused by SSLError(SSLCertVerificationError(1, '[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:1000)')))`

This is usually caused by the presence of a web proxy on your network using self-signed certificates. The Azure CLI has a dependency on Python and Python is not using the correct certificates to make requests. The easiest solution is to download the Bicep Tools independently of the Azure CLI and then tell the Azure CLI to use that version of Bicep Tools when needed. Here's how:
1. Follow [Microsoft's instructions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#install-manually) on how to manually install the Bicep Tools on your local machine
2. Open a new terminal window on your machine and run the following command, which tells Azure CLI to use the manually downloaded version of Bicep Tools instead of trying to install the tools as part of Azure CLI: `az config set bicep.use_binary_from_path=True`
3. Follow the deployment instructions again. This time it should work without issue.

### Existing Key Vault

When using our Bicep files to set up Indicator Of Attack, a Key Vault is created to store sensitive information. As per Microsoft's recommendation, the Key Vault is created with [purge protection](https://learn.microsoft.com/en-us/azure/key-vault/general/soft-delete-overview#purge-protection) enabled.

When deleting the resource group _cs-ioa-group_, the Key Vault gets soft-deleted.

If you encounter any issues while trying to create the Key Vault, please follow [Microsoft's instructions](https://learn.microsoft.com/en-us/azure/key-vault/general/key-vault-recovery?tabs=azure-portal#list-recover-or-purge-a-soft-deleted-key-vault) on how to recover a soft-deleted Key Vault.

### IOAs appear inactive for discovered subscriptions after registering an Azure management group

After registering a management group and manually remediating the CrowdStrike IOA Azure policy assignment, IOAs can remain inactive for some discovered subscriptions. This can happen when the diagnostic settings are not configured in the registered subscriptions.

The evaluation of the assigned Azure policy responsible for the diagnostic settings creation can take some time to properly evaluate which resources need to be remediated (See [Evaluation Triggers](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/get-compliance-data#evaluation-triggers)).

Make sure that all the existing subscriptions are properly listed under [resources to remediate](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources?tabs=azure-portal#step-2-specify-remediation-task-details) when creating the remediation tasks.

### Tenant ID, application ID, principal ID, and scope are not allowed to be updated

You might encounter this error when registering a management group using Bicep.

This happens when you have pre-existing role assignments for the **Monitoring Contributor**, **Lab Services Reader**, and **Azure Event Hubs Data Owner** roles to a deleted management identity created by the **CrowdStrike IOA** policy assignment.

In the Azure portal, navigate to **Management Groups** and select the tenant root group. Then go to **Access Control (IAM)** and delete all role assignments of the **Monitoring Contributor**, **Lab Services Reader**, and **Azure Event Hubs Data Owner** roles assigned to **Identity not found**.

## Contributing

If you want to develop new content or improve on this collection, please open an issue or create a pull request. All contributions are welcome!

## Support

This is a community-driven, open source project aimed to register Falcon Cloud Security with Azure using Bicep. While not an official CrowdStrike product, this repository is maintained by CrowdStrike and supported in collaboration with the open source developer community.

For additional information, please refer to the [SUPPORT.md](SUPPORT.md) file.

## License Information

See the [LICENSE](LICENSE) for more information.
