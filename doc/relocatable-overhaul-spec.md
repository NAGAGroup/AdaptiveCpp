# Relocatable toolchain: specification

How AdaptiveCpp locates every external resource, how that behaviour is
configured, and what a deployed application carries with it. This is
normative: where the code and this document disagree, the document is the
defect report.

The as-built state this replaces is recorded in
[path-resolution-ledger.md](path-resolution-ledger.md).

## 1. Scope

### The principle

**A decision made when the toolchain is built belongs in a configuration
file, not in a binary.** As much as is possible and reasonable moves out of
compile definitions and into configuration.

Two reasons, and neither of them is relocatability on its own:

- **A compiled-in value cannot be overridden.** It forces every install
  built from that source to behave identically, and a user who needs
  something else has no recourse short of rebuilding a compiler.
- **A compiled-in value cannot be inspected.** How the driver and the JIT
  will behave becomes unreadable — the answer is a string literal in
  `.rodata` rather than a line in a file the user can open.

Upstream already applies this to much of what the driver does: the link
lines, the compiler flags, the default target list and the dry-run and
save-temps defaults are all configuration entries rather than macros, and
the CUDA entries even resolve their own placeholders at read time. That part
of the design is right and is **not being redesigned** — it is the model
being extended, using the machinery already there. The only existing entries
this touches are the ones whose values embed build-machine paths (§12);
everything else is left exactly as it is, and what grows is the *number* of
keys, as decisions come out of binaries and into the files.

### Where "reasonable" stops

The presumption is that a value moves. The one class that does not is a
definition that selects **which code is compiled** — a macro guarding a
`#ifdef` cannot become a run-time value without compiling both sides.

That presumption is rebuttable in both directions, and unclear cases are
discussed rather than quietly excluded. Some of today's `#ifdef` guards
*should* become run-time choices: `SVML_AVAILABLE` compiles out a code path
because the build machine lacked a library, which is precisely a decision a
deployed application should be able to make for itself.

### What this overhaul is therefore about

1. **Build-machine discovery frozen into a binary.** What cmake found while
   configuring must not survive into a shipped artifact — neither a path
   that names the build machine, nor the fact that a library happened to be
   present, nor the name it happened to have.
2. **What resolves a value at run time.** Every entry resolves through one
   documented mechanism, and an environment variable reaches all of them.
3. **What a deployment carries.** Which files are copied beside an
   application, and what its configuration says about where they are.

## 2. The three states

Resolution happens in three states. Each name carries its own subject,
because the failure mode is a reader assuming the wrong one. Use these
words:

- **when building the toolchain** — AdaptiveCpp itself is compiled and
  installed. The only state in which cmake exists.
- **when driving the toolchain** — `acpp` compiles a user's program. The
  driver resolves settings and sets compiler and linker flags.
- **when running an application** — a program built with acpp executes, on a
  machine we may never see. The JIT runs here, so this state compiles too.

Never write bare "compile time" or "run time". If either appears, the
vocabulary has slipped and the sentence is ambiguous.

## 3. Principles

**P1. No path is compiled into a binary.** Not as a compile definition, not
as a default, not as a fallback. A path that appears in a shipped artifact
appears only in a configuration file, which is text and can be corrected
without a rebuild.

**P2. There are exactly two configuration files, and they never see each
other.**

| | written by | read by | when | location |
|---|---|---|---|---|
| toolchain config | cmake, at install | the `acpp` driver | driving the toolchain | the toolchain installation |
| application config | the deploy helper | our libraries and the JIT | running an application | beside the deployed application |

**P3. An application never reads the toolchain config.** A deployed
application does not require a toolchain to be installed, and cannot
silently inherit one.

**P4. The application config is derived from the toolchain config** by the
deploy helper, according to the deployment strategy (§7). A user may
hand-edit it, and thereby owns the result.

**P5. Everything reached when running an application goes through a
loader.** No vendor SDK appears as `DT_NEEDED` in any AdaptiveCpp binary. A
thin loader library per backend reads the application config and loads the
real implementation. This is the architecture OpenCL and Level Zero already
use.

**P6. Application-side lookup is loader-relative, never
executable-relative.** Resolution uses `dladdr` on our own symbol, so a SYCL
application shipped as a shared library — a Python extension module, for
example — finds its configuration beside the AdaptiveCpp libraries rather
than beside the host interpreter.

