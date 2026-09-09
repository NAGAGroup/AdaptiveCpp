# Path resolution: as-built ledger

An audit of how AdaptiveCpp locates every external resource today, and of every
knob that changes that behaviour. This describes the state _before_ unification;
it is the input to the specification, not the specification itself.

## The three states

Path resolution happens in three distinct states. They are named so that each
carries its own subject, because the failure mode is a reader assuming the
wrong one:

- **when building the toolchain** — AdaptiveCpp itself is being compiled and
  installed. The only state in which cmake exists.
- **when driving the toolchain** — `acpp` is compiling a user's program. The
  Python driver resolves settings, invokes clang, and links.
- **when running an application** — a program built with acpp is executing, on a
  machine we may never see. The JIT runs here, so this state compiles too.

## Method

Every non-test cmake file in the project was read whole (26 files, 3,803 lines),
along with `bin/acpp`, `src/common/filesystem.cpp`, `src/common/dylib_loader.cpp`
and `src/compiler/llvm-to-backend/Utils.cpp`. Macro consumers were established by
searching all 887 tracked C/C++ files for each identifier as a bare token, so a
name used only in an `#ifdef` is still counted as a consumer.

Counts and consumer claims in this document were measured, not inferred. Where
something is inferred it says so.

---

## Ledger 1 — discovery, by resource

`$ACPP_PATH` denotes the placeholder expanded by `replacePathPlaceholders()`
against `get_install_directory()`. "loader" denotes
`common::filesystem::get_lib_directory()`, which asks the dynamic loader via
`dladdr` where the calling library actually is — the only mechanism that carries
no build knowledge at all.

### Toolchain executables

| Resource           | Building the toolchain                                                                                | Driving the toolchain                                      | Running an application                                                                       |
| ------------------ | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `clang`            | `find_program` → `CLANG_EXECUTABLE_PATH`, or `$ACPP_PATH/bin/clang++` when built as an LLVM component | `default-clang` config key · `ACPP_CLANG` · `--acpp-clang` | `getClangPath()` → `ACPP_CLANG_PATH` macro, placeholder-expanded. **No redist tier, no env** |
| clang resource dir | `find_path(FOUND_CLANG_INCLUDE_PATH)`, or `$ACPP_PATH/<resource dir>` as a component                  | `default-clang-include-path` · `ACPP_CLANG_INCLUDE_PATH`   | not consulted                                                                                |
| `llc`              | `find_program`, or `$ACPP_PATH/bin/llc` as a component                                                | not consulted                                              | `getLLCPath()` → redist dir, else macro placeholder-expanded                                 |
| `lld`              | as `llc`                                                                                              | not consulted                                              | `getLLDPath()`, same shape                                                                   |
| `opt`              | as `llc`                                                                                              | not consulted                                              | `getOptPath()`, same shape                                                                   |
| host C++ compiler  | `CMAKE_CXX_COMPILER`                                                                                  | `default-cpu-cxx` · `ACPP_CPU_CXX` · `--acpp-cpu-cxx`      | not consulted                                                                                |
| `nvc++`            | `find_program(NVCXX_COMPILER)`                                                                        | `default-nvcxx` · `ACPP_NVCXX`                             | not consulted                                                                                |

### Device bitcode

| Resource               | Building the toolchain                          | Driving the toolchain | Running an application                                                          |
| ---------------------- | ----------------------------------------------- | --------------------- | ------------------------------------------------------------------------------- |
| our SSCP bitcode       | built by us, installed to `lib/hipSYCL/bitcode` | not consulted         | `getBitcodePath()` — loader-relative, no macro involved                         |
| CUDA `libdevice.10.bc` | `find_path(CUDA_DEVICE_LIBS_PATH)`              | not consulted         | `getDeviceLibPath()` — redist dir, else **raw macro, not placeholder-expanded** |
| ROCm device libs       | `find_path(ROCM_DEVICE_LIBS_PATH)`              | not consulted         | `LLVMToAmdgpu.cpp:203` — **raw macro, not placeholder-expanded**                |

### Vendor toolkits and runtimes

