# Deploying AdaptiveCpp-generated binaries

AdaptiveCpp provides mechanisms to aid in deploying AdaptiveCpp-compiled binaries to end users. The following discussion focuses on applications compiled by the generic SSCP compiler (`--acpp-targets=generic`), but other compilation flows might work as well.

## Deployment infrastructure

`acpp --acpp-deploy=<path>` populates a directory with what an application needs at run time, for a toolchain built with `ACPP_DEPLOYMENT_STRATEGY=full` or `full-permissive-only` (under `managed`, the default, the toolchain is an ordinary CMake project and deploying is the configurer's business - the command reports that and exits).

The directory mirrors the toolchain's own install layout. Deployed libraries find each other and the shipped vendor libraries through relative rpaths (`$ORIGIN`/`@loader_path`; on Windows, through the DLL directories in the deployed application config), so no `LD_LIBRARY_PATH` is needed. Install your application's executable into the deployment's `bin` directory; CMake applications get the matching rpath from `add_sycl_to_target`. See [the configuration model](configuration-model.md) for the details.

### Deployment components

`--acpp-deploy` still accepts a `<component>:` selection (`core`, `cuda`, `hip`, `ocl`, `all`), but it is now accepted for compatibility only and ignored: the installed manifest covers every backend the toolchain was built with, and deploys as a whole.

What is deployed:

* The AdaptiveCpp runtime, its backends, and the JIT compiler's own libraries and bitcode.
* In toolchain mode (AdaptiveCpp linked into LLVM), the LLVM pieces the JIT needs. In plugin mode (AdaptiveCpp built against a system LLVM), that LLVM is not deployed - an application's users need the same LLVM installed.
* The vendor runtimes the toolchain ships: permissive ones (SLEEF, libnuma, the OpenCL/Level Zero/Vulkan loaders, OMP's libomp, ...) always; nonpermissive ones (CUDA, the HPC SDK runtime, SVML, AMATH) only under `full`, and only once the builder accepted their terms with `ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN`.
* The application config, `etc/AdaptiveCpp/acpp-app.cfg`.

**Note on the `ocl` component:** AdaptiveCpp only handles the deployment of the OpenCL ICD loader. End users are responsible for installing an OpenCL driver for their hardware, as in the established deployment model for OpenCL applications.

### Invoking `--acpp-deploy`

A deployment package can be generated using `acpp --acpp-deploy=/my/deployment/path` (a `<component>:` prefix such as `all:` is still accepted, for compatibility). For example, 

```
acpp --acpp-deploy=/my/deployment/path
```

will deploy the toolchain's installed manifest to `/my/deployment/path`. You should then be able to run your binary from there directly, with no environment setup.

**Note that for a successful deployment, AdaptiveCpp must have been built with the respective backend enabled!** We can only deploy what we have :-)

## Limitations and handling indirect transitive dependencies

The deployment includes:

* AdaptiveCpp runtime libraries
* AdaptiveCpp runtime backends
* Infrastructure for the JIT compiler, including bitcode libraries and, in toolchain mode, the needed LLVM components
* Backend-specific dependencies (e.g. needed CUDA runtime libraries, necessary components from ROCm etc)

However, for LLVM and backend dependencies, AdaptiveCpp cannot know in detail how exactly those were built and which transitive dependencies these may have in all cases.
The AdaptiveCpp deployment mechanism includes needed dependencies for common setups, but this may be insufficient depending on how self-contained you would like your package to be.

After a successful deployment, `acpp` will recommend that you run a command to check for dependencies outside of your deployment tree. This command will look similar to

```sh
ldd `find /some/deployment/path -type f ! -name '*.bc'` | grep -v /some/deployment/path | awk '{print $3;}' | sort | uniq
```

Libraries listed by this command are additional transitive dependencies of libraries in the deployment tree that you may want to consider including as well.

However, you should **not** include the following libraries:
* Core system libraries: `libc`, `linux-vdso`
* `libcuda.so`, as it is provided by the NVIDIA graphics driver and needs to match it
* `libdrm*`, as it too is part of the graphics driver stack.

When adding dependencies by hand, put them beside the runtime in the deployment's library directory.

## Decreasing the size of the deployment package

The size of the deployment package is typically strongly dominated by the size of `libLLVM.so` (part of the deployment only in toolchain mode), which on its own can reach around 150MB in size.

The `hip` deployment component specifically is expected to pull in a library from ROCm (`libamd_comgr`) which may be statically linked against ROCm's LLVM and might thus again be around another 150MB in size.

A deployment package for all components/backends is therefore expected to be at a little over 300MB in size. Attempts to optimize this should focus on libLLVM, and if the `hip` component is included, on comgr.

Two ways to improve on this are:
1. LLVM, as shipped by many distributions, typically includes support for all available compiler backends for cross-compilation use cases. However, AdaptiveCpp only needs the backend for the host CPU (e.g. X86), NVPTX, AMDGPU and potentially spir64. So, building a custom LLVM with only these backends enabled might reduce binary size.
2. A very quick, convenient and highly effective solution is to use a binary packer like e.g. [upx](https://upx.github.io/), which can compress libraries transparently such that they automatically decompress in memory when they are needed. upx-compressed libLLVM often achieves compression rates of around 40% and can thus almost cut the size of the deployment package in half!


## Forward compatibility and updating the deployment package

When deploying applications to end users, it is typically desired that the application should continue to work if the user upgrades their hardware, potentially even to hardware that was not available yet when the application was originally distributed.

This notion of forward-compatibility is currently supported to the following extent:

* OpenMP CPU backend: Yes, however performance may not be ideal if AdaptiveCpp's LLVM is too unfamiliar with the CPU architecture (same as with regular C++ applications when the compiler is too old).
* CUDA backend: Yes, however this is only lightly tested at the moment.
* OpenCL backend: Yes, without limitations.
* HIP backend: Due to lack of forward compatibility in ROCm, AdaptiveCpp can only target those AMD GPUs that are supported by the ROCm version it was built against.

In many cases, it is possible to simply generate a new deployment package with newer, updated backend dependencies and use the new package without recompiling the application.
In order to achieve this, rebuild the same AdaptiveCpp version against the updated dependencies (e.g. ROCm) and rerun deployment. The new package may the be distributed to users.

### Upgrading the HIP deployment package
It is possible to update the HIP deployment package with support for newer hardware, and provide the user with the updated package. For example, you could rebuild AdaptiveCpp against a newer ROCm version, rerun deployment for the HIP component and give users the updated package.
The same, unmodified application should then be able to run on the new hardware.

### Upgrading the CUDA and OpenCL package

You can also upgrade the CUDA and OpenCL deployment packages, however this should rarely be necessary since those platforms already provide good forward compatibility.

### Upgrading the core package and LLVM

The same is possible with LLVM updates, *if* your AdaptiveCpp version already supports the newer LLVM version that you want to target.
**It is however not in general possible to update the AdaptiveCpp version without recompiling the application, because the AdaptiveCpp runtime is not guaranteed to have a stable ABI!**
So, if the version of AdaptiveCpp that you have built the application binary with does not yet support the LLVM that you want, then you will have to update AdaptiveCpp itself, recompile the application, and provide users with the new binary.

### Clearing the JIT cache

After an update of the deployment package, it might be a good idea to instruct users to clear the AdaptiveCpp JIT cache (or have some install wizard do this) to avoid outdated kernels being passed to drivers.

## CUDA redistribution

Note that the deployment mechanism pulls in components from backends which, in the case of CUDA, are not under an open source license. However, all CUDA components utilized by AdaptiveCpp and deployed as part of the deployment mechanism are explicitly cleared for redistribution in the [CUDA EULA](https://docs.nvidia.com/cuda/eula/index.html#attachment-a).
Nevertheless, you may still want to be aware that portions of the software distributed by you may be covered by the CUDA EULA terms.

## Vector math library redistribution

The deployment mechanism may include and redistribute third-party libraries under the following licenses:

- Intel Short Vector Math Library (`svml.so` & `intlc.so`)
  Provided under the [Intel End User License Agreement (EULA)](https://www.intel.com/content/www/us/en/content-details/777700/intel-end-user-license-agreement-for-developer-tools.html)

- Arm Performance Libraries Math Library (`amath.so`)
  Provided under the [Arm Performance Libraries End User License Agreement](https://developer.arm.com/documentation/109611/1-0/End-User-License-Agreement--EULA-?lang=en)

- SLEEF Vector Math Library (`sleef.so`)
  Provided under the [Boost Software License, Version 1.0](https://www.boost.org/LICENSE_1_0.txt)

SVML and AMATH are nonpermissive vendor units in the fork: they ship only under `full`, once `ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN` is on, and never under `full-permissive-only`. SLEEF is permissive and ships under both `full` and `full-permissive-only`.