**P7. A missing resource is diagnosable, never mysterious.** Where a
resource is required for an operation, failing to resolve it is an error
that names the configuration key. Where its absence is a valid state — no
vector math library was selected, a backend's runtime is not installed on
this machine — the resolver reports it as unset and the caller decides.
AdaptiveCpp already ignores a backend it cannot load and continues; that
behaviour is correct and is preserved.

**P8. One stem serves every surface.** A resource has one name, from which
its driver flag, environment variable and configuration key follow
mechanically (§4). A setting reachable only by editing a file is not a
setting.

**P9. Relocatability is declared, not inferred.** The deployment strategy
(§7) states what kind of artifact is being built, and everything else
follows from it. A toolchain is not accidentally relocatable, and a
`default` toolchain that is moved fails loudly rather than half-working.

## 4. Naming, and the two key conventions

**Neither file changes format.** Both already exist, both already work, and
this overhaul uses them as they are. What it does is *add* keys, so that
things currently frozen into binaries become loadable, and *correct* the
values of existing keys where §1 requires it. Nothing is renamed, nothing is
reformatted, and no parser changes.

**The toolchain configuration** is the driver's JSON in `etc/AdaptiveCpp/`
— one file for core and one per backend, flat-merged into a single key
space. Every entry carries what a reader needs to act on it:

```json
"default-cuda-lib-path": {
  "value": "<written at install>",
  "envvar": "ACPP_CUDA_LIB_PATH",
  "is-deployed-to-app": true
}
```

`value` is the only field the toolchain install writes. `envvar` names the
environment variable that overrides the entry, so an entry is never
reachable by file-editing alone. `is-deployed-to-app` says whether the
deploy step carries the entry into a deployed application.

**These files are source files in the tree**, one for core and one per
backend, checked in with `"value": "stub"`. Installing the toolchain copies
the enabled set and replaces each stub with the value the build resolved.
The key vocabulary is therefore readable in the repository rather than
assembled by string-building in cmake, and adding a key is editing a JSON
file rather than editing a generator.

**The application configuration** is `acpp-config.cfg` beside the program,
`<environment-variable>=<value>`, one per line. Its keys are environment
variable names, because `common::settings` looks them up that way.

**The deploy step is the join between the two.** It takes every toolchain
entry marked `is-deployed-to-app`, writes it under the name in its `envvar`
field, and sets the value according to the deployment strategy (§7). That is
the whole derivation; no separate mapping table exists or is needed.

`HIPSYCL_` and `OPENSYCL_` aliases keep working in both files.

## 5. Categories

Every option has exactly one category. The category determines how cmake
populates the default value and whether the cache variable is force-set. It
does not restrict the user: every entry in a configuration file is
modifiable text, and all three categories resolve identically when driving
or running.

**`external-resource`** — a path to something outside our install tree: a
vendor toolkit, a system library, device bitcode we do not ship. The cache
variable is not force-set, so a builder can override at configure time. Its
default is written by one rule, which covers every case:

| strategy | `find_*` found it | `find_*` did not |
|---|---|---|
| `default` | the absolute discovered path | the declared default |
| `bundled`, `full` | the declared default | the declared default |

A value the builder passed on the cmake command line outranks both rows: it
is used verbatim, and may itself contain placeholders. The declared default
is written in placeholder form — `$ACPP_PATH/targets/$ACPP_TARGET/lib` —
and is the same string the deploy step uses as a destination under `full`,
so where a resource *will be* and where it *gets copied to* cannot drift
apart.

Discovery is one-directional: an option's value never feeds back into the
`find_*` call. Discovery answers what is on the build machine; the option
decides what the installed configuration says.

The entry therefore always has a value, and where cmake happened to find the
resource on the build machine is irrelevant except in `default`. A value
that points at nothing is not an error: the resource is simply absent, which
P7 already covers.

**`behavior`** — a non-path choice: which vector math library to use, which
deployment strategy to use. The default is a fixed value chosen by this
specification. Not force-set.

**`toolchain-resource`** — a path to something we ship: our bitcode, the
SPIR-V translator, the LLVM tools, the clang drivers. The default is the
install location the build itself produced, written with the `$ACPP_PATH`
placeholder. The cache variable is force-set, because overriding it would be
lying about where our own install tree places a resource. A builder can
still alter the install layout through cmake's own install machinery; the
forced value tracks that layout.

## 6. Placeholders and resolution

### The placeholders

There are exactly two **core placeholders**:

