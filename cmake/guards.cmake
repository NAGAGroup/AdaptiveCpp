# Configurations this tree does not support.
#
# This fork is production source for a specific toolchain, not a general build
# of AdaptiveCpp. Everything below is unsupported not because it cannot work,
# but because we have not qualified it - and an unqualified toolchain is worse
# than an absent one, since everything compiled with it inherits the doubt.
#
# These guards exist as much for us as for anyone else. Enabling a platform
# means making every part of the toolchain work for it, including the parts
# that are easy to forget: the deployment manifests, the library naming, the
# vector math selection. A configure-time failure is the reminder.
#
# If you are reading this because a guard stopped you: nothing here is a
# judgement about the configuration. It means the work to support it has not
# been done, and the honest failure is at configure time rather than in an
# artifact that looks fine and is not.
#
# Must be included after the backend and feature-profile variables are set.

include_guard(GLOBAL)

set(ACPP_UNSUPPORTED_PREAMBLE
  "This AdaptiveCpp tree supports linux-64 only, with the core, CUDA, ROCm, \
OpenCL and Level Zero backends. See doc/relocatable-overhaul-spec.md.")

# --- platform ---------------------------------------------------------------

if(WIN32)
  message(FATAL_ERROR "${ACPP_UNSUPPORTED_PREAMBLE}\n"
    "Windows is not supported. The deployment manifests are generated in a "
    "single POSIX-shaped block; Windows library naming is handled only when "
    "the driver READS a manifest, never when cmake writes one. A Windows "
    "build would therefore produce manifests that cannot deploy.")
endif()

if(APPLE)
  message(FATAL_ERROR "${ACPP_UNSUPPORTED_PREAMBLE}\n"
    "macOS is not supported. It shares the manifest problem with Windows, and "
    "neither CUDA nor ROCm exists there, so the backends we qualify are absent.")
endif()

if(CMAKE_SYSTEM_PROCESSOR MATCHES "(arm|aarch64)")
  message(FATAL_ERROR "${ACPP_UNSUPPORTED_PREAMBLE}\n"
    "AArch64 is not supported. The vector math library selection differs from "
    "x86 - SLEEF and AMATH rather than SVML - and that path is untested here.")
endif()

# --- backends ---------------------------------------------------------------

if(WITH_VULKAN_BACKEND)
  message(FATAL_ERROR "${ACPP_UNSUPPORTED_PREAMBLE}\n"
    "The Vulkan backend is not supported. It is experimental upstream, clspv "
    "is found rather than built so the toolchain would depend on something we "
    "do not ship, and there is no deployment manifest for it - an application "
    "using it could be built and then not deployed.")
endif()

# --- how AdaptiveCpp is built ------------------------------------------------

# Our clang plugin is linked into the clang binary rather than loaded as a
# separate module. That is what lets a single clang serve both as the compiler
# and as the plugin host, and it is the configuration every other decision in
# this tree assumes - including that ACPP_CLANGXX can point at our own clang++.
if(NOT LLVM_ADAPTIVECPP_LINK_INTO_TOOLS)
  message(FATAL_ERROR "${ACPP_UNSUPPORTED_PREAMBLE}\n"
    "LLVM_ADAPTIVECPP_LINK_INTO_TOOLS must be ON. This tree is built as an "
    "in-tree LLVM component with the plugin linked into clang; a separately "
    "loaded plugin module is a different toolchain with different failure "
    "modes, and is not what we qualify or package.")
endif()

# --- compiler features -------------------------------------------------------

if(ACPP_COMPILER_FEATURE_PROFILE STREQUAL "none" OR
   ACPP_COMPILER_FEATURE_PROFILE STREQUAL "minimal")
  message(FATAL_ERROR "${ACPP_UNSUPPORTED_PREAMBLE}\n"
    "ACPP_COMPILER_FEATURE_PROFILE=${ACPP_COMPILER_FEATURE_PROFILE} is not "
    "supported; use 'full'. The lower profiles disable the SSCP compiler, "
    "which is the generic single-source JIT that --acpp-targets=generic "
    "depends on. Without it a binary compiled by this toolchain runs on the "
    "host only, which is not the product.")
endif()
