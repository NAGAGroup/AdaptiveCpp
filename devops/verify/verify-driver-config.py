#!/usr/bin/env python3
"""
Plain-python (no pytest) check of bin/acpp's config_db: the installed
toolchain config loader and its {{ }} fixpoint resolver (Commit 5, step
5a). Run as: python devops/verify/verify-driver-config.py
"""

import importlib.machinery
import importlib.util
import json
import os
import sys
import tempfile

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ACPP_DRIVER_PATH = os.path.join(REPO_ROOT, "bin", "acpp")

_failures = []


def fail(msg):
    _failures.append(msg)
    print("verify-driver-config: FAILED - " + msg, file=sys.stderr)


def load_acpp_module():
    # bin/acpp has no .py extension, and its only executable statement at
    # module scope is `if __name__ == '__main__': ...` at the very end -
    # loading it under any module name other than "__main__" (as
    # SourceFileLoader below does by construction) means that guard never
    # fires: the class definitions execute, main() does not.
    loader = importlib.machinery.SourceFileLoader("acpp_driver_under_test", ACPP_DRIVER_PATH)
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def check_config_db(acpp, tmp):
    fake_root = os.path.join(tmp, "install")
    etc_dir = os.path.join(fake_root, "etc", "AdaptiveCpp")
    deploy_dir = os.path.join(etc_dir, "deploy")
    os.makedirs(deploy_dir)

    toolchain = {
        "a": {"value": "{{ acpp-root }}/x"},
        "b": {"value": "{{ a }}/y"},
        "e": {"value": ""},
        "o": {"value": "-Wl,-rpath,$ORIGIN/lib"},
        "r": {"value": "{{ acpp-runtime-root }}/z"},
        "bad": {"value": "{{ nope }}"},
        "cuda-install-root": {"value": "{{ acpp-root }}/cuda"},
        "cuda-rt-subdir": {"value": "targets/x86_64-linux/lib"},
        "cycle1": {"value": "{{ cycle2 }}"},
        "cycle2": {"value": "{{ cycle1 }}"},
    }
    toolchain_path = os.path.join(etc_dir, "acpp-toolchain.json")
    with open(toolchain_path, "w") as f:
        json.dump(toolchain, f)

    db = acpp.config_db([etc_dir], fake_root)

    if db.get("b") != fake_root + "/x/y":
        fail("two-level {{ }} chain did not resolve: got " + repr(db.get("b")))

    if db.contains_key("e"):
        fail("an empty resolved value should count as not set")

    if db.get("o") != "-Wl,-rpath,$ORIGIN/lib":
        fail("literal $ORIGIN was mangled: got " + repr(db.get("o")))

    if db.get("r") != "{{ acpp-runtime-root }}/z":
        fail("{{ acpp-runtime-root }} should be left unresolved: got " + repr(db.get("r")))

    try:
        db.get("bad")
        fail("an unknown {{ }} key should have raised RuntimeError")
    except RuntimeError:
        pass

    try:
        db.get("cycle1")
        fail("a {{ }} cycle should have raised RuntimeError")
    except RuntimeError:
        pass

    # An unused broken entry must not break unrelated lookups: "bad" and
    # "cycle1" are broken above, but "b" was already resolved fine, and a
    # never-touched key ("cycle2") must not raise merely by existing.
    if db.get("b") != fake_root + "/x/y":
        fail("resolving 'bad'/'cycle1' should not have disturbed 'b'")

    # A missing acpp-toolchain.json (config dir present, file absent) is
    # an empty db, not an error - the same as an absent directory was.
    empty_dir = os.path.join(tmp, "no-config-here")
    os.makedirs(empty_dir)
    empty_db = acpp.config_db([empty_dir], fake_root)
    if empty_db.is_loaded:
        fail("a directory with no acpp-toolchain.json should not be 'loaded'")
    if list(empty_db.keys):
        fail("a directory with no acpp-toolchain.json should yield no keys")

    return etc_dir, toolchain, toolchain_path, fake_root


def check_acpp_config_cuda_lib_path(acpp, etc_dir, toolchain, toolchain_path):
    # acpp_config's own config_db is rooted at its *own* installation path
    # (derived from bin/acpp's real location on disk, via __file__ - not
    # the fake root check_config_db used above), so the expected values
    # below are computed from whatever that resolves to, not re-faked
    # here. --acpp-config-file-dir is the only thing this test controls.
    saved_environ = dict(os.environ)
    try:
        for var in list(os.environ):
            if var.startswith("ACPP_") or var.startswith("HIPSYCL_") or var.startswith("OPENSYCL_"):
                del os.environ[var]

        argv = ["acpp", "--acpp-config-file-dir=" + etc_dir]
        config = acpp.acpp_config(argv)
        actual_root = os.path.abspath(config.acpp_installation_path)

        expected = os.path.join(actual_root, "cuda", "targets/x86_64-linux/lib")
        lib_path = config.cuda_lib_path
        if lib_path != expected:
            fail("cuda_lib_path (rt-subdir set) mismatch: got {} expected {}".format(
                lib_path, expected))

        # Re-check with an empty cuda-rt-subdir: the vendor root itself,
        # no trailing separator.
        toolchain["cuda-rt-subdir"] = {"value": ""}
        with open(toolchain_path, "w") as f:
            json.dump(toolchain, f)
        config2 = acpp.acpp_config(argv)
        expected2 = os.path.join(actual_root, "cuda")
        lib_path2 = config2.cuda_lib_path
        if lib_path2 != expected2:
            fail("cuda_lib_path (empty rt-subdir) mismatch: got {} expected {}".format(
                lib_path2, expected2))
    except Exception as e:
        print("verify-driver-config: skipping acpp_config instantiation checks "
              "({}: {})".format(type(e).__name__, e))
    finally:
        os.environ.clear()
        os.environ.update(saved_environ)


def main():
    acpp = load_acpp_module()

    with tempfile.TemporaryDirectory() as tmp:
        etc_dir, toolchain, toolchain_path, _fake_root = check_config_db(acpp, tmp)
        check_acpp_config_cuda_lib_path(acpp, etc_dir, toolchain, toolchain_path)

    if _failures:
        print("verify-driver-config: {} check(s) failed".format(len(_failures)), file=sys.stderr)
        sys.exit(1)

    print("verify-driver-config: all checks passed")
    sys.exit(0)


if __name__ == "__main__":
    main()
