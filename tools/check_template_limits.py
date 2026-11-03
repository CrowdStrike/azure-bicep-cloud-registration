#!/usr/bin/env python3
"""Estimate the size of every deployment in the compiled entry points against Azure Resource Manager limits.

ARM limits (https://learn.microsoft.com/azure/azure-resource-manager/templates/best-practices#template-limits):
  * 4 MB per deployment, measured after copy loops are expanded. ARM stores the inline
    nested template of a module once per loop instance, so a batch deployment grows by
    the size of its per-subscription templates for every subscription in the batch.
  * 800 resources per deployment, counting every copy-loop instance (also those whose
    condition is false).
  * 256 parameters, 256 variables, 64 outputs, 24,576 characters per expression.

Batch deployments are found by their sliced input, take(skip(list, ...), <batch size>). The batch
size expression is evaluated from the entry-point parameters down: parameters(), variables(), min(),
max() and integer literals, so a per-module cap such as min(parameters('batchSize'),
variables('maxScanningBatchSize')) resolves to the batch size the module really deploys.

The tool reports three things:
  * violations: a batch deployment or a template above a limit. The command exits 1 on any.
  * the size and resource count of every batch deployment.
  * capacities: how many subscriptions or management groups fit in a deployment that starts
    batches, and how many instances fit in a copy loop over an unbatched array (management
    groups, regions). tools/test_template_limits.py asserts the capacities a registration needs.

Usage:
  tools/check_template_limits.py                        # both entry points, default values
  tools/check_template_limits.py --set subscriptionBatchSize=100
  tools/check_template_limits.py -v cs-deployment-subscription.bicep
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

MIB = 1024 * 1024
MAX_DEPLOYMENT_BYTES = 4 * MIB
MAX_RESOURCES = 800
MAX_PARAMETERS = 256
MAX_VARIABLES = 256
MAX_OUTPUTS = 64
MAX_EXPRESSION_CHARS = 24576
BUDGET_BYTES = int(MAX_DEPLOYMENT_BYTES * 0.9)
# Resolved size of one subscription entry (subscription ID and its scanning locations) in a batch slice
ENTRY_BYTES = 250

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_ENTRY_POINTS = ["cs-deployment-management-group.bicep", "cs-deployment-subscription.bicep"]

LENGTH_OF_PARAM = re.compile(r"^\[length\(parameters\('(\w+)'\)\)\]$")
PARAM_REF = re.compile(r"^\[parameters\('(\w+)'\)\]$")
REFERENCE = re.compile(r"(?:parameters|variables)\('(\w+)'\)")
CALL = re.compile(r"^(\w+)\((.*)\)$", re.S)
STRING_ARG = re.compile(r"^'(\w+)'$")


def compile_template(path: Path) -> dict:
    if path.suffix == ".json":
        return json.loads(path.read_text())
    cmd = ["bicep", "build", str(path), "--stdout"] if shutil.which("bicep") else ["az", "bicep", "build", "--file", str(path), "--stdout"]
    try:
        out = subprocess.run(cmd, check=True, capture_output=True, text=True).stdout
    except subprocess.CalledProcessError as e:
        sys.exit(f"{' '.join(cmd)} failed:\n{e.stderr}")
    return json.loads(out)


def size(obj) -> int:
    return len(json.dumps(obj, separators=(",", ":")).encode())


def resources(template: dict) -> list:
    res = template.get("resources", [])
    return list(res.values()) if isinstance(res, dict) else res


def longest_expression(obj) -> int:
    if isinstance(obj, str):
        return len(obj) if obj.startswith("[") and not obj.startswith("[[") else 0
    if isinstance(obj, dict):
        return max((max(longest_expression(k), longest_expression(v)) for k, v in obj.items()), default=0)
    if isinstance(obj, list):
        return max((longest_expression(v) for v in obj), default=0)
    return 0


def label(resource: dict) -> str:
    name = resource.get("name", "?")
    match = re.search(r"format\('\{0\}([a-z-]+)", name) if isinstance(name, str) else None
    return match.group(1).rstrip("-") if match else str(name)[:40]


def nested_deployments(template: dict):
    for resource in resources(template):
        if resource.get("type", "").lower() == "microsoft.resources/deployments" and "template" in resource.get("properties", {}):
            yield resource


def param_expression(resource: dict, name: str):
    value = resource["properties"].get("parameters", {}).get(name, {})
    return value.get("value") if isinstance(value, dict) else None


def split_args(text: str) -> list:
    """Split a function argument list on its top-level commas."""
    args, depth, quoted, start = [], 0, False, 0
    for i, char in enumerate(text):
        if char == "'":
            quoted = not quoted
        elif quoted:
            continue
        elif char in "([":
            depth += 1
        elif char in ")]":
            depth -= 1
        elif char == "," and depth == 0:
            args.append(text[start:i].strip())
            start = i + 1
    args.append(text[start:].strip())
    return args


def find_calls(text: str, function: str):
    """Yield the argument lists of every call to function in an expression."""
    for match in re.finditer(rf"\b{function}\(", text):
        depth, quoted = 0, False
        for i in range(match.end() - 1, len(text)):
            char = text[i]
            if char == "'":
                quoted = not quoted
            elif quoted:
                continue
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    yield split_args(text[match.end():i])
                    break


class Scope:
    """Resolves integer expressions of one template from the int values of its parameters."""

    def __init__(self, template: dict, params: dict):
        self.variables = template.get("variables", {})
        self.params = params

    def resolve(self, expression):
        if isinstance(expression, int) and not isinstance(expression, bool):
            return expression
        if not isinstance(expression, str):
            return None
        text = expression[1:-1] if expression.startswith("[") and expression.endswith("]") else expression
        text = text.strip()
        if re.fullmatch(r"-?\d+", text):
            return int(text)
        call = CALL.match(text)
        if not call:
            return None
        function, args = call.group(1), split_args(call.group(2))
        if function in ("parameters", "variables") and len(args) == 1 and STRING_ARG.match(args[0]):
            name = STRING_ARG.match(args[0]).group(1)
            return self.params.get(name) if function == "parameters" else self.resolve(self.variables.get(name))
        if function in ("min", "max"):
            values = [self.resolve(arg) for arg in args]
            if None in values:
                return None
            return min(values) if function == "min" else max(values)
        return None

    def batch_size(self, expression):
        """Resolve the batch size of a sliced input: the size argument of take(skip(list, ...), size)."""
        if not isinstance(expression, str):
            return None
        for args in find_calls(expression, "take"):
            if len(args) == 2 and args[0].startswith("skip("):
                value = self.resolve(args[1])
                if value is not None:
                    return value
        return None


@dataclass
class Batch:
    path: str
    batch_size: int
    bytes: int
    resources: int
    # Largest batch size within 4 MB and 800 resources
    max_batch_size: int


@dataclass
class Capacity:
    """How many entries of `unit` fit in the deployment at `path` before it exceeds the budget."""

    path: str
    unit: str
    count: int
    bytes_per_entry: int


@dataclass
class Report:
    violations: list = field(default_factory=list)
    batches: list = field(default_factory=list)
    capacities: list = field(default_factory=list)

    def capacity(self, path_suffix: str) -> Capacity:
        matches = [c for c in self.capacities if c.path.endswith(path_suffix)]
        if len(matches) != 1:
            raise KeyError(f"{len(matches)} capacities end with {path_suffix!r}: {[c.path for c in self.capacities]}")
        return matches[0]


def batch_unit(sliced_params: dict) -> str:
    return "management groups" if any("managementGroup" in name for name in sliced_params) else "subscriptions"


class Checker:
    def __init__(self):
        self.report = Report()

    def check_static(self, template: dict, path: str):
        counts = {
            "parameters": (len(template.get("parameters", {})), MAX_PARAMETERS),
            "variables": (len(template.get("variables", {})), MAX_VARIABLES),
            "outputs": (len(template.get("outputs", {})), MAX_OUTPUTS),
            "declared resources": (len(resources(template)), MAX_RESOURCES),
            "expression length": (longest_expression(template), MAX_EXPRESSION_CHARS),
            "template bytes": (size(template), MAX_DEPLOYMENT_BYTES),
        }
        for what, (value, limit) in counts.items():
            if value > limit:
                self.report.violations.append(f"{path}: {what} {value} exceeds the limit of {limit}")

    def check_batch(self, template: dict, path: str, sliced_params: dict):
        """Expand the loops over a batch's sliced input to their full batch size.

        Every entry adds one entry to each sliced input of the batch and one more
        to the parameters its own loop instance receives.
        """
        batch_size = max(sliced_params.values())
        per_entry_bytes = (len(sliced_params) + 1) * ENTRY_BYTES
        looped_bytes = 0
        resources_per_instance = 0
        other_resources = 0
        for resource in resources(template):
            loop = resource.get("copy")
            match = LENGTH_OF_PARAM.match(loop.get("count", "")) if loop else None
            if match and match.group(1) in sliced_params:
                looped_bytes += size(resource)
                resources_per_instance += 1
            else:
                other_resources += 1
        if not resources_per_instance:
            self.report.violations.append(f"{path}: no copy loop over its sliced input")
            return
        bytes_per_instance = looped_bytes + resources_per_instance * per_entry_bytes
        static_bytes = size(template) - looped_bytes
        expanded = static_bytes + batch_size * bytes_per_instance
        resource_count = other_resources + batch_size * resources_per_instance
        max_by_resources = (MAX_RESOURCES - other_resources) // max(resources_per_instance, 1)
        max_batch_size = min(int((MAX_DEPLOYMENT_BYTES - static_bytes) / bytes_per_instance), max_by_resources)
        self.report.batches.append(Batch(path, batch_size, expanded, resource_count, max_batch_size))
        if expanded > BUDGET_BYTES:
            self.report.violations.append(f"{path}: expands to {expanded / MIB:.2f} MiB at a batch size of {batch_size}, above the {BUDGET_BYTES / MIB:.2f} MiB budget")
        if resource_count > MAX_RESOURCES:
            self.report.violations.append(f"{path}: expands to {resource_count} resources at a batch size of {batch_size}, above the limit of {MAX_RESOURCES}")

    def check_batch_parent(self, template: dict, path: str, loop: dict, batch_size: int, unit: str):
        """Estimate how many entries fit before the deployment holding the batches exceeds the budget.

        Each batch instance carries the batch template plus its slice of entries, and the parent
        also receives the full list of entries as a parameter.
        """
        static = size(template) - size(loop)
        per_batch = size(loop) + 2 * batch_size * ENTRY_BYTES
        max_batches = min(max(BUDGET_BYTES - static, 0) // per_batch, MAX_RESOURCES)
        self.report.capacities.append(Capacity(path, unit, max_batches * batch_size, per_batch // batch_size))

    def check_other_loops(self, template: dict, path: str, loops: dict):
        """Estimate how many instances of the copy loops over the same array fit in the budget.

        loops maps the array a group of copy loops iterates over to the loop resources; every
        instance adds one copy of each loop resource.
        """
        for array, group in loops.items():
            per_instance = sum(size(resource) for resource in group)
            static = size(template) - per_instance
            max_instances = min(max(BUDGET_BYTES - static, 0) // per_instance, MAX_RESOURCES // len(group))
            names = ", ".join(sorted({label(resource) for resource in group}))
            self.report.capacities.append(Capacity(f"{path} > [{names}]", array, max_instances, per_instance))

    def walk(self, template: dict, path: str, params: dict, sliced_params: dict):
        """params holds the int values of this template's parameters that could be resolved."""
        self.check_static(template, path)
        if sliced_params:
            self.check_batch(template, path, sliced_params)
        scope = Scope(template, params)
        other_loops = {}
        for deployment in nested_deployments(template):
            child = deployment["properties"]["template"]
            child_path = f"{path} > {label(deployment)}"
            child_params = {}
            child_sliced = {}
            for name in deployment["properties"].get("parameters", {}):
                expression = param_expression(deployment, name)
                value = scope.resolve(expression)
                if value is not None:
                    child_params[name] = value
                batch_size = scope.batch_size(expression)
                passed_through = PARAM_REF.match(expression) if isinstance(expression, str) else None
                if passed_through and passed_through.group(1) in sliced_params:
                    batch_size = sliced_params[passed_through.group(1)]
                if batch_size is not None:
                    child_sliced[name] = batch_size
            copy = deployment.get("copy")
            if copy and child_sliced:
                self.check_batch_parent(template, child_path, deployment, max(child_sliced.values()), batch_unit(child_sliced))
            elif copy:
                count = copy.get("count", "")
                over_batch = LENGTH_OF_PARAM.match(count)
                if not (over_batch and over_batch.group(1) in sliced_params):
                    arrays = REFERENCE.findall(count)
                    other_loops.setdefault(arrays[0] if arrays else count, []).append(deployment)
            self.walk(child, child_path, child_params, child_sliced)
        if other_loops:
            self.check_other_loops(template, path, other_loops)


