# The configuration model

This document is the authority on how the fork's toolchain configuration,
deployment manifest and vendor libraries work: what is always installed,
what a strategy governs, the three files a build installs into
`etc/AdaptiveCpp`, how a deployed application finds its libraries and its
consumed files, and how `acpp --acpp-deploy` populates a deployment tree.
Source code that contradicts this document has a defect; this document
does not compromise to match the source.

## Ownership

Three kinds of asset, and only one of them is a strategy's business.

**What we build (rule 1)** is installed in every strategy, both build
modes - that is just build-and-install. In toolchain mode this is LLVM
itself (`llc`/`opt`/`ld.lld`, `libLLVM` where a dylib is built), the
AdaptiveCpp runtime and its compiler plugin, and `llvm-spirv`
(AdaptiveCpp's own fork of the SPIRV-LLVM-Translator, built and installed
under `lib/hipSYCL/ext/llvm-spirv/bin` in both modes). There is no
separate knob for any of it: it follows cmake's own install directories
under the install prefix directly, unconditional on
`ACPP_DEPLOYMENT_STRATEGY`.

**A toolchain we do not build (rule 2)** exists only in plugin mode: LLVM,
`libLLVM`, `clang`, `llc`/`opt`/`lld`, and `cpu-cxx`
(`CMAKE_CXX_COMPILER`, the bootstrap compiler) are the system's. None of
it is ever installed or deployed, and no strategy changes that; the
driver and the JIT both reach the machine's own copy through a discovered
absolute path, empty and not an error when discovery found no plugin to
build against.

**Vendors (rule 3) are the only thing a strategy governs.** CUDA, the HPC
SDK runtime (`nvhpc`), HIP, the OpenCL and Level Zero loaders, Vulkan,
`clspv`, libnuma, SLEEF/AMATH/SVML, and libomp are all vendor units -
assets AdaptiveCpp never builds, in either build mode.
`ACPP_DEPLOYMENT_STRATEGY` decides, per unit, whether it ships with the
toolchain; nothing else about the tree depends on the strategy at all.

**OMP is an ordinary vendor, in both build modes.** The OpenMP runtime
the OMP backend links, and that applications link too under the `omp.*`
flavours, is a vendor unit exactly like CUDA: its own subdirectory knob,
governed by the strategy, permissive. The build mode changes only the
*default source* - `ACPP_LIBOMP_SOURCE_DIR` - not whether it is a vendor
unit at all:

- In toolchain mode, the libomp belonging to the LLVM this build produces
  (`${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}`) - guaranteed to
  exist, since the toolchain must work with only what it ships.
- In plugin mode, whatever `find_package(OpenMP)` found for the compiler
  AdaptiveCpp itself was built with (`ACPP_DISCOVERED_LIBOMP_DIR`).

`ACPP_LIBOMP_NAME` (default `omp`) is the short name a link line or the
JIT composes with a directory; discovery cannot choose between libomp and
GOMP, so a packager who wants GOMP (ABI-compatible) points
`ACPP_LIBOMP_SOURCE_DIR` at it directly and sets `ACPP_LIBOMP_NAME=gomp`.
In toolchain mode, when libomp is *not* shipped, its driver-facing
install-root value is still the deploy-layout placeholder rather than
today's absolute build prefix (it is still ours, just not copied into the
vendor subdir) - one of the few places ownership and shipped-ness
interact instead of being independent axes.

## The two strategies

`ACPP_DEPLOYMENT_STRATEGY` is `managed` (the default), `full`, or
`full-permissive-only`.

**`managed`** is the ordinary-CMake-project case: nothing is shipped, and
whoever configures the toolchain (or a project consuming it) sets rpaths
and search paths with standard CMake variables, like any other project.
Forcing a layout decision in every strategy was the anti-pattern this
replaced.

**`full` and `full-permissive-only`** are where the toolchain takes
responsibility for vendor assets: `cmake --install` copies them into the
tree, our backends get `$ORIGIN`/`@loader_path` rpaths that reach them,
and `acpp --acpp-deploy` becomes available. They differ only in which
vendors that covers.

