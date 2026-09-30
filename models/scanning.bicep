/*
  This Bicep template defines shared constants for CrowdStrike Scanning.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

@export()
@description('Maximum number of subscriptions per scanning batch. scanningSubBatch.bicep declares two copy loops over its subscription entries (per-subscription roles and per-subscription scanning infrastructure). ARM counts every copy iteration toward the 800-resource template limit, including iterations whose condition is false, so a batch of N subscriptions always declares 2 * N resources.')
var maxScanningBatchSize = 400