def entry_values(template: dict, use_max: bool = False, overrides: dict = None) -> dict:
    """Int parameters of an entry point at their default, or at their @maxValue when use_max is set."""
    overrides = overrides or {}
    values = {}
    for name, definition in template.get("parameters", {}).items():
        if definition.get("type") != "int" or "defaultValue" not in definition:
            continue
        value = definition.get("maxValue", definition["defaultValue"]) if use_max else definition["defaultValue"]
        values[name] = int(overrides.get(name, value))
    return values


def analyze(template: dict, values: dict) -> Report:
    checker = Checker()
    checker.walk(template, "root", values, {})
    return checker.report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("templates", nargs="*", help="Bicep or compiled JSON entry points (default: both entry points in the repo root)")
    parser.add_argument("--set", action="append", default=[], metavar="PARAM=VALUE", help="override an entry-point int parameter")
    parser.add_argument("-v", "--verbose", action="store_true", help="print every batch and capacity, not only violations")
    args = parser.parse_args()

    overrides = {}
    for item in args.set:
        name, _, value = item.partition("=")
        if not name or not value.isdigit():
            parser.error(f"--set expects PARAM=INT, got {item!r}")
        overrides[name] = int(value)
    paths = [Path(t) for t in args.templates] or [REPO_ROOT / name for name in DEFAULT_ENTRY_POINTS]
    failed = False
    for path in paths:
        template = compile_template(path)
        values = entry_values(template, overrides=overrides)
        unknown = set(overrides) - set(values)
        if unknown:
            print(f"unknown int parameters for {path.name}: {', '.join(sorted(unknown))}", file=sys.stderr)
            return 2
        report = analyze(template, values)
        batch_params = ", ".join(f"{name}={value}" for name, value in sorted(values.items()) if "batch" in name.lower())
        print(f"== {path.name} ({batch_params})")
        if args.verbose:
            for batch in report.batches:
                print(f"  {batch.bytes / MIB:6.2f} MiB  {batch.resources:4} resources  batch of {batch.batch_size:<4}  max {batch.max_batch_size:<4}  {batch.path}")
            for capacity in report.capacities:
                print(f"  fits {capacity.count:5} {capacity.unit:<29} {capacity.bytes_per_entry / 1024:6.1f} KiB each  {capacity.path}")
        for violation in report.violations:
            print(f"  FAIL {violation}")
        if not report.batches:
            print("  FAIL no batch deployments found; the batch size expressions may have changed")
            failed = True
        elif not report.violations:
            print(f"  OK: {len(report.batches)} batch deployments within limits")
        failed = failed or bool(report.violations)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