**Permissive** means redistributable without an EULA opt-in (permissive
or weak-copyleft licensing, dynamically linked - e.g. libnuma under
LGPL). **Nonpermissive** means it requires an EULA opt-in (CUDA, the HPC
SDK). Every vendor unit declares its category once, at
`acpp_declare_vendor(<STEM> <lower> permissive|nonpermissive)`.

**The gate**, `ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN` (default
`OFF`), is the redistribution decision: copying a nonpermissive vendor
into the toolchain's own tree obligates whoever ships that toolchain to
have read its terms and to pass the obligation on to their own users.
`full` with the gate off is a configure-time `FATAL_ERROR` naming the
vendor and pointing at the gate; `full-permissive-only` never needs it -
a self-contained toolchain that only wants what needs no legal decision
should not have to make one.

**The per-vendor shipped rule** (`ACPP_<STEM>_SHIPPED`, set once by
`acpp_declare_vendor`) is exactly this:

| strategy | permissive vendor | nonpermissive vendor |
|---|---|---|
| `managed` | not shipped | not shipped |
| `full-permissive-only` | shipped | not shipped |
| `full` | shipped | shipped (gate must be `ON`) |

Not shipped means the vendor's values are the discovered absolute
location, and the driver, the JIT and the loader all reach the machine's
own copy; shipped means the vendor is copied under `ACPP_<STEM>_SUBDIR`
and every value that names it becomes relative to the toolchain (or, once
deployed, the runtime library's own directory) instead. See "Linked vs
consumed".

## Packager knobs

A vendor unit gets exactly three knobs, and nothing else - there is no
per-resource `-D` override of anything a vendor's own discovery or
category already settled:

1. **Discovery hints** - the find's own variables (`CUDAToolkit_ROOT`,
   `LLVM_DIR`, `OpenCL_LIBRARY`, `WITH_*_BACKEND`). These belong to
   discovery, not to the options layer, and are never named again once
   discovery has run.
2. **The strategy** (`ACPP_DEPLOYMENT_STRATEGY`) and **the gate**
   (`ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN`) - matrix-wide, not
   per-vendor.
3. **`ACPP_<VENDOR>_SUBDIR`**, a pure subdirectory with no root in it,
   resolved at configure time like `CMAKE_INSTALL_LIBDIR` itself - never
   deferred to a `{{ }}` placeholder. Default
   `<CMAKE_INSTALL_LIBDIR>/hipSYCL/ext/<lower>`
   (`<CMAKE_INSTALL_BINDIR>`-based on Windows); an explicitly empty
   string installs the vendor straight at the install root, for a
   packager whose own layout already scopes it. Meaningful only for a
   shipped vendor, since an unshipped one is never copied anywhere.

OMP gets two more, described above: `ACPP_LIBOMP_SOURCE_DIR` and
`ACPP_LIBOMP_NAME`. Nothing else is a packager knob - once discovery, the
strategy, the gate, and (for a shipped vendor) its subdirectory have run,
every other value a vendor exports is derived.

**Conda-packaged CUDA, worked through.** A conda environment installs the
CUDA toolkit at its own environment prefix, with the runtime libraries
under `targets/x86_64-linux/lib` rather than a toolkit's own top-level
`lib64`. Discovery still finds it exactly as it would anywhere else:
`CUDAToolkit_LIBRARY_DIR`, `CUDAToolkit_BIN_DIR` and the include directory
are each search hints, and `ACPP_DISCOVERED_CUDA_PREFIX` is their common
ancestor (`acpp_common_ancestor`, `cmake/discovery/common.cmake`) -
walking up from whichever directories were actually found until one
contains every other, degenerating to `/` for a layout that scatters them
with nothing in common. A packager building into that environment sets
`-DACPP_CUDA_SUBDIR=` to the empty string: the vendor unit installs
straight at the install root under `full`/`full-permissive-only`, because
the conda environment's own layout already scopes it; under `managed`
nothing is copied at all, and the app-config value CUDA gets is simply
the discovered `$PREFIX/targets/x86_64-linux/lib`, unaffected by any of
this - conda's own prefix rewriting (or a value written relative to
`ACPP_RT_LIB_DIR` instead) carries it through relocation.

