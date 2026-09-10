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

**P1. No path is compiled into a binary we ship.** Not as a compile
definition, not as a default, not as a fallback. A path that appears in an
artifact of the toolchain build appears only in a configuration file, which
is text and can be corrected without a rebuild.

This governs **building the toolchain**. It says nothing about artifacts the
toolchain produces: what an application or library compiled with acpp
carries is its own question, answered by P6.

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

**P5. Everything *redistributable* reached when running an application goes
through a loader.** No redistributable vendor library appears as
`DT_NEEDED` in any AdaptiveCpp binary. A thin loader library reads the
application config and loads the real implementation. This is the
architecture OpenCL and Level Zero already use.

The exception is a **driver library**, and it is not a compromise. A GPU
driver's API library — `libcuda.so.1` — is never redistributable and is
installed with the driver itself, so there is no configuration a user could
usefully give us and nothing to relocate. `rt-backend-cuda` links it the
way any application built against a driver API links it, and that is the
only thing that makes sense. A loader in front of it would wrap the driver
API surface for no gain.

**P6. A binary compiled by acpp carries the identity of its own
configuration.** Not its location on any machine — two values, chosen by
whoever builds it: the configuration's **name**, and a **path to it relative
to the binary itself**. Both are set through an `acpp` driver flag, surfaced
as a cmake option through the toolchain's package configuration so that
`find_package(AdaptiveCpp)` users set it on a target.

The runtime therefore never guesses which configuration belongs to a binary.
It asks the binary that called into it — executable or shared library, it
makes no difference — and looks in two places, in order:

1. **The binary's own directory**, for a file of that name. This is what
   makes a build tree work, where objects and executables are commonly
   dropped into one directory.
2. **The relative path**, resolved against the binary's directory. This is
   the deployed case, and the relative path is the maintainer's statement of
   how their application or library will sit in an install tree.

The relative path is a choice about *their* layout, made by the person who
knows it, and it relocates with the tree because it is relative. Nothing
about the machine that compiled the binary is recorded either way.

The unit this identifies is a **deployment**, not a file: a package shipping
twenty shared libraries builds them all with one name and one relative path,
so they share one configuration. Two unrelated packages in the same prefix
choose different names and do not collide. A library that abstracts acpp
carries its own, and the applications that link it deploy nothing and need
to know nothing.

**Every object that reaches our runtime has an identity to be asked for.**
An object that includes a SYCL header is a SYCL object, so it is compiled
and linked by acpp, so it carries what acpp put there. The case that looks
like a gap — an application calling a library that wraps acpp — is not one:
that application includes no SYCL header, nothing of ours is inlined into
it, and the object at the boundary is the wrapping library, which has an
identity of its own. The question "what if the caller has none" does not
arise from either direction.

Because two such objects can share a process, the configuration a binary
gets is a property of that binary rather than of the process, and the
runtime holds them per object rather than in one global.

**P7. An unset entry falls back to the platform's own lookup.** A
configuration entry says *where* a resource is when we know something the
platform does not. When it says nothing, the answer is not failure — it is
to resolve the resource the way anything else on the system is resolved:

| the resource is | unset means |
|---|---|
| a shared library behind a loader (§8) | `dlopen` it by soname and let the dynamic loader search |
| an executable we invoke (`llc`, `opt`, `lld`) | invoke it by name and let `$PATH` resolve it |
| a directory handed to a link invocation | omit the `-L` and let the linker's own search apply |

This is what makes a toolchain work with no configuration at all, which is
the ordinary case for a system install and for a conda environment where
everything is already on `$PATH` and in the loader's path.

Failure is still diagnosable when it comes: a resource that is genuinely
required and resolves nowhere is an error naming the configuration key, and
a resource whose absence is a valid state — no vector math library selected,
a backend's runtime not installed — is reported unset and the caller
decides. AdaptiveCpp already ignores a backend it cannot load and continues;
that behaviour is correct and is preserved.

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

**Existing names are kept.** A key that the driver, the runtime or a
published package already uses stays spelled the way it is spelled today —
`ACPP_CPU_CXX` does not become `ACPP_HOST_CXX`. Renaming buys coherence we
do not need and breaks interfaces we have already shipped.

**Every key this overhaul adds is `ACPP_` only.** The legacy `HIPSYCL_` and
`OPENSYCL_` prefixes exist where they already exist and gain no ground: no
new key carries an alias, and no lookup that lacks alias handling today
grows it. Upstream is moving away from both prefixes and keeps them only to
avoid breaking what is already deployed; adding alias surface to new keys
would be moving the other way.

