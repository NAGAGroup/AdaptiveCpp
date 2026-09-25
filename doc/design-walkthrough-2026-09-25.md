# Design walkthrough, 2026-09-24/25

Status: **current direction, supersedes `configuration-model.md` wherever
they conflict.** This is the record of a step-by-step discussion (Jack and
the agent), not an implementation. Nothing here is implemented yet. Items
marked *open* were not settled.

The walkthrough followed one case, CUDA + OMP on Linux, in toolchain mode,
under the full strategy, with the generic flow, stage by stage (configure,
toolchain config, manifest, install, driving, deploying, running). It ended
in a simplification that replaces most of the strategy model.

## Principles

1. **What we build, we install.** Every strategy, both build modes. That is
   just build-and-install.
2. **A toolchain we do not build** (plugin mode only: LLVM, clang,
   llc/opt/lld, cpu-cxx and their runtime libraries) is the system's. We
   never install or deploy it.
3. **OMP is the asterisk.** In toolchain mode libomp is ours (principle 1).
   Its location is wherever LLVM installs it, and LLVM's libomp is the
   default, because the toolchain-mode product must work out of the box
   with only what we ship. In plugin mode it is an ordinary vendor library.
   A downstream swap to GOMP is the user's business.
4. **We are toolchain maintainers, not packagers.** Set sensible defaults
   that work end to end. Do not design for every downstream choice.
   Downstream can change anything; that is on them.
5. **Deploying is driving** (`acpp --acpp-deploy` is part of the driver).
6. **Linked vs consumed.** Linked things (shared libraries) are the
   loader's business: RUNPATH, the loader's search, patchelf. Consumed
   things (files the runtime opens by path: libdevice, bitcode, llc/opt
   executables) are read from the application configuration.

## The simplification: two strategies

We had been over-engineering: forcing rpath and layout decisions in every
strategy is a CMake anti-pattern. Outside full, ACPP is an ordinary CMake
project, and whoever configures it sets rpaths etc. with standard CMake
variables, as for any project.

| | managed (default) | full / full-permissive-only |
|---|---|---|
| Meaning | Ordinary CMake project | We take responsibility for vendor assets |
| Ours linking ours | `$ORIGIN`-relative (good practice; overridable like any project) | `$ORIGIN`-relative |
| Linked vendor libraries, plugin-mode LLVM | However the configurer arranges it (loader search, their own CMake rpath settings, conda's patchelf). We force nothing. | Per-vendor install rules copy the vendor into the tree; our backends get `$ORIGIN` rpaths into `<vendor-subdir>/<rt-subdir>` |
| Manifests | **Do not exist** | Exist and are used |
| Deploy helper | **Not available.** A driver cannot deploy what was not built for deployment. | Available |
| Nonpermissive gate | n/a | `ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN`; full with the gate off is a configure error (EULA). full-permissive-only skips nonpermissive vendors and needs no gate. |

Gone as concepts: `default`, the absolute-vs-relative strategy distinction,
the "system"/"relocatable" flavours, `default-strategy-app-cfg-dir`, the
`runtime-configurable` row flag, per-app application-config names, and the
XDG/system/lib-relative config search.

*To confirm:* running `acpp --acpp-deploy` against a managed toolchain is a
clear error ("deployment requires a full-strategy toolchain").

## Application configuration

- **One per runtime copy.** It lives in `etc/AdaptiveCpp` at a fixed offset
  from the ACPP runtime library. The runtime locates itself and reads it.
  No embedded app name, no identity translation unit, no symbol lookup, no
  XDG/system search. The environment still overrides any entry.
- **Different application configs sharing one tree are unsupported.** The
  filesystem nearly enforces it (one runtime library per tree).
- **One constant shape.** Values are relative to `ACPP_RT_LIB_DIR`, the
  directory holding the runtime library (the runtime is what reads the
  config). A value may also be absolute, for consumed files outside our
  tree: e.g. a plugin-mode LLVM tool, or libdevice from a system CUDA under
  managed.
- **A template filled by CMake at install.** It is generated at `cmake
  --install`, beside the installed runtime, in every strategy. It is
  overridable at install (the conda case), and a user may reasonably edit
  it after install (not something we design for).
- **Under full, deploy copies it like any other file** into the deploy
  tree, beside the deployed runtime. It means the same thing there because
  the runtime is deployed with it. Rule: absent → copy; present and
  identical → skip; present and different → fail.
- Because application-config values no longer live in manifest rows (the
  manifest only exists under full), the `app-config` manifest section is
  replaced by this template.

## Per stage (the CUDA + OMP case)

**Configure.** In toolchain mode LLVM, clang, llc, opt, lld, libLLVM and
libomp are ours, not discovered. CUDA uses `find_package(CUDAToolkit)` for
the root, the version and the relative facts (rt, include, bin, libdevice).
Nobody chooses a vendor's internal layout. Configure fails without
libdevice. nvc++ belongs to the separate nvhpc unit. **A found vendor is
enabled**: support is built in, which does not imply installed or
deployed. Packager knobs: discovery hints, the strategy, and (full only)
one install subdir per vendor, default `lib/hipSYCL/ext/<vendor>`.

**Installed toolchain config.** It holds every fact the driver needs,
deploying included; anything a manifest template resolves against lives
here. One merged toolchain config (plus, under full, one merged manifest)
in `etc/AdaptiveCpp`. The environment overrides entries. The strategy key
stays, as the default the driver deploys with: we assume the build
strategy is the deploy strategy (no install/deploy matrix), though a toolchain
user may change it.

**Manifest (full only).** Scoped per backend. The installed manifest is the
merge of the manifests for enabled backends, filtered to the build mode
(plugin mode has no LLVM rows). Each backend's manifest holds ours (e.g.
the CUDA backend, llvm-to-ptx, the PTX bitcode) and the vendor's (cudart,
libdevice). Headers, ptxas and fatbinary are never manifest rows; they are
toolchain-only and live in the CUDA install rule. `ACPP_CLANG` and
`ACPP_CLANG_INCLUDE_PATH` belong to HIP (hiprtc JIT), not core. That move
is still unfinished in the tree.

**Install (full).** Ours, plus the whole LLVM build in toolchain mode.
CUDA's install rule copies into `<acpp-root>/<cuda-subdir>` in the
toolkit's own layout: cudart with its symlink chain, libdevice, headers
(leaning: the whole include directory, since it is only text; not deeply
considered), ptxas, fatbinary. The deploy tree mirrors the install tree.

**Driving.** The driver finds its config at a fixed offset. In the generic
flow nothing CUDA-specific happens at compile or link time; cudart is
reached at run time through our CUDA backend. `cuda-link-line` is
driver-time and used only by the CUDA multipass flows (explicit,
integrated, nvcxx). **The CLI driver never adds rpaths by itself**:
someone driving acpp by hand owns their link. CMake users should get the
right rpaths automatically from `add_sycl_to_target`. The mechanism under
the two-strategy model is *open* (one idea discussed: bake the rpath into
the installed CMake package as an overridable cache variable).

## Open

- The `add_sycl_to_target` rpath mechanism under full (see above).
- The deploy-helper-under-managed error (to confirm).
- Whether the whole CUDA include directory is installed under full.
- Rewriting `configuration-model.md` and `source-obligations.md` to this
  model, and deciding what of the current tree (the four-strategy options
  code, the install-root/subdir machinery, the app-config manifest
  sections, the goldens) survives.
