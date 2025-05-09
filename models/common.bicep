import { RealTimeVisibilityDetectionSettings } from 'real-time-visibility-detection.bicep'

@export()
@description('Master configuration object containing settings for all CrowdStrike feature modules')
type FeatureSettings = {
  @description('Configuration settings for the real-time visibility and detection module, which enables monitoring of Azure activity and Entra ID logs')
  realTimeVisibilityDetection: RealTimeVisibilityDetectionSettings
}
