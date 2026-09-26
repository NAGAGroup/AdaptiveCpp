#!/usr/bin/env python3
"""
Plain-python (no pytest) check of bin/acpp's deploy engine: reading the
merged installed manifest (acpp-deploy.json), resolving {{ }} tokens
(including {{ acpp-runtime-root }}) against a deploy target, the
strategy gate, the SHARED_LIB: symlink-chain copy, and the application
config copy/skip/fail rule (Commit 5, step 5b). Run as:
  python devops/verify/verify-driver-deploy.py
"""

import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
import sys
import tempfile

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ACPP_DRIVER_PATH = os.path.join(REPO_ROOT, "bin", "acpp")

_failures = []


def fail(msg):
    _failures.append(msg)
    print("verify-driver-deploy: FAILED - " + msg, file=sys.stderr)


def load_acpp_module():
    # Same approach as verify-driver-config.py: bin/acpp has no .py
    # extension, and its only top-level executable statement is
    # `if __name__ == '__main__':` at the very end - loading it under any
    # module name other than "__main__" means that guard never fires.
    loader = importlib.machinery.SourceFileLoader("acpp_driver_under_test", ACPP_DRIVER_PATH)
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def write_json(path, data):
    with open(path, "w") as f:
        json.dump(data, f)


def build_vendor_tree(tmp):
    """A small fixture tree the deploy manifest's src rows point at -
    entirely under our control, independent of where bin/acpp itself
    lives on disk (acpp-root resolves to the real repo, not this tmp
    tree, since the loaded module's __file__ is the real bin/acpp)."""
    vendor = {}

    internal_dir = os.path.join(tmp, "vendor", "internal")
    os.makedirs(internal_dir)
    with open(os.path.join(internal_dir, "hello.txt"), "w") as f:
        f.write("hello")
    vendor["internal"] = internal_dir

    llvm_dir = os.path.join(tmp, "vendor", "llvm")
    os.makedirs(llvm_dir)
    with open(os.path.join(llvm_dir, "world.txt"), "w") as f:
        f.write("world")
    vendor["llvm"] = llvm_dir

    foo_dir = os.path.join(tmp, "vendor", "foo")
    os.makedirs(foo_dir)
    with open(os.path.join(foo_dir, "libfoo.so.1.2"), "w") as f:
        f.write("sofoo")
    os.symlink("libfoo.so.1.2", os.path.join(foo_dir, "libfoo.so.1"))
    os.symlink("libfoo.so.1", os.path.join(foo_dir, "libfoo.so"))
    vendor["foo"] = foo_dir

    nonpermissive_dir = os.path.join(tmp, "vendor", "nonpermissive")
    os.makedirs(nonpermissive_dir)
    with open(os.path.join(nonpermissive_dir, "secret.txt"), "w") as f:
        f.write("secret")
    vendor["nonpermissive"] = nonpermissive_dir

    # A "*" wildcard row's source directory: a real shared library plus a
    # static archive, a libtool archive and a Windows import library (all
    # link-time only, never loaded at run time) alongside an unrelated
    # bitcode file - only the .so and the .bc should be deployed.
    star_dir = os.path.join(tmp, "vendor", "star")
    os.makedirs(star_dir)
    for name in ("libx.so", "libx.a", "libx.la", "x.lib", "ockl.bc"):
        with open(os.path.join(star_dir, name), "w") as f:
            f.write(name)
    vendor["star"] = star_dir

    return vendor


def write_toolchain(etc_dir, strategy, vendor):
    write_json(os.path.join(etc_dir, "acpp-toolchain.json"), {
        "deployment-strategy": {"value": strategy},
        "internal-src": {"value": vendor["internal"]},
        "llvm-src": {"value": vendor["llvm"]},
        "foo-install-root": {"value": vendor["foo"]},
        "nonpermissive-src": {"value": vendor["nonpermissive"]},
        "star-src": {"value": vendor["star"]},
    })