## The three installed files

Every build writes three files into `etc/AdaptiveCpp` inside the install
prefix (`cmake/acpp-installed-configs.cmake`'s
`acpp_generate_installed_configs`), which `cmake --install` then copies
there via ordinary `install(FILES ...)` rules.

**`acpp-toolchain.json`** holds every fact the driver needs to drive
compilation, in every strategy - deploying included, since
`acpp --acpp-deploy` is part of the driver (see "Deploying"). Each entry
is `{"value": "...", "envvar": "..."}`; `envvar`'s absence means the
entry is a fact nothing could override. A value may still carry
unresolved `{{ entry-key }}` tokens the driver resolves later, to a
fixpoint, against this same file - plus `{{ acpp-root }}`, the
toolchain's own root, found by the driver from its own location and
never written into the file itself.

**`acpp-app.cfg`** is a flat `KEY=value` file - no `{{ }}`, no `@`, every
value already concrete - generated by `configure_file(@ONLY)` from the
merged `app/<unit>.cfg` fragments at build time. A value is either
`$ACPP_RT_LIB_DIR`-relative (a literal token, expanded only by the C++
runtime at its own run time, never by cmake or the driver) or an absolute
discovered path - exactly the split ownership and shipped-ness already
decide everywhere else. The runtime finds this file itself:
`settings_config_file`'s constructor locates its own library's directory
(`dladdr`/`GetModuleHandle`) and reads `etc/AdaptiveCpp/acpp-app.cfg` at a
fixed relative offset from it, computed once at build time from
`CMAKE_INSTALL_LIBDIR`/`CMAKE_INSTALL_BINDIR` and the config install
directory - never an absolute path baked in. Every setting still checks
the environment first (`ACPP_<NAME>`, or its legacy `HIPSYCL_<NAME>`
spelling) and then upstream's own beside-the-executable files
(`acpp-config.cfg`, `acpp-config-<name>.cfg`), loaded after the installed
app config specifically so they can override it - the same precedence
upstream always had.

**`acpp-deploy.json`** exists only under `full` or `full-permissive-only`
- `managed` ships nothing, so there is nothing for a manifest to say.
Four groups, each a `[{"src", "dest", "files"}, ...]` array: `internal`
(what AdaptiveCpp builds and always deploys), `llvm` (what toolchain mode
builds and deploys; absent entirely in plugin mode),
`external-permissive` and `external-nonpermissive` (vendor assets). A row
may carry `"build-mode": "toolchain"|"plugin"` (kept only when it matches
`LLVM_ADAPTIVECPP_LINK_INTO_TOOLS`) or `"unless": "hiprtc-link"` (dropped
when the build linked hipRTC's own alternative) - both keys are stripped
from whatever rows survive, so the installed file never carries them.
There is no `app-config` group any more: every value that used to live in
one is in `acpp-app.cfg` instead.

**Generation.** Each kind (`config`, `deploy`, `app`) has its own
fragments, one file per vendor unit per tier -
`config/common/<unit>.json` → `config/<platform>/common/<unit>.json` →
`config/<platform>/<arch>/<unit>.json`, and the same shape under
`deploy/` and `app/`. `acpp_merge_units` (`cmake/acpp-config-merge.cmake`)
merges every enabled unit's tiers - `config` objects key-wise (a
duplicate key anywhere is a configure error), `deploy` arrays by
concatenating each group and collapsing a row that arrived identical from
more than one unit (the SPIR-V bitcode row OpenCL and Level Zero both
carry, for instance), `app` text line-wise (a duplicate key is also an
error). `acpp_generate_installed_configs` then filters the deploy
manifest by `build-mode`/`unless`, writes the merged text through a
throwaway `.in` file, and `configure_file(@ONLY)`s it - core and `omp`
are always included, alongside whichever vendor units the build enabled.

