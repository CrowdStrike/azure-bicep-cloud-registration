@export()
@description('Settings for asset inventory module')
type AssetInventorySettings = {
  @description('Assign required permissions on Azure Default Subscription automatically. Defaults to true.')
  assignAzureSubscriptionPermissions: bool

  @description('The name of the resource group for asset inventory resources')
  resourceGroupName: string
}