Where an alias already applies to an existing key, it keeps working
untouched. In practice that means `HIPSYCL_`, since `OPENSYCL_` was the
project's name for a matter of weeks and is barely present.

## 5. How an entry's value is chosen

Entries are not sorted into kinds. Every entry's value is chosen by one
rule, whether it names something we ship, something a vendor ships, or a
choice that is not a path at all.

`options.cmake` is where the cmake options a builder may override are
gathered, so that they are inspectable in one place rather than scattered
through the cmake tree. It is not a registry of configuration keys; the JSON
files are.

### The rule

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

The rule covers resources we ship as readily as resources we do not. For
something in our own install tree — our bitcode, the SPIR-V translator, the
LLVM tools, the clang drivers — the declared default is simply its install
location in placeholder form, and no discovery is involved. For a
non-path choice, such as which vector math library to prefer or which
deployment strategy to use, the declared default is the value this
specification names. Same rule, fewer moving parts.

### What gets no entry at all

**A configuration entry exists to resolve something we look up.** A path we
pass to a subprocess, a directory we hand to a linker invocation, a library
we `dlopen` by path — those are lookups, performed by the driver or by our
own code, and they need somewhere to read the answer from.

**Standard dynamic linkage is not a lookup we perform.** A library that is
`DT_NEEDED` — libnuma, libomp, libLLVM — is resolved by the dynamic loader
before our code runs, and it simply has to be present in the run
environment: in `$CONDA_PREFIX/lib` under conda, in the system library
directories on a system install. There is no answer for a configuration
entry to supply, and an entry naming such a library would be a value that
nothing reads.

Those libraries still appear in a **deploy manifest**, because `full` has to
copy them into the deployment tree, and the manifest records where they were
at install the same way it records the toolchain's library directory (§8).
Deployment knowledge, not resolution knowledge.

Where a compile definition gates code that links such a library —
`LIB_NUMA_AVAILABLE` is the case in this tree — the definition stays, since
the code genuinely cannot compile where the library is absent.

**A worry this raises, and why it is not one.** Take a toolchain that was
not built or installed under `full`, whose owner overrides the strategy to
`full` when deploying their own application. The manifest names libnuma at a
location that, on this machine, holds nothing — the library is installed on
the system rather than beside the toolchain. Deploy skips what it cannot
find (§7), so the deployed tree simply has no copy of it.

That is the correct outcome. A toolchain built with numa support only makes
sense on a machine whose dynamic loader can already find libnuma, and the
deployed application will resolve it the same way, on whatever machine it
lands on. There is no manual lookup anywhere in our code to go wrong.
Whether the target machine has libnuma at all is the application packager's
concern, and not something we can or should control from here.

## 6. Placeholders and resolution

### The placeholders

There are exactly two **core placeholders**:

- **`$ACPP_PATH`** — the install root. It means the toolchain's install
  directory when driving, and the deployment's root when running. Both are
  discovered at read time, never recorded: the driver from its own location,
  and a deployed application by walking up from where its configuration was
  found — which is only an answerable question because of the rule below.

**A configuration containing placeholders lives at the convention location,
and nowhere else.** An application configuration found at
`<root>/etc/AdaptiveCpp/<name>` yields its root by arithmetic, because the
convention fixes how deep it sits. A configuration found anywhere else —
beside a binary, or through a relative path a maintainer chose — supports no
such inversion, so it must not contain placeholders at all: it is written
under the `default` strategy, fully expanded to absolute paths, and
`$ACPP_PATH` never arises when reading it.

That is what makes both of the odd cases safe. A build tree gets a
`default`-strategy configuration beside the binary. A command-line user
generating one in place gets the same. Neither has a root, and neither needs
one.
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
libraries over the application config. One side is Python and the other is
C++, so they cannot share code: what is shared is the *specification*, and
the two implementations are held to it. Where they disagree, this section is
the arbiter.

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
- **Deployment is `acpp --acpp-deploy`**, the mechanism and the argument
  syntax that exist today. The driver reads the toolchain configuration; no
  second program is introduced.
- **`acpp --generate-app-cfg -o <path>` writes an application configuration
  and nothing else**, for the command-line user who compiled in place and
  wants one without a deployment. It is `--acpp-deploy` under `default` with
  the copying removed, which for `default` was almost the whole of it. What
  it writes is fully expanded to absolute paths, as every configuration
  outside the convention location is (§6).