def write_manifest(etc_dir):
    write_json(os.path.join(etc_dir, "acpp-deploy.json"), {
        "internal": [{
            "src": "{{ internal-src }}",
            "dest": "{{ acpp-runtime-root }}/internal-dest",
            "files": ["hello.txt"],
        }],
        "llvm": [{
            "src": "{{ llvm-src }}",
            "dest": "{{ acpp-runtime-root }}/llvm-dest",
            "files": ["world.txt"],
        }],
        "external-nonpermissive": [{
            "src": "{{ nonpermissive-src }}",
            "dest": "{{ acpp-runtime-root }}/nonpermissive-dest",
            "files": ["secret.txt"],
        }],
        "external-permissive": [
            {
                "src": "{{ foo-install-root }}",
                "dest": "{{ acpp-runtime-root }}/ext/foo",
                "files": ["SHARED_LIB:foo"],
            },
            {
                "src": "{{ star-src }}",
                "dest": "{{ acpp-runtime-root }}/star-dest",
                "files": ["*"],
            },
        ],
    })


def make_config(acpp, etc_dir):
    argv = ["acpp", "--acpp-config-file-dir=" + etc_dir]
    return acpp.acpp_config(argv)


@contextlib.contextmanager
def clean_acpp_environ():
    saved = dict(os.environ)
    try:
        for var in list(os.environ):
            if var.startswith("ACPP_") or var.startswith("HIPSYCL_") or var.startswith("OPENSYCL_"):
                del os.environ[var]
        yield
    finally:
        os.environ.clear()
        os.environ.update(saved)


def check_full_strategy(acpp, tmp, vendor):
    etc_dir = os.path.join(tmp, "full", "etc", "AdaptiveCpp")
    os.makedirs(etc_dir)
    write_toolchain(etc_dir, "full", vendor)
    write_manifest(etc_dir)
    with open(os.path.join(etc_dir, "acpp-app.cfg"), "w") as f:
        f.write("ACPP_LLC=/fake/llc\n")

    target = os.path.join(tmp, "full-target")

    with clean_acpp_environ():
        config = make_config(acpp, etc_dir)
        acpp.run_deployment(config, ["core"], target)

    if not os.path.isfile(os.path.join(target, "internal-dest", "hello.txt")):
        fail("full: internal group did not land")
    elif open(os.path.join(target, "internal-dest", "hello.txt")).read() != "hello":
        fail("full: internal-dest/hello.txt has wrong content")

    if not os.path.isfile(os.path.join(target, "llvm-dest", "world.txt")):
        fail("full: llvm group did not land")

    foo_dir = os.path.join(target, "ext", "foo")
    so = os.path.join(foo_dir, "libfoo.so")
    so1 = os.path.join(foo_dir, "libfoo.so.1")
    so12 = os.path.join(foo_dir, "libfoo.so.1.2")
    if not os.path.isfile(so12) or os.path.islink(so12):
        fail("full: libfoo.so.1.2 (the real file) missing or not a plain file")
    # The engine's so-version discovery flattens every hop to point
    # directly at the fully-resolved real file (unchanged behaviour from
    # before this step) - not a chain of one-hop links.
    if not (os.path.islink(so1) and os.readlink(so1) == "libfoo.so.1.2"):
        fail("full: libfoo.so.1 symlink not preserved")
    if not (os.path.islink(so) and os.readlink(so) == "libfoo.so.1.2"):
        fail("full: libfoo.so symlink not preserved")

    if not os.path.isfile(os.path.join(target, "nonpermissive-dest", "secret.txt")):
        fail("full: external-nonpermissive group should be included under 'full'")

    star_dir = os.path.join(target, "star-dest")
    star_deployed = sorted(os.listdir(star_dir)) if os.path.isdir(star_dir) else []
    if star_deployed != sorted(["libx.so", "ockl.bc"]):
        fail("full: \"*\" row should deploy only libx.so and ockl.bc, skipping .a/.la/.lib, got "+repr(star_deployed))

    app_cfg_target = os.path.join(target, "etc", "AdaptiveCpp", "acpp-app.cfg")
    if not os.path.isfile(app_cfg_target):
        fail("full: application config was not copied")
    elif open(app_cfg_target).read() != "ACPP_LLC=/fake/llc\n":
        fail("full: copied application config has wrong content")

    return config, os.path.abspath(target), app_cfg_target


