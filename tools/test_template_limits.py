"""Registration sizes the templates must support without exceeding Azure Resource Manager limits.

Run from the repository root: python3 -m unittest discover -s tools -v
"""

import unittest

from check_template_limits import (
    BUDGET_BYTES,
    DEFAULT_ENTRY_POINTS,
    ENTRY_BYTES,
    REPO_ROOT,
    analyze,
    compile_template,
    entry_values,
)

SUBSCRIPTIONS = 2000
# Registered management groups the unbatched per-management-group loops must hold
MANAGEMENT_GROUPS = 150
# Scanning regions per subscription; Azure has about 60
REGIONS = 100

MANAGEMENT_GROUP_ENTRY_POINT, SUBSCRIPTION_ENTRY_POINT = DEFAULT_ENTRY_POINTS


class EntryPointLimits:
    """Checks shared by both entry points; subclasses set entry_point and batch_deployments."""

    entry_point = ""
    batch_deployments = ()

    @classmethod
    def setUpClass(cls):
        template = compile_template(REPO_ROOT / cls.entry_point)
        cls.default = analyze(template, entry_values(template))
        cls.maximum = analyze(template, entry_values(template, use_max=True))

    def test_finds_every_batch_deployment(self):
        paths = [batch.path for batch in self.default.batches]
        for deployment in self.batch_deployments:
            with self.subTest(deployment=deployment):
                self.assertTrue(any(path.endswith(deployment) for path in paths), f"{deployment} not in {paths}")

    def test_batches_within_limits_at_default_batch_size(self):
        self.assertEqual(self.default.violations, [])

    def test_batches_within_limits_at_maximum_batch_size(self):
        self.assertEqual(self.maximum.violations, [])

    def test_deployments_starting_batches_fit_2000_subscriptions(self):
        for capacity in self.default.capacities:
            if capacity.unit == "subscriptions":
                with self.subTest(deployment=capacity.path):
                    self.assertGreaterEqual(capacity.count, SUBSCRIPTIONS)

    def unbatched_loops(self, kind: str) -> list:
        return [c for c in self.default.capacities if c.unit not in ("subscriptions", "management groups") and kind in c.unit]

    def test_every_unbatched_loop_has_a_threshold(self):
        for capacity in self.default.capacities:
            if capacity.unit not in ("subscriptions", "management groups"):
                with self.subTest(deployment=capacity.path, array=capacity.unit):
                    self.assertTrue("Locations" in capacity.unit or "managementGroup" in capacity.unit)

    def test_region_loops_fit_100_regions(self):
        for capacity in self.unbatched_loops("Locations"):
            with self.subTest(deployment=capacity.path, array=capacity.unit):
                self.assertGreaterEqual(capacity.count, REGIONS)

    def test_management_group_loops_fit_150_management_groups(self):
        for capacity in self.unbatched_loops("managementGroup"):
            with self.subTest(deployment=capacity.path, array=capacity.unit):
                self.assertGreaterEqual(capacity.count, MANAGEMENT_GROUPS)


class ManagementGroupEntryPointLimits(EntryPointLimits, unittest.TestCase):
    entry_point = MANAGEMENT_GROUP_ENTRY_POINT
    batch_deployments = (
        "cs-rg-batch",
        "cs-activity-batch",
        "cs-inv-batch",
        "cs-scan-mg-batch",
        "cs-scanning-mg > cs-sc",
        "cs-scanning-standalone",
        "cs-scanning-roles-batch",
    )

    def test_scanning_fits_150_management_groups(self):
        self.assertGreaterEqual(self.default.capacity("cs-scanning-mg > cs-scan-mg-batch").count, MANAGEMENT_GROUPS)

    def test_scanning_management_group_batch_holds_2000_subscriptions(self):
        # A management group batch also carries the subscription entries of its management groups, once as input and once in the slices it passes on
        batch = next(b for b in self.default.batches if b.path.endswith("cs-scanning-mg > cs-scan-mg-batch"))
        self.assertLessEqual(batch.bytes + 2 * SUBSCRIPTIONS * ENTRY_BYTES, BUDGET_BYTES)


class SubscriptionEntryPointLimits(EntryPointLimits, unittest.TestCase):
    entry_point = SUBSCRIPTION_ENTRY_POINT
    batch_deployments = (
        "cs-rg-batch",
        "cs-activity-batch",
        "cs-inv-batch",
        "cs-scanning-batch",
        "cs-scanning-roles-batch",
    )


if __name__ == "__main__":
    unittest.main()
