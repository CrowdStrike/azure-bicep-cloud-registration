@export()
@description('Settings for asset inventory module')
type AssetInventorySettings = {
  @description('The main feature toggle of the asset inventory module')
  enabled: bool

  @description('Assign required permissions on Azure Default Subscription automatically. Defaults to true.')
  assignAzureSubscriptionPermissions: bool

  @description('The name of the resource group for asset inventory resources')
  resourceGroupName: string
}