- **`add_sycl_to_target` is the toolchain's own abstraction over it.** It
  adds two custom targets if they do not already exist: an install target
  that runs the deploy into the install directory under the configured
  strategy, and a build target that runs it into the build directory under
  `default`, always. A build tree is a deployment for the developer who
  built it, so it does not need to be relocatable, and copying everything
  into the build tree and then again into the install tree is waste.
  Neither target makes an application's cmake a reader of the toolchain
  configuration — the driver reads it, on the application's behalf, which
  is driving the toolchain.

### What a cmake user has to set

**`ACPP_APP_CFG_NAME`, and nothing else.** P6's second value, the path from
the binary to its configuration, is derived at configure time, because cmake
knows both ends.

The configuration's end is ours to choose, so we know it:
`${CMAKE_INSTALL_SYSCONFDIR}/AdaptiveCpp/`, the directory name the toolchain
configuration already uses. `CMAKE_INSTALL_SYSCONFDIR` is permitted to be
absolute — a project setting it to `/etc` puts the file outside its own
prefix, and no relative path from the binary can reach it — so an absolute
value is an error rather than something to compute against. The binary's end
comes from the target's type —
`EXECUTABLE` to `${CMAKE_INSTALL_BINDIR}`, `SHARED_LIBRARY` to
`${CMAKE_INSTALL_LIBDIR}` — and the embedded value is the relative path
between them, computed with the consuming project's own `GNUInstallDirs`
values, since it is their tree.

**For a `MODULE_LIBRARY`, `add_sycl_to_target` refuses to guess and requires
the destination explicitly.** A module library is a plugin or a language
extension, which is exactly the case P6 exists for and exactly the case
where `${CMAKE_INSTALL_LIBDIR}` is *not* where the thing goes. Guessing
there produces a relative path pointing at nothing, and both search steps
then fail quietly. The same explicit argument serves any project whose
layout `GNUInstallDirs` does not describe — `libexec/myapp/`, an application
bundle — and it is the only knob a normal project never touches.

In the build tree nothing is derived: the configuration is placed at the
target's own output directory, so P6's first search step finds it. That has
to be the target's directory rather than a fixed build path, because output
directories can be set per target and per configuration.

This is deliberately done at configure time rather than at install time. An
install step could always compute the true destination and patch the value
into the installed binary, and that is the patchelf-shaped fragility this
overhaul exists to leave behind: editing linked artifacts after the fact,
with no way to check the result short of running it.

## 8. The install layout

The deploy manifests give the location of every resource relative to the
install root. They are separate from the configuration entries: entries are
resolution knowledge (what keys exist, how they resolve), a manifest is
deployment knowledge (what gets copied, where it goes).

Like the configuration files, **the manifests are source files in the
tree**, one per backend, and the install step copies the enabled set and
fills their stubs. Rows name resources by placeholder — `$ACPP_PATH/...` for
ours, `$ACPP_CUDA_LIB_PATH/...` for a resource an entry already locates —
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

The SPIR-V translator belongs to **core**, not to the OpenCL and Level Zero
components, even though only those backends use it. It is built as part of
the toolchain, it is tiny, and the two possible confusions are not
symmetric: someone finding it absent from core asks "this was built with the
toolchain, why is it not here?", which is an uncomfortable unknown, while
someone finding it present in a CUDA-only deployment shrugs and leaves it
alone. An unnecessary inclusion costs nothing; a missing one costs a
deployment.
- **Vendor resources, under `$ACPP_PATH/targets/$ACPP_TARGET/`** — the CUDA
  and ROCm runtime libraries, laid out the way CUDA's own installer and
  conda-forge lay them out.

### Vendor device bitcode

**AdaptiveCpp does not own a vendor's device bitcode unless `full` put it
there.** The entries that locate it — `ACPP_CUDA_DEVICE_LIBS_PATH` for
CUDA's `libdevice.10.bc`, `ACPP_ROCM_DEVICE_LIBS_PATH` for ROCm's device
library directory — default to `$ACPP_PATH/lib/hipSYCL/ext/bitcode/ptx` and
`.../ext/bitcode/amdgcn`, which is where `full` copies them, where the
deploy manifests put them, and where nothing else does. Under `default` the
entry expands to the absolute path the build found. Under `bundled` the
default is a claim about our own tree that only `full` makes true, so a
packager whose environment supplies the bitcode **overrides the entry** —
for conda, `$ACPP_PATH/nvvm/libdevice` for CUDA and
`$ACPP_PATH/amdgcn/bitcode` for ROCm, which is where conda-forge's
`rocm-device-libs` puts it.

