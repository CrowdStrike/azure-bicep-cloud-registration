/*
  This Bicep template defines shared functions for CrowdStrike Agentless Scanning.
  Copyright (c) 2026 CrowdStrike, Inc.
*/

@export()
@description('Returns the entries of the subscription ID to locations map for the given subscription entries, or an empty object when the map is empty. Nested deployments receive only their own subscriptions, so their size does not grow with the total number of registered subscriptions.')
func filterLocationsPerSubscription(locationsPerSubscription object, subscriptionEntries array) object =>
  empty(locationsPerSubscription)
    ? {}
    : toObject(
        subscriptionEntries,
        entry => entry.subscriptionId,
        entry => locationsPerSubscription[entry.subscriptionId]
      )
