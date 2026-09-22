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
| `ACPP_CUDA_DEVICE_LIBS_PATH` | `src/compiler/llvm-to-backend/CMakeLists.txt:271` | `LLVMToPtx.cpp:60` | no — raw macro | CUDA slice | replace when CUDA slice lands |
| `ACPP_ROCM_DEVICE_LIBS_PATH` | `src/compiler/llvm-to-backend/CMakeLists.txt:284` | `LLVMToAmdgpu.cpp:203` | no — raw macro | HIP slice | replace when HIP slice lands |
| `ACPP_HIPCC_PATH` | `src/compiler/llvm-to-backend/CMakeLists.txt:292` | `LLVMToAmdgpu.cpp:67` | no — raw macro | HIP slice | replace when HIP slice lands |
| `HIPSYCL_CLSPV_PATH` | `src/compiler/llvm-to-backend/CMakeLists.txt:358` | `LLVMToCLSPV.cpp:302` | no — raw macro | Vulkan slice | replace when Vulkan slice lands |
| `HIPSYCL_LLVMSPIRV_NAME` | `src/compiler/llvm-to-backend/CMakeLists.txt:257` | `LLVMToSpirv.cpp:328` | no — raw macro | stays | relative by construction |
| `LIB_NUMA_AVAILABLE` | `src/runtime/CMakeLists.txt:414` | `omp_allocator.cpp:14,30,58,121,159,169` | n/a — gates code | stays | stays, gates code |
| `ACPP_HIPRTC_LINK` | `src/compiler/llvm-to-backend/CMakeLists.txt:302` | `LLVMToAmdgpu.cpp` | n/a — gates code | stays | stays |

### Done: vector-math conversion

| macro (deleted) | C++ consumer | reads configuration today? | configuration entry |
|---|---|---|---|
| `SLEEF_AVAILABLE` | `Utils.cpp`, `LLVMToHost.cpp` | yes — `try_retrieve_settings_variable("sleef_dir")` | `sleef-dir` → `ACPP_JITOPT_SLEEF_DIR` |
| `AMATH_AVAILABLE` | `Utils.cpp`, `LLVMToHost.cpp` | yes — `try_retrieve_settings_variable("amath_dir")` | `amath-dir` → `ACPP_JITOPT_AMATH_DIR` |
| `SVML_AVAILABLE` | `Utils.cpp`, `LLVMToHost.cpp` | yes — `try_retrieve_settings_variable("svml_dir")` | `svml-dir` → `ACPP_JITOPT_SVML_DIR` |
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
`$ACPP_PATH` and `$ACPP_TARGET` by string substitution; it does not resolve
`{{ }}` references between entries.