That is one entry doing the work, and it replaces the symlink the packaging
lane currently plants to make a relative lookup land on conda's layout.

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
- `default-use-bootstrap-mode`. Searching the whole repository for
  `bootstrap` returns three hits: the line in `CMakeLists.txt` that
  generates the key, an unrelated comment in `SyncDependenceAnalysis.cpp`,
  and a mention of bootstrap builds in `doc/installing.md`. Nothing reads
  it — in the driver or anywhere else

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
  | `ACPP_LLC_ADDITIONAL_FLAGS`, `ACPP_OPT_ADDITIONAL_FLAGS`, and the host CPU flags when `ACPP_HOST_FORCE_MCPU_TARGET` is set | JIT flags a deployed application cannot change |

  Three call sites — `LLVMToPtx.cpp` and `LLVMToAmdgpu.cpp` twice — use
  their macro raw, without placeholder expansion, and cannot carry a
  relocatable value at all until they are converted.

  **The redist-first branch in each getter is replaced, not kept.** Today
  `getLLCPath`, `getLLDPath`, `getOptPath`, the three vector-math getters
  and both device-bitcode getters check a loader-relative
  `<our libdir>/hipSYCL/ext` location *before* consulting their macro
  (`Utils.cpp:30-39`). That branch exists because the macro was the only
  other answer and it was frequently wrong. With a configuration entry in
  its place the order becomes: **the entry, then the platform's own lookup
  (P7)** — and the loader-relative probe goes away with the macro it was
  compensating for. Deployed trees keep working because the deploy step
  writes the entry; undeployed ones keep working because the platform
  resolves them.

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

  The three getters this changes are `getLibSleefDir()`, `getLibAmathDir()`
  and `getLibSvmlDir()` in `Utils.cpp`; `getLibMvecDir()` is deliberately
  untouched (§11). `ACPP_VECTOR_MATH_LIB` enumerates what the runtime
  already parses — `sleef`, `armpl`, `svml`, `libmvec`, `none` — and
  `libmvec` is selectable while having no directory entry, because the only
  correct copy is the one the loader resolves in the running process.

  `LIB_NUMA_AVAILABLE` is the exception and stays exactly as it is.
  `rt-backend-omp` includes `numa.h` and links `${NUMA_LIBRARY}`, so the
  definition gates code that cannot compile without the library present.
  Nothing else about numa changes: it needs no configuration entry, because
  a dynamically linked library is not something we look up (§5).

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
  `HIPSYCL_DEBUG_LEVEL`, the Windows portability trio, LLVM's own
  `LLVM_DEFINITIONS`, and `ROCM_CLANG_VERSION_MAJOR`/`MINOR`/`PATCH` —
  which records not the ROCm an application will meet but whether the clang
  we are *compiled against* is AMD's patched one, and whose every consumer
  is an `#if` selecting a workaround for a specific AMD clang version
  (`Frontend.hpp`, `PipelineBuilder.cpp`, `SMCPCompatPass.cpp`).
- The two-pass resolver, in the driver and in `common::settings`.
- **The configuration identity a binary carries (P6)**, which is the largest
  single change and touches four surfaces: an `acpp` driver flag taking the
  name and the relative path; a cmake option surfaced through the
  toolchain's package configuration so `add_sycl_to_target` users set it per
  target; the embedding itself, which must be **per binary and not per
  translation unit**, since two translation units of one binary cannot be
  allowed to disagree; and the lookup in `settings_config_file`, which today
  finds `acpp-config.cfg` beside the host executable via
  `get_this_executable_path` and must instead ask the calling binary. A
  binary carrying no identity falls back to exactly today's behaviour, so
  nothing that does not opt in changes.
- Thin loader libraries so that no *redistributable* vendor library is
  `DT_NEEDED`: `libcudart` for CUDA, the ROCm runtime libraries for HIP,
  and the OpenCL and Level Zero loaders. `libcuda.so.1` is deliberately not
  among them (P5).
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

- **How deploy learns the name.** P6 has the binary carry it, so the deploy
  step has to write the file where those binaries will look. Either the name
  and relative path are given to deploy as arguments and must agree with
  what was compiled in, or deploy reads the identities out of the binaries
  it is deploying and writes what they ask for. The second is automatic and
  cannot disagree with itself.
- Whether the deploy helper writes the configuration itself, with the
  environment still overriding it at run time. That is the proposal; the
  override flag is how a user's own entries get in.
- Upstream's `acpp-config-<program-name>.cfg`, which selects by the host
  executable's filename. P6 supersedes what it was for; whether it stays as
  a legacy path or goes is not settled.