- **`$ACPP_PATH`** — the install root. It means the toolchain's install
  directory when driving, and the application's own directory when running.
  Both are discovered at read time, never recorded: the driver from its own
  location, our libraries via `dladdr` (P6).
- **`$ACPP_TARGET`** — the target subdirectory name for vendor resources,
  spelled the way CUDA and conda-forge spell it: `x86_64-linux`. It is
  **not** an LLVM triple and not a conda subdir, and the spec borrows the
  vocabulary deliberately so our layout matches the ecosystem's (§8).

A configuration entry may additionally reference **another configuration
entry** by name, so a link line reads
`-L$ACPP_CUDA_LIB_PATH -lcudart` and resolves through the entry it names.

### Nested indirection is not allowed

An entry may only reference an entry whose own value contains at most core
placeholders. Chains are rejected when the configuration is emitted, with a
message naming both entries and this rule, because cmake sees the whole set
and can prove it. In practice this means a layout string is spelled out
rather than composed: `ACPP_CUDA_LIB_PATH` is
`$ACPP_PATH/targets/$ACPP_TARGET/lib`, not `$ACPP_CUDA_TARGET_DIR/lib`.

### Resolution is two passes

1. Expand core placeholders.
2. Expand entry references, using the results of pass one.

The ban above is what makes two passes sufficient. The same two passes run
on both sides — in the driver over the toolchain config, and in our
libraries over the application config — and they are one algorithm
implemented twice, not two algorithms.

### The chains

When **driving the toolchain**:

```
command-line flag  →  environment variable  →  toolchain config
```

When **running an application**:

```
environment variable  →  application config
```

There is no third tier and no machine-wide fallback. What happens when
nothing supplies a value is P7's question, not this section's.

## 7. Deployment strategies

The deployment strategy declares what kind of artifact is being produced. It
is a `behavior` option, `ACPP_DEPLOYMENT_STRATEGY`, chosen when the
toolchain is configured, written into the toolchain config, and overridable
afterwards by editing that file or by setting the environment variable.

**The strategy governs the toolchain and the applications it builds
alike.** One toolchain does not hold two intents; that is a simplification
we take deliberately, and the post-install override is what makes it
affordable.

It affects exactly two things: what cmake writes into the toolchain config,
and how the deploy helper behaves. It does not change how the toolchain is
built, linked, or how its own dependencies are found.

### `default`

**Intent: a non-relocatable application install against a durable toolchain
install on the same system.** For someone building for themselves, and for
distribution packagers whose install tree is identical on every machine.

*Toolchain config:* every value fully expanded to an absolute path. No
placeholders survive.

*Deploy:* nothing is copied but the application configuration, itself fully
expanded, pointing back into the toolchain's own tree.

### `bundled`

**Intent: redistribution, where a package manager — a tool or a human —
provides everything that is not ours.** The deployed application is scoped
to its own prefix and uses only what is in it. This is the conda model.

*Toolchain config:* `$ACPP_PATH` and `$ACPP_TARGET` throughout. External
resources are written to their **expected in-prefix location by convention**
(§8), not to wherever cmake discovered them at build time. The toolchain
therefore also expects its own vendor dependencies in its own prefix, which
is what its package manager provides.

*Deploy:* copies `core` — a hard requirement of every application — plus the
components the packager selects. Everything else must be supplied by the
prefix. The application config uses placeholders throughout.

### `full`

**Intent: redistribution, self-contained.** The deploy helper is the
application's package manager.

*Toolchain config:* identical to `bundled`. The only install-time difference
between the two strategies is the value of `ACPP_DEPLOYMENT_STRATEGY`
itself.

*Deploy:* copies `core` plus every runtime asset the manifest names that
exists on the packager's machine, external resources included. An asset that
cannot be found is skipped with a warning rather than a failure, and the
run leaves a summary of what was and was not bundled. The application config
uses placeholders throughout.

### Common to all strategies

- Deploy always begins by resolving the toolchain config completely —
  environment variables, core placeholders, entry references — and then
  writes each entry either expanded or placeholder-relative according to the
  strategy. Every override combination is therefore well defined.
- Deploy skips any file already present at the destination, so a package
  manager that already provides a component is not overwritten. Skipping is
  by existence, not by identity (P1).
- Deployed binaries carry `$ORIGIN`-relative rpaths. Running a deployed
  application never requires setting `LD_LIBRARY_PATH`.