**Two checks run before any of the three files is trusted.** First,
every `@VAR@` the merged config and app templates reference must already
be a defined cmake variable - `configure_file` would otherwise silently
write empty, indistinguishable from a legitimately empty value and far
harder to diagnose. Second, every `{{ key }}` left in the generated
toolchain config or manifest must be `acpp-root`, `acpp-runtime-root`, or
a key the generated config itself defines - an unresolved key of any
other shape is a configure error, not something that reaches the driver
or the deploy step as literal text. The generated app config is checked
separately, for the shapes it must never contain at all: no `{{ }}` (an
app-config fragment never had one) and no leftover `@` (everything was
resolved by `configure_file` above, or generation already failed at the
first check).

## Linked vs consumed

**Linked** things are shared libraries the loader resolves through
`DT_NEEDED`/RUNPATH (Linux/macOS) or the DLL search path (Windows) - the
loader's business, never a path our own code opens. **Consumed** things
are files the runtime or the JIT opens by path - libdevice, device
bitcode, `llc`/`opt`, a vendor's own headers under a multipass flow -
read from `acpp-app.cfg`.

**RUNPATH follows shipped-ness.** Our own binaries carry an `$ORIGIN`
(`@loader_path` on macOS) RUNPATH to each other in every strategy -
`src/CMakeLists.txt` sets the base, `src/runtime/CMakeLists.txt` and
`src/compiler/llvm-to-backend/CMakeLists.txt` set it per directory. A
backend that links a shipped vendor gets one more entry, computed by
`acpp_add_vendor_rpaths` (`cmake/acpp-vendor-rpath.cmake`) from that
vendor's own subdir and fact - `rt-backend-cuda` gets `CUDA:RT`,
`rt-backend-hip` gets `HIP:RT` and `HIP:SYSDEPS`, `rt-backend-ze` gets
`ZE:RT`, `rt-backend-vk` gets `VK:RT`, `rt-backend-ocl` gets `OCL:RT`,
`rt-backend-omp` gets `LIBOMP` and `LIBNUMA`, `llvm-to-amdgpu` gets
`HIP:RT` - each a no-op unless that vendor is `SHIPPED`
(`acpp_vendor_rpath_entry` returns empty, and appending an empty string
to `INSTALL_RPATH` is a no-op) and unless the target even exists (a
disabled backend). Not shipped means nothing is appended: the loader
resolves the dependency itself, through whatever search the packager or
the machine already provides.

**Consumed files travel through `acpp-app.cfg`.** Each vendor subdir fact
gets an `ACPP_APP_<STEM>_<X>_DIR` value - `$ACPP_RT_LIB_DIR`-relative
when shipped (the concrete relative path from the runtime library's own
install directory, computed once at configure time), the discovered
absolute location otherwise - baked into the app config by
`configure_file`, read by the runtime or the JIT through
`try_retrieve_settings_variable`.

**Windows has no RUNPATH.** A shipped vendor's DLL directory reaches the
loader instead through `AddDllDirectory`, fed from an app-config row -
`ACPP_<VENDOR>_DLL_DIR` (`cuda_dll_dir`, `ocl_dll_dir`, `ze_dll_dir`,
`libomp_dll_dir`) - registered by `backend_loader.cpp` before any backend
plugin (and the vendor DLLs it transitively loads) is opened.
`dylib_loader.cpp`'s `LoadLibraryExA` call passes
`LOAD_LIBRARY_SEARCH_DEFAULT_DIRS`, which is what makes an
`AddDllDirectory`-registered directory part of the search at all -
without it, only the process's own default search order would apply. A
vendor not shipped means no `ACPP_<VENDOR>_DLL_DIR` row exists, and the
loader falls back to `PATH`.

