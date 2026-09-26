# Core options - linux, every architecture.

include_guard(GLOBAL)
include(${CMAKE_CURRENT_LIST_DIR}/../../common/core.cmake)

# ---------------------------------------------------------------------------
# Deploy paths - the publisher's choices
# ---------------------------------------------------------------------------
#
# LLVM has no deploy-path knob of its own any more: what toolchain mode
# builds follows cmake's own install directories under {{ acpp-root }}
# directly (the literal "bin" segment, and {{ acpp-libdir }}), the same as
# everything else we build. In plugin mode LLVM is the machine's (rule 2)
# and is never bundled at all.
#
# Where libomp lands. libomp is declared unconditionally, in both build
# modes, by the common file (principle 3: an ordinary vendor unit, not a
# build-mode branch) - see its "OMP" section, which owns every {{ }} entry
# libomp's own link lines and application config now read; a packager
# using GOMP instead points ACPP_LIBOMP_SOURCE_DIR at it directly.

# libnuma, sleef and amath are ordinary shared libraries with no internal
# structure to preserve, each its own vendor unit with the same two-knob
# shape - libnuma is never something we build, all three permissive.
# libnuma is linked (DT_NEEDED through rt-backend-omp), not consumed, so no
# application ever reads an install-root value for it - unlike sleef and
# amath, which the host JIT looks up by directory at run time, libnuma has
# no application-config declaration at all.
acpp_declare_vendor(LIBNUMA libnuma permissive)
acpp_declare_vendor_root(LIBNUMA libnuma ACPP_DISCOVERED_LIBNUMA_DIR "${ACPP_DISCOVERED_LIBNUMA_DIR}")

# ---------------------------------------------------------------------------
# The device compiler and the LLVM executables
# ---------------------------------------------------------------------------
#
# The device compiler is used by the multipass flows AND by the generic JIT,
# which is exactly why it has two sides: the driver invokes it from the
# toolchain while compiling, the JIT invokes it from the deployment while an
# application runs, and those need not be the same binary.
#
# Ownership, not deployment strategy, decides which shape these five take
# (see "Ownership" in the common file). Toolchain mode builds this LLVM, so
# it is ours: always the deploy-layout placeholder, in every strategy.
# Plugin mode's LLVM is the machine's (rule 2): always the discovered
# absolute path, in every strategy, empty and not an error when discovery
# found no plugin to build (decision d).

if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  # No {{ acpp-bindir }} entry exists on this platform (only Windows names
  # one): CMAKE_INSTALL_BINDIR is "bin" everywhere cmake's own GNU install
  # dirs apply, unlike the libdir, which varies (lib64, multiarch), so the
  # segment is written literally.
  acpp_declare_owned_resource(DEVICE_CMPLR "${CMAKE_INSTALL_BINDIR}/clang++")
  acpp_declare_owned_resource(LLC "bin/llc")
  acpp_declare_owned_resource(OPT "bin/opt")
  acpp_declare_owned_resource(LLD "bin/ld.lld")
  # clang's resource include directory. The JIT's HIP compilation needs it,
  # so it has two sides like the compiler itself. Concrete now, not a {{ }}
  # template: acpp_declare_owned_resource's application side is written by
  # configure_file, which resolves nothing.
  acpp_declare_owned_resource(CLANG_INCLUDE_PATH "${CMAKE_INSTALL_LIBDIR}/clang/${LLVM_VERSION_MAJOR}/include")