- The deploy helper accepts an optional user-supplied configuration file
  whose entries take precedence over the generated ones on any clash.
- Its summary names bundled **vendor** assets as their own category,
  separate from ours, so whoever ships the result has a concrete list to
  hand their own users (§9).
- For cmake users, `add_sycl_to_target` arranges deployment so no explicit
  step is required.

## 8. The install layout

The deploy manifests give the location of every resource relative to the
install root. They are separate from the configuration entries: entries are
resolution knowledge (what keys exist, how they resolve), a manifest is
deployment knowledge (what gets copied, where it goes).

Like the configuration files, **the manifests are source files in the
tree**, one per backend, and the install step copies the enabled set and
fills their stubs. Rows name resources by placeholder — `$ACPP_PATH/...` for
ours, `$ACPP_CUDA_LIBRARY_DIR/...` for a resource an entry already locates —
so a manifest carries no absolute path from the build machine.

Files are grouped under the base they are relative to, so a base is stated
once rather than repeated per row:

```jsonc
{
  "deployed-libs": {
    "toolchain-libdir": "lib64",   // filled at install
    "files": [ ... ]               // relative to toolchain-libdir
  }
}
```

`toolchain-libdir` is a **fact about the installed toolchain** — whether
this build produced `lib`, `lib64`, or whatever a distribution chose — and
it is filled at install by the same stub replacement that fills the
configuration files. The build is the only thing that knows it, so the build
is what records it. The deploy step never searches for it.

`ACPP_LIBDIR`, in the toolchain configuration, is a different thing: it is
**the library directory a deployed application should use**, relative to
`$ACPP_PATH`. It lives in the toolchain configuration because it is a
setting about the deployments this toolchain produces, not a description of
the toolchain itself. Its default is what the toolchain was installed with,
and a user — or a publisher, before shipping — may change it.

Deployment is then the composition of the two: read where the files are from
the manifest, read where they go from the configuration, and copy, keeping
each file's path relative to its base. A toolchain installed with `lib64`
deploying under an `ACPP_LIBDIR` of `lib` simply lands them in `lib`.

The layout has **two zones**:

- **Ours, at the prefix root** — `$ACPP_PATH/lib/hipSYCL/...`, our runtime
  and backend libraries, our bitcode, the LLVM tools, the SPIR-V
  translator.
- **Vendor resources, under `$ACPP_PATH/targets/$ACPP_TARGET/`** — the CUDA
  and ROCm runtime libraries and device bitcode, laid out the way CUDA's own
  installer and conda-forge lay them out.

The second zone works precisely because **nothing links against it**. Every
resource there is reached by a `dlopen` on a path resolved from the
configuration, through the thin loaders of P5, so no ELF has to record the
layout and no rpath has to follow a `$ACPP_TARGET` a user may change.

That gives the rule for the leftovers: anything still carrying a
`DT_NEEDED` — `libLLVM`, `libomp`, `libnuma` — is deployed **beside our own
libraries**, where `$ORIGIN` already reaches it, never into the target zone.

### The vendor loaders

The thin loader libraries of P5 live at
`$ACPP_PATH/lib/hipSYCL/vendor-loaders/<vendor>/`, one directory per vendor
so that a deploy manifest can select them per backend — which is what
`bundled` needs when a packager takes CUDA but not ROCm.

**They get no configuration entries.** A loader is always installed in the
same place as the rest of the toolchain, so an entry naming its location
could only ever be configured wrong; it is found the way our bitcode is,
relative to the library asking for it.

The direction is the other way round: **a loader reads entries.** It
resolves the configuration entry for the vendor library it fronts, and if
that entry names nothing present on this machine, it reports the backend as
unavailable and the runtime continues without it — the graceful degradation
AdaptiveCpp already performs for a backend it cannot load (P7). Only when
the entry resolves to something on disk does it `dlopen` it.

A loader must **never carry the soname of the library it fronts**. It
exports the vendor's symbol names by design, so a loader also named
`libcudart.so.12` would be a candidate to satisfy its own dependency, and
anything reading `ldd` output would be told a falsehood.

**The OpenCL ICD loader and `libze_loader` are vendor libraries for this
purpose too.** They are loaders in their own right — that is why those two
backends already have the architecture P5 describes — but from our side they
are still `DT_NEEDED` dependencies found wherever the build machine happened
to have them. A backend that a deployed application can use is a backend
that `full` can deploy, so each gets a configuration entry naming it and a
loader of ours in front of it. The recursion is only apparent: ours resolves
a path from the configuration, theirs discovers drivers on the system.