| Resource                                                                      | Building the toolchain                                | Driving the toolchain                                                           | Running an application                                                                              |
| ----------------------------------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| CUDA toolkit dir                                                              | `find_package(CUDAToolkit)` → `CUDA_TOOLKIT_ROOT_DIR` | `default-cuda-path` · `ACPP_CUDA_PATH`, expands `$ACPP_CUDA_PATH` in link lines | not consulted                                                                                       |
| CUDA lib dir                                                                  | —                                                     | `default-cuda-lib-path` · `ACPP_CUDA_LIB_PATH`, defaults to `<cuda>/lib64`      | not consulted                                                                                       |
| `libcudart`                                                                   | linked into `rt-backend-cuda`                         | not consulted                                                                   | **`DT_NEEDED`** on `libcudart.so.12.9.79` — versioned soname                                        |
| `libcuda` (driver)                                                            | linked into `rt-backend-cuda`                         | not consulted                                                                   | **`DT_NEEDED`** on `libcuda.so.1`                                                                   |
| ROCm dir                                                                      | `ROCM_PATH` cache var, defaulted to `/opt/rocm`       | `default-rocm-path` · `ACPP_ROCM_PATH`                                          | not consulted                                                                                       |
| ROCm lib dir                                                                  | —                                                     | `default-rocm-lib-path` · `ACPP_ROCM_LIB_PATH`                                  | not consulted                                                                                       |
| `hipcc`                                                                       | `find_program(HIPCC_PATH)`                            | not consulted                                                                   | `ACPP_HIPCC_PATH` macro, presence-tested by `#if defined`, **not placeholder-expanded**             |
| `libamdhip64`, `hsa-runtime64`, `amd_comgr`, `hsakmt`, `rocprofiler-register` | `find_library` each                                   | not consulted                                                                   | **`DT_NEEDED`** via `ROCM_LIBS`                                                                     |
| `hiprtc`                                                                      | `find_library(HIPRTC_LIBRARY)`                        | not consulted                                                                   | linked when found                                                                                   |
| Level Zero loader                                                             | `find_library(ACPP_ZE_LOADER_LIBRARY)`                | not consulted                                                                   | **`DT_NEEDED`** on `libze_loader.so.1` — but that library is itself a loader that discovers drivers |
| OpenCL ICD loader                                                             | `find_package(OpenCL)`                                | not consulted                                                                   | **`DT_NEEDED`** on `libOpenCL.so` — itself a loader that discovers implementations                  |
| `clspv`                                                                       | `find_program(CLSPV_COMPILER)`                        | not consulted                                                                   | `HIPSYCL_CLSPV_PATH` macro. Not built in our configuration                                          |
| LLVM SPIR-V translator                                                        | built as an `ExternalProject`                         | not consulted                                                                   | `HIPSYCL_RELATIVE_LLVMSPIRV_PATH` — **relative by construction**, the one that got this right       |

### Vector math libraries

| Resource     | Building the toolchain                    | Driving the toolchain | Running an application                                                                        |
| ------------ | ----------------------------------------- | --------------------- | --------------------------------------------------------------------------------------------- |
| `libmvec`    | `find_library` for **detection only**     | not consulted         | `getLibMvecDir()` — `dlopen` + `dlinfo`, asks the loader. Path deliberately never compiled in |
| SLEEF        | `find_library(LIBSLEEF)`, aarch64 only    | not consulted         | `getLibSleefDir()` — beside our libs, else macro expanded. Returns **empty** if neither       |
| AMATH        | `find_library(LIBAMATH)`, aarch64 only    | not consulted         | `getLibAmathDir()`, same shape                                                                |
| SVML / INTLC | `find_library`, x86 only; absent in conda | not consulted         | `getLibSvmlDir()`, same shape                                                                 |

### Our own artefacts

| Resource          | Building the toolchain                            | Driving the toolchain                                    | Running an application                                                                         |
| ----------------- | ------------------------------------------------- | -------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| install prefix    | `CMAKE_INSTALL_PREFIX` → `HIPSYCL_INSTALL_PREFIX` | `acpp_installation_path`, from the driver's own location | loader, with `HIPSYCL_INSTALL_PREFIX` as an `is_directory`-guarded fallback                    |
| config file dir   | `ACPP_CONFIG_FILE_INSTALL_DIR`                    | `default-config-file-dir` · `ACPP_CONFIG_FILE_DIR`       | not consulted                                                                                  |
| backend libraries | installed to `lib/hipSYCL`                        | not consulted                                            | `dlopen` by path, loader-relative, via `dylib_loader.cpp`                                      |
| `libLLVM`         | `find_library(LLVM_LIBRARY)`                      | not consulted                                            | `DT_NEEDED`                                                                                    |
| `libomp`          | `find_package(OpenMP)`                            | link line                                                | `DT_NEEDED` — bare `libomp.so`, and LLVM's per-target layout installs it under `lib/<triple>/` |
| NUMA              | `find_library(NUMA_LIBRARY)`                      | not consulted                                            | `DT_NEEDED`                                                                                    |

---

## Ledger 2 — knobs, by surface

Five surfaces can change resolution. The final column answers _can a packager
fix this after the fact?_ — because that decides whether a defect has to be
solved when building the toolchain, or merely tidied afterwards.

| Surface                            | Count                                                                                                  | Acts in                           | Packager-fixable                      |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------ | --------------------------------- | ------------------------------------- |
| cmake cache options                | 69 entries, ~40 distinct                                                                               | building the toolchain            | no                                    |
| compile definitions carrying paths | 8 (5 in `llvm-to-backend`, 3 in `src/compiler` behind the component branch)                            | building → running an application | **no** — string literals in `.rodata` |
| driver options                     | 36, each with flag + env var + config key                                                              | driving the toolchain             | n/a                                   |
| generated config keys              | 7 path-valued, across three JSON files                                                                 | driving the toolchain             | yes, the files are editable           |
| deployment manifest entries        | 17 path-valued, across four JSON files                                                                 | driving the toolchain             | yes                                   |
| ELF `RPATH`                        | `$ORIGIN` set for 4 of 7 targets; `CMAKE_INSTALL_RPATH_USE_LINK_PATH` adds absolute paths for the rest | building the toolchain            | **yes** — relinkers rewrite it        |