**macOS** uses `@loader_path` everywhere `$ORIGIN` appears on Linux, both
in our own binaries' RUNPATH and in a vendor's rpath entry
(`acpp_vendor_rpath_entry` branches on `APPLE`).

## Vendor install rules under full

Under `full` or `full-permissive-only`, a shipped vendor is copied at
`cmake --install` time by `cmake/acpp-vendor-install.cmake`'s three
helpers - `acpp_install_vendor_libs` (named shared libraries, whole
symlink chain preserved via `FOLLOW_SYMLINK_CHAIN`),
`acpp_install_vendor_files` (plain `FILES`/executable `PROGRAMS`),
`acpp_install_vendor_dir` (a whole directory's contents) - every one a
no-op unless `ACPP_<STEM>_SHIPPED`. The calls live in
`cmake/install/<platform>/common/<unit>.cmake` (plus
`cmake/install/<platform>/<arch>/core.cmake` for core, since SVML is an
x86_64-only arch delta on Linux), written by hand rather than derived
from the deploy manifest: the manifest is drive-time configuration a
downstream toolchain user is allowed to edit (swap libomp for GOMP,
repoint a vendor path), and packaging must never derive from something a
user can change.

**A vendor's install file lists both kinds of thing.** Toolchain-only
pieces the manifest never deploys - needed to drive compilation, not
opened by a running application - and everything the manifest also
deploys with an application. The toolchain-only pieces, as things stand:
CUDA's whole include tree and its `ptxas`/`fatbinary` tools (both
platforms), Windows CUDA's `cudart.lib` import library, and HIP's whole
include tree (needed only by the generic `clangJitLink` path when hipRTC
is not linked). Everything else an install file names - CUDA's
`libcudart`/`cudart64_<major>.dll` and `libdevice.10.bc`, HIP's seven
runtime libraries plus its `rocm_sysdeps` and device-bitcode directories,
the HPC SDK's whole `REDIST` runtime directory, the OpenCL and Level Zero
loaders, the Vulkan loader (and, on macOS, MoltenVK), `clspv`'s
executable, libomp, and (on Linux) SLEEF/AMATH/libnuma/SVML - is also a
manifest row.

**A symlink chain is preserved, not just the file a name resolves to.**
`acpp_install_vendor_libs`'s resolver (`_acpp_resolve_vendor_lib_files`)
globs every `lib<name>.so*`/`lib<name>*.dylib` in the source directory
(the single `<name>.dll`/`lib<name>.dll` on Windows, which has no chain),
and `file(INSTALL ... FOLLOW_SYMLINK_CHAIN)` copies the whole chain
starting from the shortest name - the unversioned link, the soname link,
the real versioned file - so a shipped library's `DT_NEEDED` soname still
resolves after copying, exactly as it did in the vendor's own tree.

**The sync harness** (`devops/verify/verify-install-sync.cmake`) keeps
the install files and the manifest from silently drifting apart, without
deriving either from the other: it text-parses every
`acpp_install_vendor_*` call and every manifest row, normalizes both
sides' tokens (a manifest's `{{ x-y-subdir }}`/`{{ libomp-name }}` and an
install call's `${ACPP_X_Y_SUBDIR}`/`${ACPP_LIBOMP_NAME}`) to one
canonical form, and requires every row to be covered by a call - deriving
which cmake stem and lowercase name belongs to which unit from the
options files' own `acpp_declare_vendor` calls, not a hand-written table.
An install call no row ever claims is printed, not failed: that is
exactly the toolchain-only list above.

## Driving

The driver (`bin/acpp`) loads `acpp-toolchain.json` from `etc/AdaptiveCpp`
beside its own installation (or `--acpp-config-file-dir`/
`ACPP_CONFIG_FILE_DIR`, for an alternate location) into a `config_db`,
resolving `{{ }}` references recursively - a referenced key is
substituted with its own resolved value, so a chain of any length
resolves in one top-level call, and a cycle is a runtime error naming the
key. Every entry can be overridden: each has a command-line flag and an
environment variable (`option`'s three-way binding: commandline,
environment, config_db key) that both take precedence over the installed
value.