Directory names come from `GNUInstallDirs` rather than being rederived.

## 9. Vendor assets and redistribution

Some resources a deployment may carry are not ours to give away. The
manifest already reflects this in one direction — no driver library appears
anywhere in it, and the OpenCL rows name the ICD loader rather than any
vendor's driver — and that must stay true.

Copying vendor assets into the **toolchain's own install tree**, which
`full` implies, is a redistribution decision made by whoever builds the
toolchain. It is therefore gated: configuring `full` fails unless
`ACPP_ALLOW_SHIPPING_VENDOR_ASSETS_WITH_TOOLCHAIN` is also set. The failure
message lists the exact files that would be shipped — cmake has already
resolved them — so the choice is informed rather than a shrug at a boolean.

The documentation of that option is where the vendors' redistribution terms
are explained, NVIDIA's and Intel's in particular, because it is the one
place a toolchain builder is guaranteed to read before proceeding.

Beyond that gate, how a toolchain is *used* is not ours to police. A builder
who ships a `full` toolchain either changes the strategy it ships with or
tells their own users what it does.

## 10. What this deletes

- every path-valued compile definition
- `CMAKE_INSTALL_RPATH_USE_LINK_PATH`, which adds absolute link-time paths
- `ACPP_CONFIG_FILE_OMIT_ENVIRONMENT_PATHS` and every other switch that
  achieved relocatability by emptying a value: they scrub six standalone
  keys and miss the paths embedded in flag strings, and they produce a
  toolchain that cannot compile until the user supplies three environment
  variables
- `ACPP_CONFIG_FILE_GLOBAL_INSTALLATION` and the `/etc/AdaptiveCpp`
  fallback, which let a machine we do not control supply values silently
- bare configuration keys for path-valued settings: each becomes a full
  flag/environment/key triple, so `_config_db.get()` stops being the way a
  path is read. The version and plugin-capability keys keep reading straight
  from the configuration, because they are build facts with no flag and no
  environment variable by design
- `DT_NEEDED` entries on vendor SDKs, and with them the tight version pins
  that downstream packages must carry
- `default-use-bootstrap-mode`, a generated key with no reader anywhere

## 11. What this does not touch

Four things upstream already gets right, and a rewrite would break:

- `getBitcodePath()` asks the loader where our libraries are and derives
  the bitcode directory from that. No macro, no configuration entry, nothing
  to relocate.
- `HIPSYCL_RELATIVE_LLVMSPIRV_PATH` is relative by construction.
- `getLibMvecDir()` deliberately never records a path: libmvec is part of
  glibc, so the only correct copy is the one the loader resolves in the
  process doing the JIT. It is detected at build time and never deployed.
- The CUDA link line and compiler flags already use placeholders and name no
  build-machine path.

## 12. The work this requires

Independent of strategy, and in the source rather than in cmake:

- **Compile definitions converted to configuration lookups.** Measured
  against the tree, they fall into two groups.

  *Move to the configuration* — every one of these records something cmake
  discovered:

  | Definition | What it freezes |
  |---|---|
  | `ACPP_CLANG_PATH`, `ACPP_LLC_PATH`, `ACPP_LLD_PATH`, `ACPP_OPT_PATH` | where our tools were at build time |
  | `ACPP_LLC_NAME`, `ACPP_LLD_NAME`, `ACPP_OPT_NAME`, `HIPSYCL_LLVMSPIRV_NAME` | what those tools were called |
  | `ACPP_CUDA_DEVICE_LIBS_PATH`, `ACPP_ROCM_DEVICE_LIBS_PATH`, `ACPP_HIPCC_PATH`, `HIPSYCL_CLSPV_PATH` | vendor resource locations |
  | `SLEEF_AVAILABLE`, `AMATH_AVAILABLE`, `SVML_AVAILABLE` | that a library was present on the build machine |
  | `LIB_SLEEF_DIR`/`_NAME`/`_NAME_WE` and the AMATH, SVML and INTLC triples | where it was and what it was called |
  | `DEFAULT_VEC_MATH_LIB` (compiled into both `src/compiler` and `rt-backend-omp`) | which one was chosen |
  | `ROCM_CLANG_VERSION_MAJOR`/`MINOR`/`PATCH` | the build machine's ROCm version, inside the compiler component |
  | `ACPP_LLC_ADDITIONAL_FLAGS`, `ACPP_OPT_ADDITIONAL_FLAGS`, and the host CPU flags when `ACPP_HOST_FORCE_MCPU_TARGET` is set | JIT flags a deployed application cannot change |

  Three call sites — `LLVMToPtx.cpp` and `LLVMToAmdgpu.cpp` twice — use
  their macro raw, without placeholder expansion, and cannot carry a
  relocatable value at all until they are converted.

  `ACPP_LLC_HOST_CPU_FLAG` and `ACPP_OPT_HOST_CPU_FLAG` are **not** a
  defect in their default form: they hold `-mcpu=native`, which llc
  resolves on the machine running the JIT. Only the forced variant freezes
  an answer.

  **The vector math libraries are the worked example.** All three code paths
  compile unconditionally — the `#ifdef` guards go away entirely — and each
  library gets its own directory entry, populated by the `external-resource`
  rule in §5. Nothing about the build machine survives: whether SLEEF was
  present decides only what the installed configuration *says*, never what
  the binary can do. One entry per library, not the single
  `ACPP_VECTOR_MATH_LIB_DIR` that exists today, because the library is now
  chosen when the application runs and the resolver must be able to find
  whichever one is asked for — one entry per library, plus the existing
  `ACPP_VECTOR_MATH_LIB` entry naming which of them to use. The entries are
  **directory**-valued: the
  consumer in `LLVMToHost.cpp` needs only a directory, since the library's
  short name is already written into the source as `-lsleefgnuabi`,
  `-lamath` and `-vector-library=...`, so the `_NAME` and `_NAME_WE`
  definitions have no reason to exist at all.

  `LIB_NUMA_AVAILABLE` is the exception and stays: `rt-backend-omp` includes
  `numa.h` and links `${NUMA_LIBRARY}`, so a toolchain built without libnuma
  genuinely cannot compile that path.

  *Presumed to stay* — each selects which code is compiled, so it cannot
  become a run-time value without compiling both sides. The presumption is
  rebuttable per definition (§1), and this list is where that argument
  happens, not a settled exclusion:
  `HIPSYCL_WITH_SSCP_COMPILER`, `HIPSYCL_WITH_STDPAR_COMPILER`,
  `HIPSYCL_WITH_ACCELERATED_CPU`, `HIPSYCL_WITH_REFLECTION_BUILTINS`,
  `ACPP_LLVM_COMPONENT`, `HIPSYCL_COMPILER_COMPONENT`,
  `HIPSYCL_TOOL_COMPONENT`, `HIPSYCL_RT_HIP_TARGET_ROCM`,
  `HIPSYCL_RT_HIP_SUPPORTS_UNIFIED_MEMORY`, `ACPP_HIPRTC_LINK`,
  `CL_HPP_TARGET_OPENCL_VERSION`, `VK_ENABLE_BETA_EXTENSIONS`,
  `HIPSYCL_DEBUG_LEVEL`, the Windows portability trio, and LLVM's own
  `LLVM_DEFINITIONS`.
- The two-pass resolver, in the driver and in `common::settings`.
- Thin loader libraries per backend, so no vendor SDK is `DT_NEEDED`. CUDA
  needs two, HIP one.
- `ACPP_ROCM_CXX_FLAGS` referencing `$ACPP_CLANG_INCLUDE_PATH` instead of
  cmake's `${CLANG_INCLUDE_PATH}`, and the ROCm link line referencing
  `$ACPP_ROCM_PATH` instead of cmake's `${ROCM_PATH}` — the placeholder
  forms are already used on the same lines.
- Rpath, in one commit: `acpp-hcf-tool` and `acpp-pcuda-pp` have no rpath of
  their own and survive only on `CMAKE_INSTALL_RPATH_USE_LINK_PATH`, so
  deleting it breaks them the same instant.
- The deploy helper: strategy-aware behaviour, the user-override file, and
  the summary.
- Core's manifest copying both `libomp` and `libgomp` unconditionally rather
  than the one actually linked — upstream's own TODO.

## 13. Open

- Whether the deploy helper writes `acpp-config.cfg` itself, with the
  per-application `acpp-config-<name>.cfg` and the environment still
  overriding it at run time. That is the proposal; it adds no new file and
  cannot clobber a hand-written one, since the override flag is how a user's
  entries get in.
- Whether `core` keeps upstream's per-backend component selection at the
  command line, or is always everything the enabled backends need.
