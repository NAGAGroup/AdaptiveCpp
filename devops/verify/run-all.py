#!/usr/bin/env python3
"""Runs every devops/verify harness. The fork is verified by these cmake -P
and python harnesses, not by local builds; real builds run in acpp-toolchain
CI."""
import glob
import os
import subprocess
import sys

VERIFY_DIR = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(VERIFY_DIR, "..", ".."))
SELF = os.path.basename(__file__)

filters = sys.argv[1:]


def wanted(name):
    if not filters:
        return True
    return any(f in name for f in filters)


py_harnesses = []
for f in sorted(glob.glob(os.path.join(VERIFY_DIR, "*.py"))):
    base = os.path.basename(f)
    if base == SELF:
        continue
    if wanted(base):
        py_harnesses.append(base)

cmake_harnesses = []
for f in sorted(glob.glob(os.path.join(VERIFY_DIR, "*.cmake"))):
    base = os.path.basename(f)
    if base.endswith("-inner.cmake") or base.endswith("-lib.cmake"):
        continue
    if wanted(base):
        cmake_harnesses.append(base)

results = []

for py in py_harnesses:
    path = os.path.join(VERIFY_DIR, py)
    proc = subprocess.run([sys.executable, path], cwd=REPO,
                           capture_output=True, text=True)
    results.append((py, proc.returncode, proc.stdout, proc.stderr))

for cm in cmake_harnesses:
    path = os.path.join(VERIFY_DIR, cm)
    proc = subprocess.run(["cmake", "-P", path], cwd=REPO,
                           capture_output=True, text=True)
    results.append((cm, proc.returncode, proc.stdout, proc.stderr))

for name, rc, out, err in results:
    status = "PASS" if rc == 0 else "FAIL"
    print("{:<45} {} (exit {})".format(name, status, rc))

failures = [r for r in results if r[1] != 0]

if failures:
    print("\n--- FAILURE DETAILS ---")
    for name, rc, out, err in failures:
        print("\n### {} (exit {})".format(name, rc))
        print("--- stdout ---")
        print(out)
        print("--- stderr ---")
        print(err)

print("{} / {} harnesses passed".format(len(results) - len(failures), len(results)))

sys.exit(1 if failures else 0)