def check_app_config_skip_and_fail(acpp, config, runtime_root, app_cfg_target):
    # A second, identical deploy must skip silently - no exception.
    try:
        acpp.deploy_app_config(config, runtime_root)
    except SystemExit:
        fail("app-config: a second identical deploy should not fail")

    # A different pre-existing target file must fail with exit 1, naming
    # both files - check by capturing stderr, not just the exit code.
    with open(app_cfg_target, "w") as f:
        f.write("ACPP_LLC=/different/llc\n")

    stderr = io.StringIO()
    try:
        with contextlib.redirect_stderr(stderr):
            acpp.deploy_app_config(config, runtime_root)
        fail("app-config: a differing pre-existing target config should have raised SystemExit")
    except SystemExit as e:
        if e.code != 1:
            fail("app-config: differing-target exit code should be 1, got "+repr(e.code))
        msg = stderr.getvalue()
        if app_cfg_target not in msg:
            fail("app-config: differing-target error should name the target file")
        # Matches deploy_app_config's own lookup: beside whichever
        # acpp-toolchain.json this run actually read (config_dirs[0]), not
        # config.acpp_installation_path - see bin/acpp's own comment.
        install_cfg = os.path.join(config.config_db.config_dirs[0], "acpp-app.cfg")
        if install_cfg not in msg:
            fail("app-config: differing-target error should name the installed file")


def check_permissive_only(acpp, tmp, vendor):
    etc_dir = os.path.join(tmp, "permissive", "etc", "AdaptiveCpp")
    os.makedirs(etc_dir)
    write_toolchain(etc_dir, "full-permissive-only", vendor)
    write_manifest(etc_dir)

    target = os.path.join(tmp, "permissive-target")

    with clean_acpp_environ():
        config = make_config(acpp, etc_dir)
        acpp.run_deployment(config, ["core"], target)

    if not os.path.isfile(os.path.join(target, "internal-dest", "hello.txt")):
        fail("full-permissive-only: internal group should still land")
    if os.path.isfile(os.path.join(target, "nonpermissive-dest", "secret.txt")):
        fail("full-permissive-only: external-nonpermissive group should be skipped")


EXPECTED_ERROR = "acpp: deployment requires a toolchain built with the full or full-permissive-only strategy"


def check_managed_and_missing_manifest(acpp, tmp, vendor):
    # (a) managed strategy, manifest present.
    etc_dir = os.path.join(tmp, "managed", "etc", "AdaptiveCpp")
    os.makedirs(etc_dir)
    write_toolchain(etc_dir, "managed", vendor)
    write_manifest(etc_dir)

    with clean_acpp_environ():
        config = make_config(acpp, etc_dir)
        stderr = io.StringIO()
        try:
            with contextlib.redirect_stderr(stderr):
                acpp.run_deployment(config, ["core"], os.path.join(tmp, "managed-target"))
            fail("managed: run_deployment should have raised SystemExit")
        except SystemExit as e:
            if e.code != 1:
                fail("managed: exit code should be 1, got "+repr(e.code))
            if stderr.getvalue().strip() != EXPECTED_ERROR:
                fail("managed: stderr should be exactly the expected message, got "+repr(stderr.getvalue()))

    # (b) full strategy, but no acpp-deploy.json at all.
    etc_dir2 = os.path.join(tmp, "no-manifest", "etc", "AdaptiveCpp")
    os.makedirs(etc_dir2)
    write_toolchain(etc_dir2, "full", vendor)

    with clean_acpp_environ():
        config2 = make_config(acpp, etc_dir2)
        stderr2 = io.StringIO()
        try:
            with contextlib.redirect_stderr(stderr2):
                acpp.run_deployment(config2, ["core"], os.path.join(tmp, "no-manifest-target"))
            fail("no-manifest: run_deployment should have raised SystemExit")
        except SystemExit as e:
            if e.code != 1:
                fail("no-manifest: exit code should be 1, got "+repr(e.code))
            if stderr2.getvalue().strip() != EXPECTED_ERROR:
                fail("no-manifest: stderr should be exactly the expected message, got "+repr(stderr2.getvalue()))


def main():
    acpp = load_acpp_module()

    with tempfile.TemporaryDirectory() as tmp:
        vendor = build_vendor_tree(tmp)

        config, runtime_root, app_cfg_target = check_full_strategy(acpp, tmp, vendor)
        check_app_config_skip_and_fail(acpp, config, runtime_root, app_cfg_target)
        check_permissive_only(acpp, tmp, vendor)
        check_managed_and_missing_manifest(acpp, tmp, vendor)

    if _failures:
        print("verify-driver-deploy: {} check(s) failed".format(len(_failures)), file=sys.stderr)
        sys.exit(1)

    print("verify-driver-deploy: all checks passed")
    sys.exit(0)


if __name__ == "__main__":
    main()
