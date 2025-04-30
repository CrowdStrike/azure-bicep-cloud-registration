import {RealTimeVisibilityDetectionSettings} from 'real-time-visibility-detection.bicep'

@export()
@description('Settings for all feature modules')
type FeatureSettings = {
  @description('Settings for real time visibility and detection module')
  realTimeVisibilityDetection: RealTimeVisibilityDetectionSettings
}
