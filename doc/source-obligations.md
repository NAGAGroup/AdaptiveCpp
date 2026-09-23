# Source obligations the configuration model creates

Each vendor slice appends its rows here as work lands.

## Compile-definition macros

| macro | cmake definition site | C++ consumer | reads configuration today? | configuration entry | disposition |
|---|---|---|---|---|---|
| `ACPP_LLC_PATH` | `src/compiler/CMakeLists.txt:62` | `Utils.cpp:76` (`getLLCPath`) | no — reads the macro | `llc` | replace with config read |
| `ACPP_LLD_PATH` | `src/compiler/CMakeLists.txt:63` | `Utils.cpp:94` (`getLLDPath`) | no — reads the macro | `lld` | replace with config read |
| `ACPP_OPT_PATH` | `src/compiler/CMakeLists.txt:64` | `Utils.cpp:112` (`getOptPath`) | no — reads the macro | `opt` | replace with config read |
| `ACPP_LLC_NAME` | `src/compiler/CMakeLists.txt:66` | `Utils.cpp:71` | no — reads the macro | `llc` (exe entry) | replace with config read |
| `ACPP_LLD_NAME` | `src/compiler/CMakeLists.txt:65` | `Utils.cpp:89` | no — reads the macro | `lld` (exe entry) | replace with config read |
| `ACPP_OPT_NAME` | `src/compiler/CMakeLists.txt:67` | `Utils.cpp:107` | no — reads the macro | `opt` (exe entry) | replace with config read |
| `ACPP_CLANG_PATH` | `src/compiler/llvm-to-backend/CMakeLists.txt:170` | `Utils.cpp:59` (`getClangPath`) | no — reads the macro | `device-clang-cmplr` | replace with config read |
| `ROCM_CLANG_VERSION_MAJOR`/`MINOR`/`PATCH` | `src/compiler/CMakeLists.txt:259` | `PipelineBuilder.cpp:57-58`, `Frontend.hpp:91,569,640,752`, `SMCPCompatPass.cpp:23` — all `#if defined(ROCM_CLANG_VERSION_MAJOR) && ... == N` | no — read only by the preprocessor | none | becomes a discovery export read at configure, not a config entry: every consumer is an `#if` guard selecting which code the plugin compiles, so the value can never be a runtime read; the root's own version probe (`CMakeLists.txt:388-395`, the `execute_process`/regex pair) duplicates `cmake/discovery.cmake`'s ROCm detection instead of feeding it — centralize there |
| `ACPP_LLC_HOST_CPU_FLAG` | `src/compiler/llvm-to-backend/CMakeLists.txt:302` | `LLVMToHost.cpp:313` | no — reads the macro | `jit-host-llc-cpu-flag` → `ACPP_JIT_HOST_LLC_CPU_FLAG` | replace with config read; duplicates the entry already declared |
| `ACPP_OPT_HOST_CPU_FLAG` | `src/compiler/llvm-to-backend/CMakeLists.txt:303` | `LLVMToHost.cpp:314` | no — reads the macro | `jit-host-opt-cpu-flag` → `ACPP_JIT_HOST_OPT_CPU_FLAG` | replace with config read; entry already exists |
| `ACPP_LLC_ADDITIONAL_FLAGS` | `src/compiler/llvm-to-backend/CMakeLists.txt:304` | `LLVMToHost.cpp:512` | no — reads the macro | `jit-host-llc-flags` → `ACPP_JIT_HOST_LLC_FLAGS` | replace with config read; entry already exists |
| `ACPP_OPT_ADDITIONAL_FLAGS` | `src/compiler/llvm-to-backend/CMakeLists.txt:305` | `LLVMToHost.cpp:513` | no — reads the macro | `jit-host-opt-flags` → `ACPP_JIT_HOST_OPT_FLAGS` | replace with config read; entry already exists — found in the same `target_compile_definitions` block as the three above, not separately named when this obligation was raised |
| `ACPP_CUDA_DEVICE_LIBS_PATH` | (deleted) | `LLVMToPtx.cpp` | yes — `try_retrieve_settings_variable("cuda_libdevice_dir")` | `cuda-libdevice-dir` → `ACPP_CUDA_LIBDEVICE_DIR` | **done** |
| `ACPP_ROCM_DEVICE_LIBS_PATH` | (deleted) | `LLVMToAmdgpu.cpp` | yes — `try_retrieve_settings_variable("hip_device_libs_dir")` | `hip-device-libs-dir` → `ACPP_HIP_DEVICE_LIBS_DIR` | **done** |
| `ACPP_HIPCC_PATH` | (deleted) | (deleted: `getRocmClang`/`getCommandOutput` had no callers since upstream `377178f0`) | n/a | n/a | **done** (dead code) |
| `HIPSYCL_CLSPV_PATH` | (deleted) | `LLVMToCLSPV.cpp` | yes — `try_retrieve_settings_variable("clspv")` | `clspv` → `ACPP_CLSPV` | **done** |
| `HIPSYCL_LLVMSPIRV_NAME` | `src/compiler/llvm-to-backend/CMakeLists.txt:257` | `LLVMToSpirv.cpp:328` | no — raw macro | `llvm-spirv` → `ACPP_LLVMSPIRV` | replace with a config read of the `llvmspirv` entry |
| `HIPSYCL_RELATIVE_LLVMSPIRV_PATH` | `src/compiler/llvm-to-backend/CMakeLists.txt:258` | `LLVMToSpirv.cpp:328`, alongside `HIPSYCL_LLVMSPIRV_NAME` | no — raw macro | `llvm-spirv` → `ACPP_LLVMSPIRV` | replace with a config read of the `llvmspirv` entry — `llvm-spirv` is now an owned config entry (`config/common/core.json:101-109`; `acpp_declare_owned_resource(LLVMSPIRV ...)` in each platform's `core.cmake`), so both rows collapse to the same read |
| `LIB_NUMA_AVAILABLE` | `src/runtime/CMakeLists.txt:414` | `omp_allocator.cpp:14,30,58,121,159,169` | n/a — gates code | stays | stays, gates code |
| `ACPP_HIPRTC_LINK` | `src/compiler/llvm-to-backend/CMakeLists.txt:302` | `LLVMToAmdgpu.cpp` | n/a — gates code | stays | stays |

### Done: vector-math conversion

| macro (deleted) | C++ consumer | reads configuration today? | configuration entry |
|---|---|---|---|
| `SLEEF_AVAILABLE` | `Utils.cpp`, `LLVMToHost.cpp` | yes — `try_retrieve_settings_variable("sleef_dir")` | `sleef-dir` → `ACPP_SLEEF_DIR` |
| `AMATH_AVAILABLE` | `Utils.cpp`, `LLVMToHost.cpp` | yes — `try_retrieve_settings_variable("amath_dir")` | `amath-dir` → `ACPP_AMATH_DIR` |
| `SVML_AVAILABLE` | `Utils.cpp`, `LLVMToHost.cpp` | yes — `try_retrieve_settings_variable("svml_dir")` | `svml-dir` → `ACPP_SVML_DIR` |
| `LIBMVEC_AVAILABLE` | `Utils.cpp`, `LLVMToHost.cpp` | yes — `dlopen`/`dlinfo` lookup | n/a (glibc, loader resolves) |

## Non-macro obligations

### bin/acpp (the Python driver)

`bin/acpp` reads installed configuration with 35 keys using the `default-`
prefix (e.g., `"default-clang"`, `"default-cuda-path"`). The configuration
model says keys carry no prefix.

The driver expands `$ACPP_PATH` via a two-pass substitution dictionary (lines
760, 768, 775). The configuration model says resolution is to a fixpoint using
`{{ key }}` syntax; no `{{ }}` resolver exists in the driver.

The driver hardcodes `"lib"` in four places:
- `bin/acpp:761` — `os.path.join(self.acpp_installation_path, "lib")`
- `bin/acpp:769` — same
- `bin/acpp:775` — same
- `bin/acpp:985` — `os.path.join(self.acpp_installation_path, "lib", "hipSYCL")`

The configuration model says `acpp-libdir` is a fact from
`@CMAKE_INSTALL_LIBDIR@`; the driver should read it from the configuration.

### settings.cpp (the runtime's configuration singleton)

`src/common/settings.cpp` implements `settings_config_file`, a global
singleton that reads `acpp-config.cfg` (a flat `key=value` text file) beside
the library found via `dladdr`. This is upstream's mechanism. The application
configuration discovery mechanism described in `doc/configuration-model.md` is
not implemented; the exported-symbol lookup, the padded-field rewriting, the
XDG search order, and the one-per-process semantics do not exist.

### The driver's fixpoint resolver

The `{{ key }}` fixpoint resolver described in the configuration model does
not exist in the Python driver. The driver reads values and expands
`$ACPP_PATH` by string substitution only; it does not resolve
`{{ }}` references between entries.

### Install rpaths that hardcode lib

Six `INSTALL_RPATH`/`CMAKE_INSTALL_RPATH` sites exist under `src/`. `${base}`
is set once, in `src/CMakeLists.txt:9,12`, to `$ORIGIN` (non-Apple) or
`@loader_path` (Apple) — the loader-relative token itself carries no layout
assumption. Two sites build on it without naming a libdir:

- `src/runtime/CMakeLists.txt:23` — `${base} ${base}/hipSYCL`
- `src/runtime/CMakeLists.txt:121` — `${base}/../ ${base}/llvm-to-backend`
- `src/compiler/llvm-to-backend/CMakeLists.txt:7` — `${base} ${base}/../../`

Four do, identically, by hardcoding `lib`:

- `src/tools/acpp-info/CMakeLists.txt:18`
- `src/tools/acpp-hcf-tool/CMakeLists.txt:11`
- `src/tools/acpp-appdb-tool/CMakeLists.txt:14`
- `src/tools/acpp-pcuda-pp/CMakeLists.txt:12`

all `set_target_properties(<tool> PROPERTIES INSTALL_RPATH ${base}/../lib/)`.
Each carries a comment calling this "the same rpath idiom as the other
tools" — it is the same bug in four places, not an idiom: on a `lib64`
layout the tool's RUNPATH points at a directory `acpp-rt` was never
installed into. Obligation: derive the segment from `CMAKE_INSTALL_LIBDIR`
relative to `CMAKE_INSTALL_BINDIR`, the same fact `acpp-libdir` already
carries into the configuration schema, so the four tools stop being a
second, unsynchronized copy of it.

### The global configuration installation

The obligation that raised this named the variable
`ACPP_CONFIG_FILE_GLOBAL_INSTALLATION`; no such identifier exists in the
tree. The real variable is `ACPP_CONFIG_FILE_INSTALL_DIR`
(`CMakeLists.txt:560`), set to the relative subpath `etc/AdaptiveCpp` —
joined under the install prefix, read the same way by `bin/acpp:658`.
Nothing in the tree installs it, or anything else, to a literal absolute
`/etc/AdaptiveCpp` outside a prefix; grepping for that exact string finds
only `doc/configuration-model.md`'s "File search order" (the deployed
application's own config search, a different mechanism from the
toolchain's `etc/AdaptiveCpp`), where `/etc/AdaptiveCpp/app-cfgs/` is
already tier 2 of 3 — the system tier, below the user's
`$XDG_CONFIG_HOME` tier and above the dladdr-relative fallback.

So as literally named, the obligation's premise does not hold: the
toolchain's own configuration directory is prefix-relative today, and the
one genuinely absolute `/etc/AdaptiveCpp` path in the tree is a documented
tier of a search order that already resolves the conflict for the one
mechanism — application-configuration discovery — that uses an absolute
system directory at all. What is still open: whether
`ACPP_CONFIG_FILE_INSTALL_DIR` should ever gain a second,
non-prefix-relative install site for the toolchain's own configuration — a
system-package scenario, one toolchain per machine, `/etc/AdaptiveCpp`
outside any single prefix — the same two shapes the obligation posed
(remove the possibility outright and keep this prefix-relative only, or
extend the existing search order's system tier to also serve toolchain
configuration lookup, not just app-cfg). Needs Jack's ruling on which, and
on whether a conflict is there to resolve at all.

### Wiring-slice obligations left by the CUDA slice

- Root `CMakeLists.txt`: `find_package(CUDA QUIET)` (line ~127) and the
  `CUDA_DEVICE_LIBS_PATH` block (~lines 518-532) still run in the root
  and duplicate what `cmake/discovery/cuda.cmake` now handles.
- `cmake/FindCUDA.cmake`: upstream's shim; delete when the root's
  `find_package(CUDA)` is removed.
- `src/runtime/CMakeLists.txt`: `rt-backend-cuda` links via `CUDA::cudart`
  `CUDA::cuda_driver` and carries a RUNPATH entry that the wiring derives
  from `{{ cuda-deploy-path }}/{{ cuda-libdir }}`.
- `bin/acpp` lines ~1038-1044: `cuda_lib_path` property hardcodes a
  `lib64` fallback; reads `default-cuda-lib-path`.
- `cmake/adaptivecpp-config.cmake.in`: `ACPP_CUDA_PATH` stays (user-facing
  cmake export).
- `bin/acpp` cuda_nvcxx_invocation: reads `nvcxx` and `nvcxx-link-line`
  (today it reuses `cuda-link-line`, which carries clang flags nvc++ does
  not want, and the driver prepends `-cuda` itself).
- The deploy engine's `"*"` copies every file in the directory including
  static archives; a shared-library-only pattern is an engine obligation.

### Wiring-slice obligations left by the HIP slice

- Root `CMakeLists.txt`: `find_package(HIP)` with the hipcc fallback and
  `ROCM_PATH` reassignment to `/opt/rocm` (~lines 214-226); the
  `USE_ROCM_LLVM` and ROCm clang version block (~368-420); the
  `ROCM_DEVICE_LIBS_PATH` block (~481-489); the `find_library` block for
  amdhip64, hsa-runtime64, amd_comgr, hsakmt, rocprofiler-register
  (~495-510); `ROCM_LIBS` and the `ROCM_LINK_LINE`/`ROCM_CXX_FLAGS`
  cache variables.
- `src/runtime/CMakeLists.txt`: `rt-backend-hip` keeps `hip::host` and
  gains the derived RUNPATH entry to
  `{{ hip-deploy-path }}/{{ hip-libdir }}`.
- `bin/acpp` ~1051-1055: `rocm_lib_path` property hardcodes `"lib"`
  fallback; reads the entry.
- `cmake/adaptivecpp-config.cmake.in`: `ACPP_ROCM_PATH` stays.

### Wiring-slice obligations left by the OpenCL slice

- Root `CMakeLists.txt`: `find_package(OpenCL QUIET)` at ~205-211 moves
  into `discovery/ocl.cmake` behind the `WITH_SSCP_COMPILER` gate with a
  2.1 minimum, a deliberate departure: upstream PR 1778 showed that
  without it macOS finds Apple's 1.2 `OpenCL.framework` and
  `rt-backend-ocl` fails to link (`clCreateProgramWithIL`,
  `clCreateCommandQueueWithProperties`, the SVM entry points), which is
  why upstream's macOS CI passes `-DWITH_OPENCL_BACKEND=OFF`; with the
  floor the framework is simply not found. The `WITH_OPENCL_BACKEND`
  default from `OpenCL_FOUND` at ~235-243 becomes
  `ACPP_DISCOVERED_OCL_FOUND`.
- `src/runtime/CMakeLists.txt`: the `FetchContent` blocks for
  `ocl-headers` and `ocl-cxx-headers` move to `cmake/fetch.cmake`, which
  runs after discovery and only when OpenCL was found or the backend is
  forced on; the `ocl-headers` and `ocl-cxx-headers` INTERFACE targets
  are created there from `ACPP_FETCHED_OCL_HEADERS_DIR` and
  `ACPP_FETCHED_OCL_CXX_HEADERS_DIR`. `rt-backend-ocl` keeps linking
  `${OpenCL_LIBRARIES}` (not a loader variable of our own) and gains the
  derived RUNPATH entry to `{{ ocl-deploy-path }}/{{ ocl-libdir }}`.
- Deploy engine: `SHARED_LIB:<name>` resolves to `lib<name>.so` and the
  engine follows the symlink chain, so the dev symlink must exist in the
  source directory, which is the same thing `find_package(OpenCL)` needs
  at configure; a loader-only system carrying just `libOpenCL.so.1` needs
  the engine to accept a soname when the dev symlink is absent.
- A macOS user with a real ICD loader (for example PoCL through the
  Khronos loader) points `OpenCL_LIBRARY` and `OpenCL_INCLUDE_DIR` at it,
  since CMake searches frameworks first.

### Wiring-slice obligations left by the Level Zero slice

- Root `CMakeLists.txt` ~526-532: the `find_library(ACPP_ZE_LOADER_LIBRARY
  NAMES ze_loader REQUIRED)` block and its comment naming
  `ACPP_ZE_LIB_PATH` and a vendor-asset gate that no longer exist are
  replaced by `discovery/ze.cmake`.
- `WITH_LEVEL_ZERO_BACKEND` defaults from `ACPP_DISCOVERED_ZE_FOUND`, on
  only when discovery found the loader and
  `ACPP_COMPILER_FEATURE_PROFILE` is neither `none` nor `minimal`,
  matching the root's gate that forces SSCP for OpenCL or Level Zero
  (f2600750 `CMakeLists.txt` 294-298). Upstream links `-lze_loader` by
  hand (Level Zero ships no CMake package) and never gave the backend a
  default; the `REQUIRED` `find_library` came from this branch
  (`a33fbb1f`, a Windows link fix), not from upstream.
- `src/runtime/CMakeLists.txt`: `rt-backend-ze` adds
  `target_include_directories(PRIVATE ${ACPP_DISCOVERED_ZE_INCLUDE_DIR})`
  and the derived RUNPATH entry to
  `{{ ze-deploy-path }}/{{ ze-libdir }}`.
- `bin/acpp` `available_components` gains `"ze"` and the OpenCL deploy
  note gets a Level Zero sibling (loader only; the driver is the user's).
- `doc/install-spirv.md`: the `-DWITH_LEVEL_ZERO_BACKEND=ON` sentence
  becomes "found automatically".

### Wiring-slice obligations left by the OMP slice

- Root `CMakeLists.txt` ~562-570 (`DEFAULT_OMP_FLAG`), ~693-743 (the
  `OMP_LINK_LINE` cache variable and its platform branches; the
  `SEQUENTIAL_*` siblings are already core's) and ~762-764
  (`OMP_CXX_FLAGS`) are replaced by core: the options now live in each
  platform's `cmake/options/<platform>/common/core.cmake`, not a vendor
  file, because upstream's CPU backend is unconditionally built.
- `bin/acpp`'s `default-omp-link-line` and `default-omp-cxx-flags` reads
  fall under the general `default-` prefix row above.

### Wiring-slice obligations left by the linux/aarch64 slice

- Root `CMakeLists.txt` ~576-672: the vector math selection (the arch-gated
  `find_library` calls and `DEFAULT_VEC_MATH_LIB`) is replaced by
  discovery's unconditional finds plus the per-arch options file.
- The wiring slice must select `cmake/options/<platform>/<arch>` and
  `config/<platform>/<arch>` from `CMAKE_SYSTEM_NAME` and
  `CMAKE_SYSTEM_PROCESSOR` with the mapping: `x86_64|AMD64` → `x86_64`,
  `aarch64|arm64|ARM64` → `aarch64`, `Linux` → `linux`, `Darwin` →
  `macos`, `Windows` → `windows`.

### Wiring-slice obligations left by the windows/x86_64 slice

- `backend_loader.cpp`: adds `AddDllDirectory` for every
  `ACPP_*_DLL_DIR` present in the application configuration before
  loading backends.
- Deploy engine: `files` entries are template-expanded like `src` and
  `dest`, so `"SHARED_LIB:cudart64_{{ cuda-version-major }}"` resolves
  at deploy time.
- `cmake/discovery/ocl.cmake` and `ze.cmake`: the `WIN32` branches
  (`find_file` for the DLL, `ACPP_DISCOVERED_*_BINDIR`) are exercised
  only on a Windows configure.
- `cmake/discovery.cmake`: `ACPP_DISCOVERED_LIBOMP_DIR` must be the
  DLL directory on Windows (LLVM's bin), not the import-lib directory;
  the plugin-discovery half must `FATAL_ERROR` on Windows (linked-only).
- `bin/acpp`: `acpp_plugin_path` reads `plugin-path` and `cuda_lib_path`
  reads `cuda-lib-path`; the hardcoded `lib/x64` fallback goes.

### Wiring-slice obligations left by the windows/aarch64 slice

- The CUDA unit on Windows on Arm assumes toolkit 13.4+ (the first with
  Windows on Arm support) and assumes the `cudart64_<major>` DLL naming
  on arm64; both are to be verified against a real install before the
  compatibility set.

### Wiring-slice obligations left by the macos/arm64 slice

- Root `CMakeLists.txt`: `WITH_METAL_BACKEND` defaults from
  `ACPP_DISCOVERED_METAL_FOUND`.
- `src/runtime/CMakeLists.txt` ~449-475: the `find_path(METAL_INCLUDE_DIR)`
  block is replaced by `discovery/metal.cmake`; `rt-backend-metal` takes
  `target_include_directories(PRIVATE ${ACPP_DISCOVERED_METAL_INCLUDE_DIR})`.
- `doc/install-metal.md`: says "found automatically";
  `-DMETAL_INCLUDE_DIR=...` as override.
- `WITH_OPENCL_BACKEND` is OFF on macOS by discovery.

### Wiring-slice obligations left by the Vulkan slice

- Root `CMakeLists.txt` ~244: `WITH_VULKAN_BACKEND` default stays `OFF`
  (reason recorded; discovery runs regardless and the flip is one line
  later).
- Root ~250-252 `find_package(Vulkan)` and ~534-539 `find_program(clspv)`
  are replaced by `discovery/vk.cmake` and `discovery/clspv.cmake`.
- `src/runtime/CMakeLists.txt`: `rt-backend-vk` links
  `${ACPP_DISCOVERED_VK_LOADER}` and
  `${ACPP_DISCOVERED_VK_SPIRV_TOOLS_LIBRARY}`, includes
  `${ACPP_DISCOVERED_VK_INCLUDE_DIR}`, gains the derived RUNPATH entry to
  `{{ vk-deploy-path }}/{{ vk-libdir }}`.
- Nightly check: `rt-backend-vk`'s `DT_NEEDED` must omit `SPIRV-Tools`
  (it is a static archive, build-only).
- `bin/acpp` `available_components` gains `"vk"`.
- Deploy engine note: `clspv`'s own shared dependencies, if any, are a
  nightly question.
- `rt-backend-vk` on Windows links the import library and reaches the
  machine's `vulkan-1.dll`; no `AddDllDirectory` entry.
- Deploy-engine question: whether to write `MoltenVK_icd.json` beside a
  copied `libMoltenVK.dylib` on macOS.

### Wiring-slice obligations left by the common slice

- The wiring selects `<platform>/<arch>` by the recorded mapping and
  includes `cmake/options/<platform>/<arch>/<file>.cmake` for core and
  each found flow.
- It merges `config` fragments and `deploy` fragments per the model's
  merge section into one installed file per flow: `config/common/`,
  `config/<platform>/common/`, `config/<platform>/<arch>/` in that order;
  a duplicate key is a configure error.
- `devops/verify/golden` is the reference the merge must reproduce.

### Wiring-slice obligations left by the ownership rule

- The deploy engine filters manifest rows by `"build-mode"` at configure
  time against `LLVM_ADAPTIVECPP_LINK_INTO_TOOLS`: a row tagged
  `"toolchain"` or `"plugin"` is dropped when the build is the other
  mode; a row carrying no `build-mode` key applies in both. This is the
  same absence-based rule the merge already uses for a flow whose
  dependencies were not found - here the axis is build mode instead of
  discovery.
- The `llvm` category deploys in every strategy when it is present at
  all (rule 1: it exists only in toolchain mode, and is unconditional
  there); `internal` already deploys under `default` too, and needs no
  new obligation - it always has.
- RUNPATH wiring follows ownership, not strategy: our own binaries carry
  a `$ORIGIN`/`@loader_path`-relative RUNPATH to each other in every
  strategy; in plugin mode, the link to `libLLVM` (or the equivalent
  machine library) is absolute, because nothing of the machine's LLVM is
  deployed; a vendor's RUNPATH is absolute under `default` and relative
  otherwise, from its own `*_DEPLOY_PATH`.
- Upstream's own core deployment manifest (the `libLLVM`, `llc`/`opt`/
  `lld`, `omp` and `gomp` rows built into its deploy-manifest generation)
  is replaced by this fork's manifest, not merged with it: a plugin build
  here installs none of those rows, by rule 2, where upstream's would.

### Obligations on the deploy engine

- The final deploy manifest is one merge of core's manifest and every
  enabled vendor's manifest.
- A configuration key duplicated across files is an error, matching the
  configuration merge's rule.
- Identical manifest rows collapse to one: the SPIR-V bitcode row is
  identical between the `ocl` and `ze` manifests, and the engine must not
  copy it twice.

### Wiring-slice obligations left by the manifest split

Not done in this pass — wiring work, not documentation. Recorded here as
what the split still owes.

- **Per-vendor cmake install rules, not yet written.** Each vendor needs
  an install rule, below the prolog, following `ACPP_DEPLOYMENT_STRATEGY`,
  that installs two things under the full strategies: (a) the
  toolchain-only assets its multipass flow needs to drive, and (b) the
  same assets its manifest already deploys with an app. (a) and (b) are
  **defined separately and kept in sync by a harness, not derived from
  each other** — the install rule is a package-time decision about what
  physically sits in the toolchain, the manifest is drive-time
  configuration a downstream user may edit (swap libomp for GOMP,
  repoint a vendor path), and packaging must never read something a user
  is allowed to change.
- **The `"toolchain-only": true` groups move to those install rules and
  leave the manifests.** Not done in this pass — the harnesses still
  depend on them being present, and moving them is exactly the wiring
  work this section defers. Today's inventory, by grep:
  - `config/windows/common/deploy/cuda.json` — three rows: CUDA's C++
    headers (`cuda-include-path`, `"*"`), the import library
    (`cuda-lib-path`, `cudart.lib`), and the nvcc-adjacent tools a
    multipass build drives (`cuda-bin-path`, `ptxas.exe`/`fatbinary.exe`).
  - `config/linux/common/deploy/cuda.json` — two rows: the same headers,
    and the same tools (`ptxas`/`fatbinary`); no import-library row,
    Linux has no equivalent.
  - `config/linux/common/deploy/hip.json` — one row: HIP's own headers
    (`hip-include-path`, `"*"`).
  - Each has an identical copy in its golden(s) under
    `devops/verify/golden/`; no macOS manifest carries the flag (no
    CUDA or HIP backend there).
- **A new harness is owed**: for each vendor, every manifest row deployed
  under the full strategies must have a matching cmake install rule (b,
  above) — the sync check the corrected ruling requires, not yet
  written. It fails independently of whether the manifest was hand-edited
  correctly; that is the point of keeping the two definitions apart.