### The knobs we added

| Name                                        | Surface        | Effect                                         |
| ------------------------------------------- | -------------- | ---------------------------------------------- |
| `ACPP_CONFIG_FILE_OMIT_ENVIRONMENT_PATHS`   | cmake `BOOL`   | Empties 7 config keys and 17 manifest entries  |
| `ACPP_OMIT_RECORDED_INSTALL_PREFIX`         | cmake `BOOL`   | Empties `HIPSYCL_INSTALL_PREFIX`               |
| `ACPP_SPIRV_CMAKE_ARGS`                     | cmake `STRING` | Passes cmake args to the SPIR-V sub-build      |
| `ACPP_CUDA_LIB_PATH` / `ACPP_ROCM_LIB_PATH` | driver option  | Overrides the derived vendor library directory |

### Path-valued compile definitions

| Definition                                          | Target            | Consumer                    | Placeholder-expanded |
| --------------------------------------------------- | ----------------- | --------------------------- | -------------------- |
| `ACPP_CLANG_PATH`                                   | `llvm-to-backend` | `Utils.cpp:58`              | yes                  |
| `ACPP_LLC_PATH` / `ACPP_LLD_PATH` / `ACPP_OPT_PATH` | compiler          | `Utils.cpp:75/93/111`       | yes                  |
| `LIB_SLEEF_DIR` / `LIB_AMATH_DIR` / `LIB_SVML_DIR`  | compiler          | `Utils.cpp:132/154/182`     | yes                  |
| `LIB_INTLC_DIR`                                     | compiler          | via `LIB_SVML_DIR`'s getter | n/a                  |
| `ACPP_CUDA_DEVICE_LIBS_PATH`                        | `llvm-to-ptx`     | `LLVMToPtx.cpp:60`          | **no**               |
| `ACPP_ROCM_DEVICE_LIBS_PATH`                        | `llvm-to-amdgpu`  | `LLVMToAmdgpu.cpp:203`      | **no**               |
| `ACPP_HIPCC_PATH`                                   | `llvm-to-amdgpu`  | `LLVMToAmdgpu.cpp:66`       | **no**               |
| `HIPSYCL_CUDA_PATH`                                 | `llvm-to-ptx`     | **none**                    | dead                 |
| `ACPP_ROCM_PATH`                                    | `llvm-to-amdgpu`  | **none**                    | dead                 |

---

## Observations

**1. Four getter shapes in one file.** `Utils.cpp` resolves ten resources with
four different procedures: placeholder-only (`getClangPath`), redist-then-
placeholder (`getLLCPath` and two others), redist-then-placeholder guarded by an
availability macro and returning empty on failure (the three vector libraries),
and loader-only (`getLibMvecDir`). Nothing marks which shape applies where.

**2. No environment variable reaches the application-running state.** Not one
getter consults the environment. The driver has a complete flag → env → config
chain for all 36 of its options, and none of it is visible to the JIT. This is
why setting `ACPP_CUDA_PATH` cannot fix a libdevice lookup.

**3. Three call sites bypass the getters entirely.** `LLVMToPtx.cpp:60`,
`LLVMToAmdgpu.cpp:203` and `LLVMToAmdgpu.cpp:67` use their macros raw. Because
they never call `replacePathPlaceholders`, a build that embedded `$ACPP_PATH`
values would ship the literal string and fail — so the placeholder mechanism
cannot be adopted for these without changing the source first.

**4. One name, three meanings.** `ACPP_ROCM_PATH` is simultaneously a link-line
placeholder, a driver env var, and a C++ macro. They are unrelated, and only the
macro is dead. `ACPP_CUDA_DEVICE_LIBS_PATH` is both a cmake cache variable and a
compile definition. Any audit keyed by name rather than by surface will be wrong.

**5. Scrubbing produces a non-functional toolchain.** With
`ACPP_CONFIG_FILE_OMIT_ENVIRONMENT_PATHS=ON`, `default-clang`,
`default-cpu-cxx` and `default-clang-include-path` are empty, so a bare install
cannot compile anything until the user supplies three environment variables.
Relocatability was achieved by removing function rather than by making the
values relative.

**6. Two of four backends already have the target architecture.** OpenCL and
Level Zero both reach their implementations through a loader library that
discovers drivers at run time; only CUDA and HIP link a vendor SDK directly, and
those are exactly the two whose versioned sonames force tight package pins.

**7. The correct pattern usually already exists.** The driver's naming
convention is fully derivable; `Utils.cpp`'s getter is the right shape;
`dylib_loader.cpp` is a complete, cross-platform loading abstraction;
`HIPSYCL_RELATIVE_LLVMSPIRV_PATH` is relative by construction. In each case part
of the system is already right and the rest diverges. Unification is mostly
promotion, not invention.
