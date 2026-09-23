# The configuration model

This document is the authority on how the fork's configuration, manifests and
deployment work. It defines vocabulary, the entry schema, the four deployment
strategies, the manifest format, the application configuration discovery
mechanism, and how vendor libraries reach a deployed application. Source code
that contradicts this document has a defect; this document does not compromise
to match the source.

## Fidelity and the prolog

**Fidelity.** The fork adds no functionality except relocatability and the
deployment mechanism; every backend's enable condition and discovery match
upstream's. This keeps the fork a drop-in: a user who never asks about
paths gets the toolchain upstream would have built. Where the fork departs,
it is deliberate and narrow; see below.

**The prolog.** Discovery runs first, then the fetches (some gated on
what discovery found), then the options files; below that the tree only
adds sources and install rules. A find must see the machine as it is, so
a fetched dependency never stands in for something the build machine must
have; and nothing finds or fetches once the options files have started
reading discovery's exports.

**Deliberate departures.**

- OpenCL's 2.1 version floor: upstream's OpenCL find carries no minimum
  version, so it finds Apple's 1.2 framework and later fails to link; the
  floor rejects it the same way on every platform (see the obligations).
- Plugin mode ships no LLVM pieces. Upstream's own core manifest lists
  `libLLVM`, `llc`/`opt`/`lld`, `omp` and `gomp` regardless of mode; here
  those belong to the machine (rule 2 under "The four deployment
  strategies") and are never rows.
- Toolchain mode's `cpu-cxx` is our own `clang++`. Upstream's equivalent,
  `CMAKE_CXX_COMPILER`, is the bootstrap compiler in every mode; here that
  is true only in plugin mode - toolchain mode builds its own compiler and
  drives with it.
- `default` deploys what we build. Upstream's `default`-equivalent writes
  a configuration and copies nothing; here rule 1 makes our own runtime,
  and LLVM when we build it, unconditional on strategy.

**Naming.** "Linked" is called toolchain mode in this document, for the
build that links AdaptiveCpp into the LLVM tools it also builds. A later
rename pass will give the cmake identifiers
(`LLVM_ADAPTIVECPP_LINK_INTO_TOOLS`) the same name; they keep their
current spelling until then.

## The source tree

Configuration and manifests are source files split by platform, architecture
and compilation flow, merged into one installed configuration per toolchain.
A flow whose dependencies were not found produces no installed file; absence
is what says "this toolchain cannot do that".

```
cmake/discovery.cmake                              every core find, split by build mode
cmake/discovery/<backend>.cmake                    conditional sub-files per vendor
cmake/options/common/core.cmake                    matrix-wide helpers, controls, JIT flags
cmake/options/<platform>/common/core.cmake         platform-wide deploy paths, resources
cmake/options/<platform>/common/<flow>.cmake       platform-wide vendor options
cmake/options/<platform>/<arch>/core.cmake         arch delta (wiring's include point)
cmake/options/<platform>/<arch>/<flow>.cmake        one-line include of the platform common
config/common/core.json                            matrix-wide configuration entries
config/common/<flow>.json                          matrix-wide flow entries
config/<platform>/common/core.json                 platform-specific core entries
config/<platform>/common/<flow>.json               platform-specific flow entries
config/<platform>/common/deploy/core.json          platform-wide deploy manifest
config/<platform>/common/deploy/<flow>.json
config/<platform>/<arch>/core.json                 arch-specific entries (if any)
config/<platform>/<arch>/deploy/core.json          arch-specific deploy rows (if any)
devops/verify/golden/<platform>/<arch>/            the full form of every installed file
```

The eight upstream compilation flows are all in scope: `omp.library-only`,
`omp.accelerated`, `cuda.integrated-multipass`, `cuda.explicit-multipass`,
`cuda-nvcxx`, `hip.integrated-multipass`, `generic` (which splits further into
`generic-<backend>` because only backends present when the toolchain is built
are supported).

### Common and the merge

**The tier rule.** A file lives at the highest tier at which it is
identical and present in every tree below it. `core` is the one file split
by content: helpers, controls, JIT flags and the platform-independent
driver defaults go matrix-wide; the platform's names, roots and resources
go platform-wide; the arch delta stays in the arch file. Every arch cmake
file exists, even when it is one `include` line — the wiring always
includes `cmake/options/<platform>/<arch>/<file>.cmake`.

**The merge.** One installed configuration per flow is the union of the
fragments that exist for it, in tier order: `config/common/`,
`config/<platform>/common/`, `config/<platform>/<arch>/`. A key present
in two fragments is a configure error. Deploy manifests concatenate each
group's array in tier order. An absent fragment contributes nothing.

**The proof.** `devops/verify/golden/<platform>/<arch>/` holds the full
form of every installed file. `verify-common` merges the fragments and
asserts JSON equality with the golden, so the goldens are the readable
whole and are updated when a change is intended.

**Platform and architecture axes.** The copies that existed before common
was factored are gone; what the machine changes is now visible as the arch
delta (`linux/x86_64`'s SVML resource and its deploy row), and everything
else is the platform's or the matrix's.

## Three syntaxes, three moments

| syntax | expanded by | when |
|---|---|---|
| `@ACPP_OPTION@` | cmake `configure_file` | when building the toolchain |
| `{{ entry-key }}` | the driver, to a fixpoint | when driving the toolchain |
| `$ACPP_PATH` | the C++ runtime | when running an application |

**Two roots, never one name.** `{{ toolchain-path }}` is the toolchain's own
root, found by the driver from its own location. `$ACPP_PATH` is the deployed
application's root. Neither exists in the other's world; a value naming the
wrong root is an unresolved-key error rather than a subtly wrong path. This is
a deliberate deviation from upstream, where `$ACPP_PATH` is expanded by both
the Python driver and the C++ runtime, silently meaning the toolchain when
driving and the deployment when running.

**Resolution is to a fixpoint.** Replace `{{ key }}` with its value repeatedly
until none remain; report a cycle if a pass makes no progress. There is no
chain ban and no fixed pass count.

**Manifests contain no `@` at all.** They are copied verbatim, never
configured, and resolve at deploy time from the configuration as it then
stands. A `@` in a manifest source file is always a bug. This is what makes
editing an installed configuration change deploy behaviour with no reinstall.

**In cmake, write `\$ACPP_PATH`** in quoted strings. An unescaped
`"$ACPP_PATH/..."` makes cmake attempt a variable reference — a warning now,
an error under `CMP0010 NEW`.

## The entry schema

```json
"vector-math-lib": {
  "value":  "@ACPP_VECTOR_MATH_LIB@",
  "envvar": "ACPP_VECTOR_MATH_LIB",
  "app": {
    "var": "ACPP_JITOPT_HOST_VECTOR_MATH_LIBRARY",
    "value": "{{ vector-math-lib }}",
    "runtime-configurable": true
  }
}
```

**Keys carry no prefix.** The old `default-*` prefix named a moment in a
value's history rather than the value itself, and it generated names like
`default-acpp-default-xdg-config-for-default-deploy`. Toolchain configuration
keys are read only by our own driver and runtime, both changing together; the
user-facing surface is the environment variables, which keep their spelling.

- **`value`** is the toolchain's own, filled when the toolchain is built.
- **`envvar`** is the name the entry answers to on the toolchain side. Its
  absence means the entry is a fact — nothing anyone could type would make it
  true, so there is no override channel.
- **`app`** present means the entry travels to a deployed application. `var`
  is the key the application reads (keyed by `ACPP_*` names, which is what
  `generate_configuration_identifier` builds). `value` is what gets written.
  `runtime-configurable` is documentation only — the runtime consults the
  environment before the file for every key, so nothing enforces it; real
  enforcement would live in the runtime's setting traits.

**Three kinds of entry:**

- **Choices** — `deployment-strategy`, `vector-math-lib`, the JIT flags.
  Have an `envvar`.
- **Dependency facts** — `llvm-libdir`, `llvm-version-major`, the version
  entries, `plugin-linked-into-llvm`. No `envvar`.
- **Provenance** — `llvm-path`, `libomp-path`, `libnuma-path`: where to copy
  from, read only by deploy. Single-sided: no `app` block, no
  `ACPP_TOOLCHAIN_`/`ACPP_APP_` pair; `core.cmake` declares them through
  `acpp_declare_owned_provenance` (what we build: `llvm-path` and
  `libomp-path` in toolchain mode) or `acpp_declare_provenance` (vendor
  plugins: `libnuma-path` always, `libomp-path` in plugin mode), one
  variable each.

## Two-sided resources

The device compiler is invoked by the driver when building the toolchain and by
the JIT when running an application. Those are different facts — the driver
runs from the toolchain on a developer's machine, the JIT runs from the
deployment on someone else's — so one value cannot describe both.

A resource declares both sides, filled by a pair of cmake variables:

```json
"device-clang-cmplr": {
  "value": "@ACPP_TOOLCHAIN_DEVICE_CMPLR@",
  "envvar": "ACPP_CLANG",
  "app": { "var": "ACPP_CLANG", "value": "@ACPP_APP_DEVICE_CMPLR@",
           "runtime-configurable": true }
}
```

Which shape a resource takes - discovered absolute, or the placeholder from
two roots - is decided by ownership, not `ACPP_DEPLOYMENT_STRATEGY`. See
"The deploy layout decides everything".

## The deploy layout decides everything

**Ownership decides a resource's shape, not the strategy.** Three kinds:

- **Ours** (rule 1): what we build. In toolchain mode that is the device
  compiler, `llc`/`opt`/`lld`, `cpu-cxx`, clang's resource directory and
  libomp; in every mode it is also `llvm-spirv` (our own translator, never
  LLVM's) and the plugin file. Always the deploy-layout placeholder, on
  both sides, in every strategy including `default` - a strategy is a
  commitment about assets we do not build, and these are not that. There
  is no `-D` override for the value; override the deploy path
  (`ACPP_LLVM_DEPLOY_PATH` and similar) if the tree differs.
- **The machine's** (rule 2): in plugin mode, the LLVM we did not build -
  the device compiler, `llc`/`opt`/`lld`, clang's resource directory, and
  `cpu-cxx` (`CMAKE_CXX_COMPILER`, the bootstrap compiler). Always the
  discovered absolute path, on both sides, in every strategy - nothing is
  deployed, so the JIT reaches the same machine copy the driver does.
  Empty and not an error when discovery found no plugin to build. Override
  through the underlying find's own cache variable (upstream's
  `CLANG_EXECUTABLE_PATH` is one such `CACHE STRING`), never through the
  resource's own name - there is nothing here for a publisher to commit to.
- **Vendor plugins** (rule 3): assets we never build, in either mode -
  CUDA, HIP, the OpenCL/Level Zero loaders, Vulkan, clspv, the HPC SDK
  runtime, SLEEF/AMATH/libnuma, and libomp *in plugin mode* (rule 4: it
  provides compute, so it is a vendor plugin there, not the machine's -
  in toolchain mode it is ours instead, above). Governed by
  `ACPP_DEPLOYMENT_STRATEGY`, `-D`-overridable only under `default`; see
  "The four deployment strategies".

**`*_DEPLOY_PATH` is the publisher's, set when building the toolchain.** It
says where something lands in a deployed application, baked into our RUNPATH
and written to the configuration. Discovery never touches it. This applies
to owned and vendor deploy paths alike; a machine resource has none, because
nothing of it is ever deployed.

**No facts are computed in an options file.** `acpp-libdir` comes from
`@CMAKE_INSTALL_LIBDIR@`, `llvm-libdir` from `@LLVM_LIBDIR@` (which
`discovery.cmake` sets), the versions from theirs — straight into the stub,
because nothing in the options file chooses them.

**Options load after `discovery.cmake`**, which hoists every `find_*` to one
place. Discovery exports `ACPP_DISCOVERED_*` — a stated interface rather than
reaching into whichever variable a particular find happened to use.

## The four deployment strategies

**Rule 1.** What we build is installed and deployed with apps in every
strategy, `default` included - it is always ours (see "The deploy layout
decides everything").

**Rule 2.** In plugin mode the machine's own toolchain - LLVM, `libLLVM`,
`clang`, `llc`/`opt`/`lld`, `cpu-cxx` (`CMAKE_CXX_COMPILER`) - is the
discovered absolute path in every strategy, never shipped, no manifest
row. A strategy governs assets we do not build; the machine's own
toolchain is never an asset we build.

The strategy governs only vendor plugins - assets we do not build (rule 3
above), and libomp specifically in plugin mode (rule 4). It decides two
things and nothing more: the initial values written into the installed
configuration for those assets, and whether `cmake --install` copies them
in. It says nothing about how a later deployment behaves, and nothing
about what we build or the machine's toolchain, which rules 1 and 2
already settled.

| | vendor values | install copies vendors | deploy copies |
|---|---|---|---|
| `default` | absolute | nothing | ours only |
| `managed` | placeholder | nothing | ours only; packager provides vendors |
| `full-permissive-only` | placeholder | permissive | + permissive vendors |
| `full` | placeholder | everything | + nonpermissive vendors, behind the gate |

Three audiences:

- **The toolchain packager** chooses the strategy when building the toolchain.
  `default` is the same-system case. `managed` is `full` minus cmake copying
  vendor libraries at install, because the publisher's package manager delivers
  them into the built layout — the conda scenario, where external dependencies
  arrive as conda packages. The publisher sets deploy-path knobs to match the
  layout that results once all bundled vendor items are in place; what we
  build already has its layout, unconditionally (rule 1). `full` and
  `full-permissive-only` are the easy path: defaults work, cmake installs
  external dependencies alongside, deployment is straightforward for the
  publisher's users.
- **The toolchain user** compiles applications and may deploy them. A
  `managed` toolchain's users may switch it into `full*` deployment — `acpp
  --acpp-deploy` then copies the conda-prefix vendor assets into the
  application's deployment at the layout the rewritten ELFs expect. Our own
  runtime, and LLVM when we built it, deploy the same way under every
  strategy already, because rule 1 settled that.
- **The application user** runs the deployed application. They have no knobs.

`full-permissive-only` exists so that wanting a self-contained toolchain does
not require opting into a legal decision you are not making: a gate everyone
sets protects nobody.

The gate is `ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN`; its failure
message lists the resolved `external-nonpermissive` rows.

**RUNPATH follows ownership.** Ours is `$ORIGIN`/`@loader_path`-relative
among our own binaries, in every strategy (rule 1). The machine's
toolchain, in plugin mode, is absolute (rule 2) - nothing of it is
deployed, so there is nothing to be relative to. A vendor's RUNPATH is
absolute under `default` and relative otherwise, derived from its
`*_DEPLOY_PATH` knob like everything else vendor (rule 3). Anything not
reachable from `$ORIGIN`/`@loader_path` is found by the loader's own
mechanisms (`ld.so.cache`, `LD_LIBRARY_PATH`), which is unsupported
territory — the design serves what it can predict.

## The manifest

Four categories, which are the copy policy:

```json
{ "internal": [ { "src": "{{ toolchain-path }}/{{ acpp-libdir }}",
                  "dest": "{{ acpp-libdir }}",
                  "files": ["SHARED_LIB:acpp-rt"] } ],
  "llvm": [...], "external-permissive": [...], "external-nonpermissive": [...] }
```

`src` is a directory named by an entry, `files` are relative to it, `dest` is
relative to the deployment root. `SHARED_LIB:` and `*` are the driver's
existing mechanisms. A group carrying `"toolchain-only": true` is installed
into the toolchain under `full*` and never deployed to an application —
headers, executables the JIT does not invoke.

**`llvm` is ours in toolchain mode, and only in toolchain mode.** It holds
what toolchain mode builds - the device compiler, `llc`/`opt`/`lld`,
libomp, clang's resource headers, `libLLVM` where a dylib is built - and
it is deployed in every strategy, `default` included (rule 1); it does
not exist in plugin mode at all, because none of that is ours to ship
there (rule 2). Every row carries an optional `"build-mode": "toolchain"
| "plugin"` key; a row without one applies in both modes. The installed
manifest holds only the rows whose build-mode matches
`LLVM_ADAPTIVECPP_LINK_INTO_TOOLS`, or carry none: the deploy engine
filters at configure time, the same way a flow's fragments are simply
absent when discovery found nothing for it.

**libomp splits by mode**, per rule 4: a `"build-mode": "toolchain"` row in
`llvm`, always deployed with it; a `"build-mode": "plugin"` row in
`external-permissive`, governed by `ACPP_DEPLOYMENT_STRATEGY` like any
other vendor plugin.

**`llvm-spirv` is ours in both modes.** AdaptiveCpp builds its own fork of
the SPIRV-LLVM-Translator (`doc/install-ocl.md`) and installs it under our
own library directory, `hipSYCL/ext/llvm-spirv/bin/`, independent of
`{{ llvm-deploy-path }}` - the machine's LLVM never supplies it, plugin or
not. Its row is `internal`, unconditional, no `build-mode` key.

**LLVM deploys as a unit** under `llvm-deploy-path`, preserving its
internal bin-to-libdir relationship, because its binaries carry their own
RUNPATH. The path defaults to `.`: toolchain mode is one prefix, one
tree. Plugin mode bundles no LLVM at all (rule 2), so the path is unused
there.

## Discovery

`cmake/discovery.cmake` hoists every `find_*` into one place. It opens with
the build mode: a fatal rejects component-without-linking (the one guard
kept from the cleanup). The linked half is derivation from the parent
build's install prefix. The plugin half is `find_package(LLVM CONFIG REQUIRED)`
and the associated find-programs. Both halves find the machine-level set
(numa, sleef, amath, svml, intlc). All exports are `ACPP_DISCOVERED_*`.

Options load after discovery; their declarations consume the `ACPP_DISCOVERED_*`
contract.

## Vendor library deployment

**`DT_NEEDED` records sonames, never paths.** At load time those names are
resolved in a fixed order — `DT_RPATH`, then `LD_LIBRARY_PATH`, then
`DT_RUNPATH`, then `/etc/ld.so.cache`, then the default directories — all
before any of our code runs.

**`$ORIGIN` in a RUNPATH is the one escape hatch** and it expresses exactly
one idea: relative to the object being loaded.

**There are no loader shims.** The two cases that occur in practice are already
served: a system install where `ld.so.cache` finds the vendor libraries, and a
prefix-shaped tree (conda, pixi) where they sit in `<libdir>`, which is what
`$ORIGIN/../` reaches. The third case, a vendor library at an arbitrary path,
is what `LD_LIBRARY_PATH` and `ld.so.conf` exist for. The diagnostic argument
for shims was also wrong: `common::load_library` already appends `dlerror()`,
so a missing vendor library is reported by name today.

**One `*_DEPLOY_PATH` knob per vendor**, in the same shape as
`ACPP_LLVM_DEPLOY_PATH`. Each vendor unit deploys whole under its deploy
path, default `{{ acpp-libdir }}/hipSYCL/ext/<vendor>`, in the vendor's own
relative layout as its find module reports it; nobody chooses that internal
layout. A `managed` publisher sets the knob to match the layout their
package manager produces. RUNPATH is derived from the deploy path and that
layout.

There is no vendor zone, no `ACPP_TARGET` (the vendor-zone placeholder is
gone; `ACPP_TARGETS`, the driver's `--acpp-targets` option, stays), and no
loader shims.

**The HPC SDK runtime is its own vendor unit**, `nvhpc`, distinct from the
CUDA toolkit. The redistributable subset is the SDK's `REDIST` directory.
It deploys with nvcxx-built applications because `nvc++` links them against
it. Under `full*` the packager's `nvc++` version travels with the toolchain
in those libraries, so a toolchain user's `nvc++` must match; nothing checks
that until the compatibility set. The nvcxx flow always has a CUDA toolkit
unit, because `rt-backend-cuda` is built against it; that unit may be the
SDK's bundled CUDA when only the SDK is installed.

**The HIP unit is TheRock's ROCm and only that**; classic `/opt/rocm` layouts
fail at configure. The unit carries the runtime libraries (`libamdhip64`,
`libhsa-runtime64`, `libamd_comgr`, `libhiprtc` and friends), the vendored
`rocm_sysdeps` dependencies, the device bitcode at
`lib/llvm/amdgcn/bitcode/`, and the headers (toolchain-only) at their real
relative paths. AMD's LLVM is not a row: nothing in the toolchain, the deploy
step or the JIT invokes it. The bitcode directory is target-neutral — the
same `.bc` files serve every gfx target — so the unit has no GPU-family
dimension. The unit is permissive. `hipcc` is absent because TheRock
deprecates it and upstream's own `377178f0` already removed the JIT's
use of it; the helpers it left behind were dead code and are deleted.

**Loader-only vendors** (OpenCL's ICD loader, Level Zero's loader) are
units of one library in the vendor's own library directory, permissive,
with no run-time resource because the runtime reaches them through
`DT_NEEDED`. The vendor's actual implementation (the ICD, the driver) is
never carried; where the loader looks for it is the user's environment,
not a configuration entry of ours. Level Zero's headers are the machine's,
build-only, a discovery requirement but not a row because nothing
user-facing includes them; the loader's optional validation and tracing
layers are not rows. The Vulkan loader is the same shape: a loader-only
unit, permissive, with the Vulkan headers and the static SPIRV-Tools
archive as build-only discovery requirements (never rows). Vulkan has no
multipass flow, so it carries no link line.

**Executable units** (clspv) are vendor units whose deployable is a
program the JIT invokes at application run time, not a library. The
executable is a two-sided resource (`ACPP_CLSPV`), and the compiler reads
it through `try_retrieve_settings_variable`. The unit deploys under
`{{ acpp-libdir }}/hipSYCL/ext/clspv` with its bindir, following the same
prefix-and-relative-path rule as the library units.

**Flows without a vendor unit.** The omp flows carry no unit and no
manifest of their own: the CPU backend is internal, already in core's
manifest. Upstream's CPU backend is unconditionally built, so omp is
core, not a vendor: the link line and compile flags live in each
platform's core.cmake, because the OpenMP flag is the platform's. libomp
itself splits by ownership (rule 4): ours in toolchain mode, a vendor
plugin in plugin mode - see "The manifest". The OMP flag follows the same
split: plugin mode is upstream's `DEFAULT_OMP_FLAG` exactly (`-Xclang
-fopenmp` when the machine's bootstrap compiler is AppleClang, else
`-fopenmp`); toolchain mode is plain `-fopenmp` always, because `cpu-cxx`
is our own `clang++`, never AppleClang. A user linking GOMP instead of
LLVM's libomp edits their own manifest; the fork does not choose between
OpenMP runtimes.

**Windows.** Vendor units on Windows hold their DLLs in the vendor's
bin-relative directory (deployable) and their import libraries in the
lib-relative directory (toolchain-only, needed only to drive the multipass
flows). The deploy path default is `{{ acpp-bindir }}/hipSYCL/ext/<vendor>`.
With no RUNPATH, the runtime's existing `AddDllDirectory` is the Windows
form of the derived RUNPATH, fed from the application configuration: each
vendor's DLL directory is a two-sided resource
(`ACPP_<VENDOR>_DLL_DIR`). `SHARED_LIB:<name>` resolves to `<name>.dll`
on Windows and the `files` entries in deploy manifests are
template-expanded like `src` and `dest`, so a versioned DLL like
`cudart64_12.dll` is written as
`"SHARED_LIB:cudart64_{{ cuda-version-major }}"`. Under clang-cl there
is no LLVM DLL (the tools are static), so the llvm group lists executables
(with `.exe`), `libomp.dll` and clang's resource headers. The HPC SDK
does not exist on Windows; TheRock's Windows layout is unread, so hip and
nvhpc are deferred. The Vulkan unit is the one loader-only unit whose
Windows shape differs: the SDK ships only the import library; the loader
`vulkan-1.dll` is the machine's (System32, installed by drivers or the
Vulkan runtime installer), so the unit deploys nothing on Windows and has
no DLL directory resource.

**macOS.** The RUNPATH form is `@loader_path`, the driver's shared-library
spelling is `lib<name>.dylib`, and the host JIT links Mach-O with
`ld64.lld`. Metal has no vendor unit: the runtime compiles MSL through the
system Metal framework at run time, so nothing external is deployed;
metal-cpp is a build-only discovery requirement (like Level Zero's headers)
and never a row. OpenCL is discovered on macOS as everywhere else; Apple's
framework is 1.2 and falls below the 2.1 floor, so it is not found. No
CUDA, Level Zero, HIP or NVHPC on macOS. The Vulkan unit on macOS carries the loader and
MoltenVK (the ICD, Apache-2) in its external-permissive rows; ICD
registration stays the user's environment, consistent with the OCL_ICD
ruling.

**Multi-pass is exempt.** In multi-pass, the vendor link line is on the
application's own link, so the application carries `DT_NEEDED` with whatever
RUNPATH its builder chose. By the time the runtime opens the backend, a
library with that soname is already loaded and the loader satisfies the
dependency from the loaded set without a filesystem search. In `generic`
nothing has loaded it, so the backend's dependency triggers a real search
resolved entirely by decisions frozen when the toolchain was built.

## Application configuration discovery

A deployed application must find the configuration written for it. Upstream's
`settings_config_file` singleton looks for `acpp-config.cfg` beside the host
executable, which fails whenever the SYCL code is not in the executable (a
Python extension module finds the interpreter's directory).

### The mechanism

**A binary carries one string: the app-config name.** Not a path, not a
location — one string, chosen by whoever built it, embedded at link time.

The name lives in a fixed-size padded field with a magic header, defined as an
**exported data symbol** by the identity translation unit that acpp generates.
Only executables and module libraries define the symbol; shared libraries
define nothing and are never patched.

### Runtime resolution

On first use, in order:

1. **Look the symbol up on the main program handle** through the loader
   (`dlopen(NULL)` / `dlsym` on Linux, `RTLD_MAIN_ONLY` on macOS,
   `GetModuleHandle(NULL)` + `GetProcAddress` on Windows, all via `common`'s
   `dylib_loader`). This is answerable before any static initializer anywhere
   runs because the executable is mapped first — load order does not matter.
2. **Otherwise, the name a module's constructor registered** when it was
   `dlopen`'d. Its constructor runs before any of its code.
3. **Otherwise, upstream's existing** `acpp-config.cfg`-beside-the-executable
   behaviour, so nothing that does not opt in changes.

Two registrations with different names in one process is the incoherence and
is reported at registration.

### One configuration per process

The configuration names the toolchain: which `llc`, which clang, which device
bitcode, which CUDA library directory. Two answers in one process means two
JIT toolchains compiling for the same devices — different CUDA runtime
versions, different device bitcode. That is not a case to support gracefully;
it is a case to detect.

### File search order

1. `$XDG_CONFIG_HOME/AdaptiveCpp/app-cfgs/<name>.cfg` (Linux);
   `$LOCALAPPDATA/AdaptiveCpp/app-cfgs/<name>.cfg` (Windows);
   `$HOME/Library/Application Support/AdaptiveCpp/app-cfgs/<name>.cfg`
   (macOS)
2. The system configuration directory: `/etc/AdaptiveCpp/app-cfgs/` (Linux);
   `$ProgramData/AdaptiveCpp/app-cfgs/` (Windows);
   `/Library/Application Support/AdaptiveCpp/app-cfgs/` (macOS)
3. Relative to our own library directory (found via `dladdr`)

User configuration beats system configuration, as everywhere else. A stray
file in `$XDG_CONFIG_HOME` can only affect applications carrying that name,
so name-keying already scopes it.

### Deployment

The deploy step reads the name out of the binary and may rewrite the padded
field while copying — never in place. This is safe in a way general binary
patching is not: the layout is ours, produced by our own toolchain, verifiable
before and after.

Under `default` nothing is copied, so there is no copy to patch. That is the
mode where a conflict remains possible and is reported.

### Who gets a name

- **An executable** gets one. The libraries deployed with it are patched to
  match.
- **A module library** gets one — it may be loaded by something that is not a
  SYCL application at all (Python being the obvious case).
- **A shared-library-only package** does not get one and carries no placeholder.
- **Command-line users**: an `acpp` flag decides whether to embed.
- **cmake users**: `add_sycl_to_target` takes `ACPP_APP_CFG_NAME` and nothing
  else.

### Platform pathway

- **Linux**: the driver adds `--export-dynamic-symbol` for the one name.
- **macOS**: kept through dead-strip.
- **Windows**: `dllexport` in the identity TU.

### Implementation status

None of this is implemented yet. Upstream's `settings_config_file` singleton
is what exists; it reads a flat `key=value` `.cfg` file beside the executable.

## Deferred

- **The compatibility set** is a later bonus: a link-time check in the acpp
  driver comparing header metadata compiled into object files against the
  toolchain's configuration facts. It is never an install-time or run-time
  check.
