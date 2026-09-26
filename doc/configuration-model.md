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
