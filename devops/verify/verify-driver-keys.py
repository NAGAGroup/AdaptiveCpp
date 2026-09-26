#!/usr/bin/env python3
"""
Plain-python (no pytest) check that every config key bin/acpp reads is
defined in config/*.json on every platform/arch it applies to (Slice S1,
step 4): guards the driver (reader) and config/ (writer) against drifting
apart - a key the driver reads but no config/*.json defines on some
platform/arch either needs a config entry there, or belongs in one of the
two exemption lists below. Run as:
  python devops/verify/verify-driver-keys.py
"""

import json
import os
import re
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ACPP_DRIVER_PATH = os.path.join(REPO_ROOT, "bin", "acpp")
CONFIG_ROOT = os.path.join(REPO_ROOT, "config")

PLATFORMS = ["linux", "windows", "macos"]

# (i) Command-line/environment-only keys with a code fallback in bin/acpp:
# never required in config/*.json on any platform/arch. Names are the
# post-rename (no "default-" prefix) config-field names bin/acpp's
# options/flags dicts actually use.
OPTIONAL_KEYS = {
    "platform",
    "gpu-arch",
    "cuda-lib-path",
    "rocm-lib-path",
    "config-file-dir",
    "deploy",
    "is-dryrun-only-std-flags",
    "is-stdpar",
    "is-stdpar-system-usm",
    "is-stdpar-mqs",
    "is-stdpar-unconditional-offload",
    "stdpar-prefetch-mode",
    "export-all",
    "no-warn-legacy-flows",
    "pcuda",
    "pcuda-chevron-launch",
}

# (ii) Backend-scoped key prefixes: a key with one of these prefixes is
# required only on a platform/arch where that backend's own unit file
# (config/common/<unit>.json, config/<platform>/common/<unit>.json or
# config/<platform>/<arch>/<unit>.json) exists at some tier.
BACKEND_PREFIXES = {
    "cuda-": "cuda",
    "hip-": "hip",
    "nvcxx": "nvhpc",
    "ocl-": "ocl",
    "ze-": "ze",
    "vk-": "vk",
    "clspv": "clspv",
}

_failures = []


def fail(msg):
    _failures.append(msg)
    print("verify-driver-keys: FAILED - " + msg, file=sys.stderr)


def extract_driver_read_keys(text):
    """3rd positional literal argument of every option(...) call, plus
    every string literal passed to config_db/_config_db's
    .get/.get_or_default/.contains_key (same regex approach used by
    /tmp/acpp-keyaudit.py's key audit). Returns {key: [line, ...]}."""
    keys = {}

    def add(key, pos):
        ln = text.count("\n", 0, pos) + 1
        keys.setdefault(key, []).append(ln)

    option_re = re.compile(
        r'(?<![\w.])option\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"([^"]+)"')
    for m in option_re.finditer(text):
        add(m.group(3), m.start())

    method_re = re.compile(
        r'(?:self\._config_db|_config_db|config\.config_db|config_db)\.'
        r'(get_or_default|get|contains_key)\(\s*"([^"]+)"')
    for m in method_re.finditer(text):
        add(m.group(2), m.start())

    return keys


def classify_json(path):
    """config/common/<unit>.json -> ("ROOT", "common", unit)
    config/<platform>/common/<unit>.json -> (platform, "common", unit)
    config/<platform>/<arch>/<unit>.json -> (platform, arch, unit)"""
    rel = os.path.relpath(path, CONFIG_ROOT)
    parts = rel.split(os.sep)
    if parts[0] == "common":
        return ("ROOT", "common", parts[1][:-5])
    if parts[0] in PLATFORMS:
        if parts[1] == "common":
            return (parts[0], "common", parts[2][:-5])
        return (parts[0], parts[1], parts[2][:-5])
    return None


def collect_config_tree():
    """{(platform-or-ROOT, tier, unit): set(keys)}, excluding deploy/ and
    app/ (deploy manifests and application-config fragments are a
    different key namespace, not the toolchain config bin/acpp reads)."""
    tier_info = {}
    for root, dirs, files in os.walk(CONFIG_ROOT):
        dirs[:] = [d for d in dirs if d not in ("deploy", "app")]
        for fname in sorted(files):
            if not fname.endswith(".json"):
                continue
            full = os.path.join(root, fname)
            cls = classify_json(full)
            if cls is None:
                continue
            with open(full) as f:
                data = json.load(f)
            tier_info.setdefault(cls, set()).update(data.keys())
    return tier_info


def discover_arches(platform):
    pdir = os.path.join(CONFIG_ROOT, platform)
    if not os.path.isdir(pdir):
        return []
    return sorted(
        d for d in os.listdir(pdir)
        if d != "common" and os.path.isdir(os.path.join(pdir, d))
    )


def unit_exists(tier_info, platform, arch, unit):
    for (p, tier, u) in tier_info:
        if u != unit:
            continue
        if p == "ROOT" or (p == platform and tier in ("common", arch)):
            return True
    return False


def union_keys(tier_info, platform, arch):
    result = set()
    for (p, tier, unit), keyset in tier_info.items():
        if p == "ROOT" or (p == platform and tier in ("common", arch)):
            result.update(keyset)
    return result


def backend_unit_for(key):
    for prefix, unit in BACKEND_PREFIXES.items():
        if key.startswith(prefix):
            return unit
    return None


def main():
    with open(ACPP_DRIVER_PATH) as f:
        driver_text = f.read()

    driver_keys = extract_driver_read_keys(driver_text)
    tier_info = collect_config_tree()

    combos = []
    for platform in PLATFORMS:
        for arch in discover_arches(platform):
            combos.append((platform, arch))

    combo_keys = {c: union_keys(tier_info, *c) for c in combos}
    combo_labels = ["{}/{}".format(p, a) for p, a in combos]

    rows = []
    for key in sorted(driver_keys.keys()):
        status = {}
        if key in OPTIONAL_KEYS:
            for combo in combos:
                status[combo] = "optional"
            rows.append((key, status))
            continue

        backend_unit = backend_unit_for(key)
        for combo in combos:
            platform, arch = combo
            if backend_unit is not None and not unit_exists(tier_info, platform, arch, backend_unit):
                status[combo] = "n/a ({})".format(backend_unit)
                continue
            if key in combo_keys[combo]:
                status[combo] = "ok"
            else:
                status[combo] = "MISSING"
                fail("{} is missing on {}/{} (read at bin/acpp:{})".format(
                    key, platform, arch,
                    ",".join(str(l) for l in driver_keys[key])))
        rows.append((key, status))

    key_width = max([len("config key")] + [len(k) for k, _ in rows])
    col_width = max([len(l) for l in combo_labels] + [7])
    header = "{:<{kw}} | {}".format(
        "config key", " | ".join(l.ljust(col_width) for l in combo_labels),
        kw=key_width)
    print(header)
    print("-" * len(header))
    for key, status in rows:
        cells = " | ".join(status[c].ljust(col_width) for c in combos)
        print("{:<{kw}} | {}".format(key, cells, kw=key_width))

    if _failures:
        print("verify-driver-keys: {} check(s) failed".format(len(_failures)), file=sys.stderr)
        sys.exit(1)

    print("verify-driver-keys: all checks passed ({} driver-read keys, {} platform/arch combos)".format(
        len(driver_keys), len(combos)))
    sys.exit(0)


if __name__ == "__main__":
    main()
