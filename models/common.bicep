import {AssetInventorySettings} from 'asset-inventory.bicep'
import {RealTimeVisibilityDetectionSettings} from 'real-time-visibility-detection.bicep'

@export()
@description('Settings for all feature modules')
type FeatureSettings = {
  @description('Settings for asset inventory module')
  assetInventory: AssetInventorySettings

  @description('Settings for real time visibility and detection module')
  realTimeVisibilityDetection: RealTimeVisibilityDetectionSettings
}
