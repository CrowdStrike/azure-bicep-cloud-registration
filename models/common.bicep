import { LogIngestionSettings } from 'log-ingestion.bicep'

/*
  This Bicep template defines common types and models used across the CrowdStrike deployment templates.
  Copyright (c) 2025 CrowdStrike, Inc.
*/

@export()
@description('Master configuration object containing settings for all CrowdStrike feature modules')
type FeatureSettings = {
  @description('Configuration settings for the log ingestion module, which enables monitoring of Azure activity and Entra ID logs')
  logIngestionSettings: LogIngestionSettings
}