else()
  acpp_declare_machine_resource(DEVICE_CMPLR ACPP_DISCOVERED_CLANG "${ACPP_DISCOVERED_CLANG}")
  acpp_declare_machine_resource(LLC ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/llc")
  acpp_declare_machine_resource(OPT ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/opt")
  acpp_declare_machine_resource(LLD ACPP_DISCOVERED_LLVM_BINDIR "${ACPP_DISCOVERED_LLVM_BINDIR}/ld.lld")
  acpp_declare_machine_resource(CLANG_INCLUDE_PATH ACPP_DISCOVERED_CLANG_INCLUDE "${ACPP_DISCOVERED_CLANG_INCLUDE}")
endif()

# llvm-spirv is not LLVM's: AdaptiveCpp builds its own fork of the
# SPIRV-LLVM-Translator and installs it under its own library directory
# (doc/install-ocl.md), independent of cmake's own LLVM install dirs. Ours
# in BOTH modes (rule 1) - the machine's LLVM never supplies it, plugin or
# not - always the deploy-layout placeholder, in every strategy.
acpp_declare_owned_resource(LLVMSPIRV "${CMAKE_INSTALL_LIBDIR}/hipSYCL/ext/llvm-spirv/bin/llvm-spirv")

# The vector math libraries, each its own vendor unit with the same
# two-knob shape as libnuma above, permissive - directory-valued because
# the library's short name is written into the JIT's link invocation.
# libmvec needs no entry: it is part of glibc, so the only correct copy is
# the one the loader resolves in the running process. SVML is x86-only and
# lives in the arch file.
acpp_declare_vendor(SLEEF sleef permissive)
acpp_declare_vendor_root(SLEEF sleef ACPP_DISCOVERED_SLEEF_DIR "${ACPP_DISCOVERED_SLEEF_DIR}")
acpp_declare_vendor_app_root(SLEEF sleef)

# Nonpermissive: Arm Performance Libraries' math library is redistributed
# under Arm's End User License Agreement (upstream's doc/deployment.md).
# SLEEF (above) stays permissive: it ships under the Boost Software
# License.
acpp_declare_vendor(AMATH amath nonpermissive "${ACPP_DISCOVERED_AMATH_DIR}")
acpp_declare_vendor_root(AMATH amath ACPP_DISCOVERED_AMATH_DIR "${ACPP_DISCOVERED_AMATH_DIR}")
acpp_declare_vendor_app_root(AMATH amath)

# ---------------------------------------------------------------------------
# Driver-only resources
# ---------------------------------------------------------------------------

# The host C++ compiler the driver invokes for CPU code. Ownership, not
# strategy, decides its shape: in toolchain mode it is our own clang++,
# always the deploy-layout placeholder in every strategy (rule 1). In
# plugin mode it is upstream's HIPSYCL_CPU_CXX exactly: the machine's own
# build compiler (CMAKE_CXX_COMPILER), the one AdaptiveCpp itself was built
# with, absolute, in every strategy, overridable only by reconfiguring with
# a different CMAKE_CXX_COMPILER - not by a strategy choice.
if(LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  set(ACPP_CPU_CXX "{{ acpp-root }}/{{ acpp-bindir }}/clang++")
else()
  set(ACPP_CPU_CXX "${CMAKE_CXX_COMPILER}")
endif()

# The compiler plugin, in plugin builds only. We always build our own
# plugin file, so it is ours (rule 1): always the deploy-layout placeholder,
# in every strategy, with no override - a strategy choice is about vendor
# assets we do not build, and this is not one. When
# AdaptiveCpp is linked into the LLVM tools there is no plugin file and the
# driver emits no plugin flags.
if(NOT LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  set(ACPP_PLUGIN_PATH "{{ acpp-root }}/{{ acpp-libdir }}/libacpp-clang.so")
endif()

# Which vector math library the host JIT uses. NOT discovery-derived: several
# may be present at once and discovery cannot choose between them. The default
# is the one every glibc system has, every code path compiles unconditionally,
# and the runtime falls back to libmvec when the configured library is absent.
if(NOT DEFINED ACPP_VECTOR_MATH_LIB)
  set(ACPP_VECTOR_MATH_LIB "libmvec")
endif()

# ---------------------------------------------------------------------------
# Driver behaviour - platform-specific defaults
# ---------------------------------------------------------------------------

if(NOT DEFINED ACPP_SEQUENTIAL_LINK_LINE)
  set(ACPP_SEQUENTIAL_LINK_LINE "")
endif()

# The CPU backend is always built (upstream's WITH_CPU_BACKEND is
# unconditionally true), so the omp flows have no vendor unit: this is
# core, not a vendor file. The link line and flags are the platform's,
# which is why they live here rather than matrix-wide; the omp link line
# carries no rpath to libomp: under the omp flows the application's own
# link binds libomp, so the RUNPATH is the application builder's. Upstream's
# DEFAULT_OMP_FLAG has no APPLE special case outside macOS, so this needs no
# branch by build mode.
if(NOT DEFINED ACPP_OMP_LINK_LINE)
  set(ACPP_OMP_LINK_LINE "-fopenmp")
endif()

# -D_ENABLE_EXTENDED_ALIGNED_STORAGE is needed for correctly aligned local
# memory on CPU.
if(NOT DEFINED ACPP_OMP_CXX_FLAGS)
  set(ACPP_OMP_CXX_FLAGS "-fopenmp -D_ENABLE_EXTENDED_ALIGNED_STORAGE")
endif()
