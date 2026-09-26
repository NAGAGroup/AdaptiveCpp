# Source obligations the configuration model creates

Each vendor slice appended its rows here as work landed. Most of what this
file used to track is now built: the two-strategy model, the vendor-unit
options, the per-vendor cmake install rules, the deploy manifest and its
sync harness are all in the tree and covered by `devops/verify`, and
`doc/configuration-model.md` describes the result. What is left is what
the tree, read today, still shows as unfinished or unconfirmed.

## Open

- `get_lib_directory()`'s `HIPSYCL_INSTALL_PREFIX` fallback
  (`src/common/filesystem.cpp`, `include/hipSYCL/common/config.hpp.in`)
  resolves to a bare `/lib` today, because `CMakeLists.txt` deliberately
  leaves `ACPP_RECORDED_INSTALL_PREFIX` empty (its own comment explains
  why: naming the build machine's prefix in the binary would be wrong).
  It exists purely as a defensive last resort for a `dladdr`/
  `GetModuleFileName` failure this codebase does not otherwise expect to
  hit. Still unresolved: whether it should ever be given a real value, or
  whether an empty fallback quietly resolving to `/lib` is itself worth a
  guard.
- Root `CMakeLists.txt` still runs its own upstream-style finds alongside
  `cmake/discovery/*.cmake`'s: `find_package(CUDA QUIET)` (:126),
  `find_package(HIP QUIET ...)` plus the `hipcc` fallback (:127,
  :214-226), `find_package(OpenCL QUIET)` (:207, :210),
  `find_package(Vulkan 1.4 ...)` (:251), `find_library(AMDHIP64_LIBRARY/
  HSARUNTIME64_LIBRARY/AMDCOMGR_LIBRARY ...)` (:501-505),
  `find_path(ROCM_DEVICE_LIBS_PATH ...)`/`find_path(CUDA_DEVICE_LIBS_PATH
  ...)` (:478, :512), `find_library(ACPP_ZE_LOADER_LIBRARY NAMES
  ze_loader REQUIRED)` (:528), `find_program(CLSPV_COMPILER NAMES clspv
  REQUIRED)` (:535). The root file's own comment (:680-708) already
  checked every one against `cmake/discovery/*.cmake`: each lands under a
  differently-named variable, so re-finding the same hardware twice is
  redundant, not conflicting - except `ACPP_ZE_LOADER_LIBRARY`, which
  `src/runtime/CMakeLists.txt`'s `target_link_libraries` still reads by
  that exact cache-variable name, on purpose. Deleting the root's copy
  needs repointing that one target, not just the find.
- `WITH_LEVEL_ZERO_BACKEND` and `WITH_METAL_BACKEND` still have no
  discovery-based default (`CMakeLists.txt`:693-696 and :813-815, both
  comments naming this file already) - every other backend flag defaults
  from its own `ACPP_DISCOVERED_*_FOUND`; these two still need an
  explicit `-D` or stay off.
- SVML's redistribution category is unconfirmed against Intel's terms.
  The tree declares it permissive
  (`acpp_declare_vendor(SVML svml permissive)`,
  `cmake/options/linux/x86_64/core.cmake`), the same as every other
  vendor unit here, with nothing recording that the terms were actually
  checked (`doc/configuration-model.md`'s "The per-vendor sweep" carries
  the same note).
- The nvcxx flow's own link-line entry is declared but unread. `nvcxx-
  link-line`/`ACPP_NVCXX_LINK_LINE` exists in the toolchain config schema
  (`config/linux/common/nvhpc.json`, written by
  `cmake/options/linux/common/nvhpc.cmake`), but `bin/acpp` has no
  `nvcxx-link-line` option entry, and `cuda_nvcxx_invocation` still reads
  `config.cuda_link_line` (the CUDA multipass backend's own line) for its
  linker args instead - the driver needs the option added and the class
  repointed.
- The four tool `INSTALL_RPATH` sites that hardcode `lib` instead of
  deriving it from `CMAKE_INSTALL_LIBDIR` are unchanged:
  `src/tools/acpp-info/CMakeLists.txt`:18,
  `src/tools/acpp-hcf-tool/CMakeLists.txt`:11,
  `src/tools/acpp-appdb-tool/CMakeLists.txt`:14,
  `src/tools/acpp-pcuda-pp/CMakeLists.txt`:12 all read
  `${base}/../lib/`; on a `lib64` layout `acpp-rt` was never installed
  there.
- `bin/acpp` still carries 17 `"default-"`-prefixed configuration keys,
  all for options outside the vendor-unit model (`platform`, `gpu-arch`,
  the `cuda-lib-path`/`rocm-lib-path` fallbacks, `config-file-dir`,
  `deploy`, the `stdpar-*` flags, `is-export-all`,
  `pcuda`/`pcuda-chevron-launch`, `no-warn-legacy-flows`), and three
  places (`_get_rocm_substitution_vars`, `_get_cuda_substitution_vars`,
  `_get_omp_substitution_vars`) still hardcode `"lib"` for the legacy
  `$ACPP_LIB_PATH` substitution dictionary. None of this sits inside the
  vendor-unit model commits 1-7 touched.
- The deploy engine's `"*"` entry copies every file in a source
  directory, including a static archive if one happens to be there -
  `config/linux/common/deploy/nvhpc.json`'s sole row uses `"*"` to ship
  the HPC SDK's whole `REDIST` runtime tree, which is exactly the shape
  this would matter for. A shared-library-only filter is still an
  engine obligation, not implemented.
- Whether `ACPP_CONFIG_FILE_INSTALL_DIR` should ever gain a second,
  non-prefix-relative install site (a system-package scenario, one
  toolchain per machine, `/etc/AdaptiveCpp` outside any single prefix) is
  Jack's call, not a code question - the toolchain's own configuration
  directory is prefix-relative today and nothing in the tree installs it
  anywhere else.
- Windows CI still has to cover what a Linux harness runner cannot: every
  `devops/verify/verify-windows-*.cmake` pre-sets `ACPP_<VENDOR>_SUBDIR`
  before including a vendor's options file, so `acpp_declare_vendor`'s
  own `WIN32` default branch is never exercised by `cmake -P` on Linux.
- CUDA on Windows on Arm assumes toolkit 13.4+ and the
  `cudart64_<major>` DLL naming on arm64; both are unverified against a
  real install.
- Three nightly-only checks still owed, none covered by a `cmake -P`
  harness: `rt-backend-vk`'s `DT_NEEDED` must omit `SPIRV-Tools` (a
  static archive, build-only); `clspv`'s own shared dependencies, if it
  has any; whether to write `MoltenVK_icd.json` beside a copied
  `libMoltenVK.dylib` on macOS.

## Compile-definition macros

| macro | cmake definition site | C++ consumer | reads configuration today? | configuration entry | disposition |
|---|---|---|---|---|---|
| `ACPP_LLC_PATH` | (deleted) | `Utils.cpp` (`getLLCPath`) | yes — `try_retrieve_settings_variable("llc")` | `llc` → `ACPP_LLC` | **done** |
| `ACPP_LLD_PATH` | (deleted) | `Utils.cpp` (`getLLDPath`) | yes — `try_retrieve_settings_variable("lld")` | `lld` → `ACPP_LLD` | **done** |
| `ACPP_OPT_PATH` | (deleted) | `Utils.cpp` (`getOptPath`) | yes — `try_retrieve_settings_variable("opt")` | `opt` → `ACPP_OPT` | **done** |
| `ACPP_LLC_NAME` | `src/compiler/CMakeLists.txt` (bare `"llc"`, no `find_program`) | `Utils.cpp` (`getLLCPath`) | last-resort fallback only, after the setting | `llc` (exe entry) | **done** — kept, deliberately, as the bare-name/PATH fallback; no longer build-machine-discovered |
| `ACPP_LLD_NAME` | `src/compiler/CMakeLists.txt` (unchanged — platform-derived bare name, never `find_program`-discovered) | `Utils.cpp` (`getLLDPath`) | last-resort fallback only, after the setting | `lld` (exe entry) | **done** — same reasoning `ACPP_LLC_NAME` now also follows |
| `ACPP_OPT_NAME` | `src/compiler/CMakeLists.txt` (bare `"opt"`, no `find_program`) | `Utils.cpp` (`getOptPath`) | last-resort fallback only, after the setting | `opt` (exe entry) | **done** — kept, deliberately, as the bare-name/PATH fallback |
| `ACPP_CLANG_PATH` | (deleted) | `Utils.cpp` (`getClangPath`) | yes — `try_retrieve_settings_variable("clang")`, falls back to bare `"clang++"` | `clang` → `ACPP_CLANG` | **done** |
| `ROCM_CLANG_VERSION_MAJOR`/`MINOR`/`PATCH` | `CMakeLists.txt:389` | `PipelineBuilder.cpp:57-58`, `Frontend.hpp:91,569,640,752`, `SMCPCompatPass.cpp:23` — all `#if defined(ROCM_CLANG_VERSION_MAJOR) && ... == N` | no — read only by the preprocessor | none | still the root's own `execute_process`/regex probe, still not centralized into `cmake/discovery.cmake` - every consumer is an `#if` guard selecting which code the plugin compiles, so the value can never be a runtime read either way |
| `ACPP_LLC_HOST_CPU_FLAG`/`ACPP_OPT_HOST_CPU_FLAG`/`ACPP_LLC_ADDITIONAL_FLAGS`/`ACPP_OPT_ADDITIONAL_FLAGS` | (deleted) | `LLVMToHost.cpp` | yes — `try_retrieve_settings_variable` | `jit-host-llc-cpu-flag`/`jit-host-opt-cpu-flag`/`jit-host-llc-flags`/`jit-host-opt-flags` → `ACPP_JIT_HOST_*` (`cmake/options/common/core.cmake`, "The host JIT") | **done** |
| `ACPP_CUDA_DEVICE_LIBS_PATH` | (deleted) | `LLVMToPtx.cpp` | yes — `try_retrieve_settings_variable("cuda_libdevice_dir")` | `cuda-libdevice-dir` → `ACPP_CUDA_LIBDEVICE_DIR` | **done** |
| `ACPP_ROCM_DEVICE_LIBS_PATH` | (deleted) | `LLVMToAmdgpu.cpp` | yes — `try_retrieve_settings_variable("hip_device_libs_dir")` | `hip-device-libs-dir` → `ACPP_HIP_DEVICE_LIBS_DIR` | **done** — zero remaining references anywhere under `src/`, checked by grep |
| `ACPP_HIPCC_PATH` | (deleted) | (deleted: `getRocmClang`/`getCommandOutput` had no callers since upstream `377178f0`) | n/a | n/a | **done** — zero remaining references under `src/` |
| `HIPSYCL_CLSPV_PATH` | (deleted) | `LLVMToCLSPV.cpp` | yes — `try_retrieve_settings_variable("clspv")` | `clspv` → `ACPP_CLSPV` | **done** — zero remaining references under `src/` |
| `HIPSYCL_LLVMSPIRV_NAME` | `src/compiler/llvm-to-backend/CMakeLists.txt` (unchanged) | `LLVMToSpirv.cpp` | last-resort fallback only, after `try_retrieve_settings_variable("llvmspirv")` | `llvm-spirv` → `ACPP_LLVMSPIRV` | **done** — macro kept as the app-local-redistributable/installation-relative fallback (it names a relative path, never an absolute one) |
| `HIPSYCL_RELATIVE_LLVMSPIRV_PATH` | `src/compiler/llvm-to-backend/CMakeLists.txt` (unchanged) | `LLVMToSpirv.cpp`, alongside `HIPSYCL_LLVMSPIRV_NAME` | last-resort fallback only, after the same settings read | `llvm-spirv` → `ACPP_LLVMSPIRV` | **done** — same fallback, same reasoning |
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

**Done.** `bin/acpp`'s `config_db` now resolves `{{ key }}` references to a
fixpoint itself (`_resolve`/`_substitute`), reads `acpp-toolchain.json`
directly, and treats `acpp-root` as the one key the caller supplies rather
than one the config carries - the fixpoint resolver the configuration
model describes exists in the driver today, not just in cmake. A separate
resolver, `resolve_deploy_template`, does the same for a deploy manifest
row, with `acpp-runtime-root` substituted from the deploy target instead
of the config. The remaining `"default-"`-prefixed keys and the
`$ACPP_LIB_PATH` hardcodes are recorded in "Open" above - both sit outside
the vendor-unit model this campaign built.

### settings.cpp (the runtime's configuration singleton)

**Done.** The installed app config (`etc/AdaptiveCpp/acpp-app.cfg` - one
per runtime copy, `cmake/acpp-installed-configs.cmake` + `CMakeLists.txt`'s
root `install(FILES)` rules) is loaded by `settings_config_file`'s
constructor before upstream's beside-the-executable files, which still
override it unchanged - found via `common::filesystem::get_lib_directory()`
joined with `ACPP_RT_LIB_DIR_TO_APP_CONFIG`, a `PRIVATE` compile definition
`src/common/CMakeLists.txt` computes with `file(RELATIVE_PATH)` at
configure time, never an absolute path. A value beginning with the literal
`$ACPP_RT_LIB_DIR` (only that prefix - no other expansion) is rewritten the
same way in `load_file`. `try_retrieve_environment_variable`/
`try_retrieve_settings_variable` (`include/hipSYCL/common/settings.hpp`) no
longer truncate a `std::string`-typed setting at its first whitespace.

Every baked tool-path macro the table above names
(`ACPP_LLC_PATH`/`ACPP_LLD_PATH`/`ACPP_OPT_PATH`/`ACPP_CLANG_PATH`, plus
`HIPSYCL_LLVMSPIRV_NAME`/`HIPSYCL_RELATIVE_LLVMSPIRV_PATH`'s disposition)
goes through `try_retrieve_settings_variable` first
(`Utils.cpp`'s `getLLCPath`/`getLLDPath`/`getOptPath`/`getClangPath`,
`LLVMToSpirv.cpp`), reading from the same installed app config. `ACPP_CLANG`
falls back to the bare `"clang++"`; `ACPP_LLC`/`ACPP_LLD`/`ACPP_OPT` fall
back to `ACPP_LLC_NAME`/`ACPP_LLD_NAME`/`ACPP_OPT_NAME` (bare names
resolved via `PATH`, never a `find_program` result). The vector-math-library
setting (`LLVMToHost.cpp`'s `host-vector-math-library` kernel-build option)
is a separate settings surface (`hipsycl::rt::settings`,
`include/hipSYCL/runtime/settings.hpp`) from `common::settings`; its
generated key, `ACPP_JITOPT_HOST_VECTOR_MATH_LIBRARY`, matches
`config/*/app/core.cfg`'s key exactly.

Root `CMakeLists.txt` no longer computes `CLANG_INSTALLED_PATH` at all
(checked by grep - zero remaining references) and no longer wraps
`CLANG_INCLUDE_PATH` in a deploy-path prefix. `ROCM_CXX_FLAGS`/
`CUDA_CXX_FLAGS` are deleted outright: the options model's
`ACPP_HIP_CXX_FLAGS`/`ACPP_CUDA_CXX_FLAGS` supersede them.
`doc/install-rocm.md` still documents `-DROCM_CXX_FLAGS` as a user
override; stale, not fixed here.

Windows: `backend_loader.cpp`'s `get_plugin_search_paths()` calls
`AddDllDirectory` for each vendor's app-config-declared directory -
settings `"cuda_dll_dir"`, `"ocl_dll_dir"`, `"ze_dll_dir"`,
`"libomp_dll_dir"`, read via `try_retrieve_settings_variable`, reading
`ACPP_CUDA_DLL_DIR`/`ACPP_OCL_DLL_DIR`/`ACPP_ZE_DLL_DIR`/
`ACPP_LIBOMP_DLL_DIR` from the installed app config
(`config/windows/common/app/{cuda,ocl,ze,core}.cfg`).
`src/common/dylib_loader.cpp`'s `load_library` calls `LoadLibraryExA(...,
LOAD_LIBRARY_SEARCH_DEFAULT_DIRS)` first, which Win32 documents to include
the process's `AddDllDirectory` list with no `SetDefaultDllDirectories`
call needed - so every `AddDllDirectory` call this mechanism adds is
actually honoured.

### Install rpaths that hardcode lib

Six `INSTALL_RPATH`/`CMAKE_INSTALL_RPATH` sites exist under `src/`.
`${base}` is set once, in `src/CMakeLists.txt:9,12`, to `$ORIGIN`
(non-Apple) or `@loader_path` (Apple). Two build on it without naming a
libdir (`src/runtime/CMakeLists.txt:23,121`,
`src/compiler/llvm-to-backend/CMakeLists.txt:7`) and need nothing further.
The remaining four, in `src/tools/*/CMakeLists.txt`, still hardcode `lib`
- see "Open" above.

### The global configuration installation

**Resolved as far as the tree can settle it.** The real variable is
`ACPP_CONFIG_FILE_INSTALL_DIR` (`CMakeLists.txt:557`), set to the relative
subpath `etc/AdaptiveCpp`, joined under the install prefix and read the
same way by `bin/acpp`. Nothing in the tree installs it, or anything else,
to a literal absolute `/etc/AdaptiveCpp` outside a prefix. What is still
open - whether it should ever gain a second, non-prefix-relative install
site - is recorded under "Open" above; it needs Jack's ruling, not more
reading of the source.

### Wiring-slice obligations, by vendor slice

The per-vendor options files, install rules, deploy manifests and
discovery files this section used to itemize as owed are in the tree now
- `cmake/options/<platform>/common/*.cmake`, `cmake/install/<platform>/
common/*.cmake`, `config/<platform>/common/*.json` and `deploy/*.json`,
`cmake/discovery/*.cmake` - one set per CUDA, HIP, OpenCL, Level Zero,
Vulkan, OMP, and the aarch64/windows-x86_64/windows-aarch64/macos-arm64
platform deltas, each parsed and checked by its own `devops/verify`
harness (`doc/configuration-model.md`'s "Verification" lists them). What
each slice's own section here used to flag as not yet done and is not
covered above is:

- The root `CMakeLists.txt` finds each slice complained still duplicated
  discovery - consolidated into the one "Open" bullet above rather than
  repeated per vendor.
- The CUDA slice's `bin/acpp` obligations (`cuda_lib_path` composing
  `cuda-install-root`/`cuda-rt-subdir`, the `nvcxx_invocation` class) are
  done except the nvcxx link-line gap - see "Open" above.
- The Vulkan slice's three nightly questions (`DT_NEEDED` omitting
  `SPIRV-Tools`, `clspv`'s own shared deps, `MoltenVK_icd.json`) are
  still open - see "Open" above.
- The windows/aarch64 slice's CUDA version/DLL-naming assumption is still
  open - see "Open" above.

### The ownership rule and the deploy engine

**Done.** The deploy engine (`bin/acpp`'s `deployment_engine`/
`run_deployment`) filters manifest rows by `build-mode` at generation
time, before the manifest is even installed
(`cmake/acpp-installed-configs.cmake`'s `_acpp_filter_deploy_group`)
rather than at deploy time; the effect the obligation asked for is the
same. The `llvm` group deploys whenever it is present at all (rule 1);
`internal` always has. RUNPATH wiring follows ownership and shipped-ness,
not the strategy directly - `doc/configuration-model.md`'s "Linked vs
consumed" is the current description, and `cmake/acpp-vendor-rpath.cmake`
is the implementation. Upstream's own core deployment manifest is
replaced by this fork's, not merged with it -
`config/linux/common/deploy/core.json` carries only this fork's rows.

The deploy manifest is one merge of core's manifest and every enabled
vendor's (`acpp_merge_units`, `cmake/acpp-config-merge.cmake`); a
configuration key duplicated across files is a configure error
(`acpp_merge_json_objects`); an identical row arriving from more than one
vendor's manifest collapses to one (`acpp_merge_deploy`'s `dedupe`
argument). All three are covered by `verify-common.cmake`'s golden
comparisons. The one still-open deploy-engine question, the `"*"` entry
not filtering out static archives, is recorded under "Open" above.

### The path model

**Done.** The doubled-slash case an empty `<vendor>-subdir` used to
produce no longer exists: an application's own view of a vendor subdir is
now a concrete cmake string, computed at configure time by
`acpp_join_relative`/`acpp_join_absolute` (`cmake/options/common/
core.cmake`), which drop an empty piece before joining rather than
deferring the composition to a `{{ }}` template a deploy-time resolver
would have to normalize. There is nothing left in the deploy engine to
special-case.

Windows CI is still needed to exercise the real `WIN32` branch of
`acpp_declare_vendor`'s default - recorded under "Open" above.
