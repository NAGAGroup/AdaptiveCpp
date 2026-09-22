# The configuration model

This document is the authority on how the fork's configuration, manifests and
deployment work. It defines vocabulary, the entry schema, the four deployment
strategies, the manifest format, the application configuration discovery
mechanism, and how vendor libraries reach a deployed application. Source code
that contradicts this document has a defect; this document does not compromise
to match the source.

## The source tree

Configuration and manifests are source files split by platform, architecture
and compilation flow, merged into one installed configuration per toolchain.
A flow whose dependencies were not found produces no installed file; absence
is what says "this toolchain cannot do that".

```
cmake/discovery.cmake                       every core find, split by build mode
cmake/discovery/<backend>.cmake             conditional sub-files per vendor
cmake/options/<platform>/<arch>/core.cmake  declarations that consume ACPP_DISCOVERED_*
cmake/options/<platform>/<arch>/<flow>.cmake
config/<platform>/<arch>/core.json
config/<platform>/<arch>/<flow>.json
config/<platform>/<arch>/deploy/core.json
config/<platform>/<arch>/deploy/<flow>.json
```

The eight upstream compilation flows are all in scope: `omp.library-only`,
`omp.accelerated`, `cuda.integrated-multipass`, `cuda.explicit-multipass`,
`cuda-nvcxx`, `hip.integrated-multipass`, `generic` (which splits further into
`generic-<backend>` because only backends present when the toolchain is built
are supported), and a `common` file for content shared across the matrix,
factored last after every flow file exists.

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
  `acpp_declare_provenance`, one variable each.

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

Under `default` both sides are the discovered absolute path. Under the
placeholder strategies they are the same relative location from two roots:
`{{ toolchain-path }}/{{ llvm-deploy-path }}/bin/clang++` and
`$ACPP_PATH/{{ llvm-deploy-path }}/bin/clang++`.

## The deploy layout decides everything

**`*_DEPLOY_PATH` is the publisher's, set when building the toolchain.** It
says where something lands in a deployed application, baked into our RUNPATH
and written to the configuration. Discovery never touches it.

**Path entries are derived from it.** Under the placeholder strategies the
toolchain's own tree has the same shape as a deployment, so "where is LLVM in
the toolchain" and "where does LLVM land in an application" are one question
from two roots. Only under `default` does discovery answer instead.

**A resource value is builder-overridable only under `default`.** Choosing any
other strategy is a commitment that the package contains what it needs; paths
follow from the layout rather than being set one at a time. A `-D` outside
`default` is a fatal error naming the deploy path to set instead. A user of
the installed toolchain can still override anything through the environment.

**No facts are computed in an options file.** `acpp-libdir` comes from
`@CMAKE_INSTALL_LIBDIR@`, `llvm-libdir` from `@LLVM_LIBDIR@` (which
`discovery.cmake` sets), the versions from theirs — straight into the stub,
because nothing in the options file chooses them.

**Options load after `discovery.cmake`**, which hoists every `find_*` to one
place. Discovery exports `ACPP_DISCOVERED_*` — a stated interface rather than
reaching into whichever variable a particular find happened to use.

## The four deployment strategies

The strategy decides two things and nothing more: the initial values written
into the installed configuration, and whether `cmake --install` copies
external assets in. It says nothing about how a later deployment behaves.

| | values | install copies | deploy copies |
|---|---|---|---|
| `default` | absolute | nothing | nothing; writes a configuration only |
| `managed` | placeholder | nothing | `internal`, `llvm` when we built it |
| `full-permissive-only` | placeholder | permissive | + `llvm` always, `external-permissive` |
| `full` | placeholder | everything | + `external-nonpermissive`, behind the gate |

Three audiences:

- **The toolchain packager** chooses the strategy when building the toolchain.
  `default` is the same-system case. `managed` is `full` minus cmake copying
  vendor libraries at install, because the publisher's package manager delivers
  them into the built layout — the conda scenario, where external dependencies
  arrive as conda packages. The publisher sets `ACPP_LLVM_DEPLOY_PATH` and
  similar knobs to match the layout that results once all bundled items are in
  place. `full` and `full-permissive-only` are the easy path: defaults work,
  cmake installs external dependencies alongside, deployment is straightforward
  for the publisher's users.
- **The toolchain user** compiles applications and may deploy them. A
  `managed` toolchain's users may switch it into `full*` deployment — `acpp
  --acpp-deploy` then copies the conda-prefix LLVM into the application's
  deployment at the layout the rewritten ELFs expect.
- **The application user** runs the deployed application. They have no knobs.

`full-permissive-only` exists so that wanting a self-contained toolchain does
not require opting into a legal decision you are not making: a gate everyone
sets protects nobody.

The gate is `ACPP_ALLOW_NONPERMISSIVE_SHIPPED_WITH_TOOLCHAIN`; its failure
message lists the resolved `external-nonpermissive` rows.

`RUNPATH` is the layout: it is derived from `*_DEPLOY_PATH` knobs, not
configured independently. Anything not reachable from `$ORIGIN` is found by
the loader's own mechanisms (`ld.so.cache`, `LD_LIBRARY_PATH`), which is
unsupported territory — the design serves what it can predict.

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
headers, executables the JIT does not invoke. `llvm` is its own category
because the rule is "we copy LLVM when we built it, or when you asked for
everything" — provenance, not licence.

**LLVM deploys as a unit** under `llvm-deploy-path`, preserving its internal
bin-to-libdir relationship, because its binaries carry their own RUNPATH.
The default is mode-branched: linked build → `.`, plugin build →
`{{ acpp-libdir }}/hipSYCL/ext`. Both build modes (plugin ext-shaped, linked
dot-shaped) are in scope.

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
layers are not rows.

**Flows without a vendor unit.** The omp flows carry no unit and no
manifest: the CPU backend is internal and libomp is the LLVM unit's, both
already in core's manifest. The flow contributes only the driver's link
line and compile flags, per platform because the OpenMP flag is the
platform's.

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

1. `$XDG_CONFIG_HOME/AdaptiveCpp/app-cfgs/<name>.cfg`
2. The system configuration directory (`/etc/AdaptiveCpp/app-cfgs/`; Windows
   and macOS equivalents are deferred until those platforms are reached)
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
- **Windows and macOS system configuration directories** are decided when
  those platforms are reached in the vendor campaign.