**The CLI driver never adds rpaths by itself.** Someone driving `acpp` by
hand, outside CMake, owns their own link. A multipass backend's link line
therefore carries only `-L`/`-l` - `ACPP_CUDA_LINK_LINE` is
`-L{{ cuda-install-root }}/{{ cuda-rt-subdir }} -lcudart`,
`ACPP_HIP_LINK_LINE` is the same shape for `amdhip64` - and
`ACPP_NVCXX_LINK_LINE` is empty by default: nvc++ links its own way, and
neither an rpath nor an `-Mnorpath` override to suppress one belongs to a
link line the driver contributes on the application's behalf.

**A CMake application gets its rpath from `add_sycl_to_target` instead.**
Under `full`/`full-permissive-only`, the installed CMake package bakes
`ACPP_APP_INSTALL_RPATH` (an overridable cache variable, computed once at
the toolchain's own configure/install time by `acpp_app_install_rpath`) -
`$ORIGIN/../<libdir>` plus one `acpp_vendor_rpath_entry` per vendor
`add_sycl_to_target` covers (`CUDA:RT`, `NVHPC:RT`, `LIBOMP`, each only if
that vendor is even declared and only a non-empty entry) - and appends it
to the target's `INSTALL_RPATH` property. This assumes the executable
installs to `<prefix>/<CMAKE_INSTALL_BINDIR>`, since the deploy tree
mirrors the install tree (see "Deploying"); a project installing its
executables elsewhere overrides the variable itself. Empty, and
appending nothing, under `managed` (an ordinary CMake project's own
rpath choices are none of the toolchain's business) and on Windows (no
RPATH there at all - see "Linked vs consumed").

## Deploying

`acpp --acpp-deploy` only works against a toolchain built `full` or
`full-permissive-only` - against `managed`, or when no `acpp-deploy.json`
was installed at all, `run_deployment` prints the exact message
`acpp: deployment requires a toolchain built with the full or
full-permissive-only strategy` to stderr and exits 1. No partial
behaviour.

**`{{ acpp-runtime-root }}`** is the one token only a deploy invocation
resolves, to the absolute target path it was given
(`os.path.abspath(target_path)`) - every other `{{ }}` in a manifest row
resolves against the installed toolchain config exactly as the driver
would resolve it elsewhere, read fresh at deploy time, so editing the
installed configuration between builds changes deploy behaviour with no
reinstall.

**Which groups deploy** depends on the strategy actually driving the
deployment (the installed `deployment-strategy` value, which a toolchain
user may have changed since the toolchain was built): `internal` and
`llvm` always (rule 1 - what was built is always deployed);
`external-permissive` always; `external-nonpermissive` only when the
strategy is `full` (never under `full-permissive-only`, exactly the
per-vendor shipped rule's own table). Every row in a deployed group is
copied - `SHARED_LIB:<name>` resolves to the platform's shared-library
filename, `*` copies every file in the source directory, anything else
copies by that literal name - and a shared library that is itself a
symlink deploys its whole chain the same way the install step preserved
it. A missing source file or directory is a warning, not a failure:
deployment continues, and every miss is listed at the end.

**The application config copies with its own rule**, separate from the
manifest's rows: absent at the deploy target → copy; present and
byte-identical → skip (`  <src> -> (already present, identical)
<dest>`); present and different → fail loud (`acpp: deployment target
already has an application config that differs from the installed one:
... refusing to overwrite it.`, exit 1) rather than silently keep a stale
one, since a deployed application trusts this file completely and a
stale mismatch is exactly the failure mode worth refusing outright.
Absent at the *install* (no installed configuration directory, or no
`acpp-app.cfg` inside it) is a warning only: deployment still ships
everything else.

**The deploy tree mirrors the install tree.** Every `dest` is
`{{ acpp-runtime-root }}` plus the same relative path a fragment's
`src`/`dest` composes elsewhere (`{{ acpp-libdir }}`, a vendor's own
subdir) - the same layout the toolchain itself has under its own install
prefix, just rooted at the deployment target instead. This is what makes
`add_sycl_to_target`'s `<prefix>/bin`-relative rpath assumption (see
"Driving") correct for a deployed application too, without a separate
deploy-specific rpath computation.

**The component list is ignored.** `--acpp-deploy`'s legacy component
selection (`core`, `all`, or a named component) is accepted for
compatibility only; any other value prints a warning
(`--acpp-deploy's component selection (...) is accepted for compatibility
only; the installed manifest is merged and deployed as a whole.`) and
changes nothing - there is one installed manifest, merged from whichever
units the toolchain build enabled, and it deploys as a whole.

## The per-vendor sweep

Linked means the runtime's own `DT_NEEDED` (or the Windows DLL search);
consumed means opened by path, read from an `acpp-app.cfg` key. Shipped
follows the strategy table under "The two strategies".

| unit | category | linked | consumed (app-config key) | toolchain-only |
|---|---|---|---|---|
| CUDA | nonpermissive | `rt-backend-cuda` → `cudart` (`cudart64_<major>.dll` on Windows) | `libdevice.10.bc` (`ACPP_CUDA_LIBDEVICE_DIR`) | include tree, `ptxas`/`fatbinary`; Windows `cudart.lib` |
| nvhpc | nonpermissive | nothing of ours; a `cuda-nvcxx` app links the HPC SDK `REDIST` runtime itself, through `nvc++` | - | - (whole `REDIST` dir ships; `nvc++` itself is never in the tree) |
| HIP | permissive | `rt-backend-hip` → 7 runtime libs (`amdhip64`, `hsa-runtime64`, `amd_comgr`, `hiprtc`, `hiprtc-builtins`, `rocprofiler-register`, `rocm-core`) + `rocm_sysdeps`; `llvm-to-amdgpu` → `hiprtc` optionally | device bitcode dir (`ACPP_HIP_BITCODE_DIR`) | whole include tree (generic `clangJitLink` path, only when hipRTC not linked) |
| OpenCL | permissive | `rt-backend-ocl` → the ICD loader | - | - (loader-only; the ICD itself is never shipped) |
| Level Zero | permissive | `rt-backend-ze` → `ze_loader` | - | - (loader-only; headers are build-only) |
| Vulkan | permissive | `rt-backend-vk` → the Vulkan loader (+ MoltenVK on macOS) | - | - (nothing ships on Windows at all: `vulkan-1.dll` is the system's) |
| clspv | permissive | not linked - a two-sided executable resource the JIT invokes (`ACPP_TOOLCHAIN_CLSPV`/`ACPP_APP_CLSPV`) | the executable path itself (`ACPP_CLSPV`) | - |
| OMP / libomp | permissive | `rt-backend-omp` → `ACPP_LIBOMP_NAME` (default `omp`); also linked directly into `omp.*`-flavour applications | - | - |
| libnuma | permissive | `rt-backend-omp` → `numa` | - | - |
| sleef / amath | permissive | not linked | host JIT's vector-math directory (`ACPP_SLEEF_DIR`/`ACPP_AMATH_DIR`) | - (found only off x86_64 on Linux; a no-op elsewhere) |
| SVML (+ intlc) | permissive in the tree as it stands | not linked | host JIT's vector-math directory (shares SLEEF/AMATH's app-config shape) | - (x86_64-only; one manifest row and one install call name both `svml` and `intlc`) |
| Metal | n/a - no vendor unit | the system Metal framework, at the runtime's own run time | - | - (`metal-cpp` is a build-only discovery requirement, never a row) |

A short note on SVML's category: the design discussion flagged it as
needing a check against Intel's redistribution terms before
implementation ("svml's category ... is to be checked against Intel's
license during implementation"). The tree as it stands declares it
permissive, the same as every other vendor unit here
(`acpp_declare_vendor(SVML svml permissive)`), with nothing recording
that check having actually happened - described above as the code has
it, not as settled.
