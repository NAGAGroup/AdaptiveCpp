# Relocatable toolchain: specification

How AdaptiveCpp locates every external resource, and how that behaviour is
configured. This is normative: where the code and this document disagree, the
document is the defect report.

The as-built state this replaces is recorded in
[path-resolution-ledger.md](path-resolution-ledger.md).

## 1. The three states

Resolution happens in three states. Each name carries its own subject, because
the failure mode is a reader assuming the wrong one. Use these words:

- **when building the toolchain** — AdaptiveCpp itself is compiled and
  installed. The only state in which cmake exists.
- **when driving the toolchain** — `acpp` compiles a user's program. The driver
  resolves settings and sets compiler and linker flags.
- **when running an application** — a program built with acpp executes, on a
  machine we may never see. The JIT runs here, so this state compiles too.

Never write bare "compile time" or "run time". If either appears, the vocabulary
has slipped and the sentence is ambiguous.

## 2. Principles

**P1. No path is compiled into a binary.** Not as a compile definition, not as
a default, not as a fallback. A path that appears in a shipped artifact appears
only in a configuration file, which is text and can be corrected without a
rebuild.

**P2. Configuration files are the single source of truth**, with environment
variables as the only override. There are exactly two, and they never see each
other:

| | read by | when | location |
|---|---|---|---|
| toolchain config | the `acpp` driver | driving the toolchain | the toolchain installation |
| application config | loader libraries and the JIT | running an application | beside the deployed application |

**P3. An application never reads the toolchain config.** A deployed application
does not require a toolchain to be installed, and cannot silently inherit one.

**P4. The application config is derived from the toolchain config** by
`acpp --acpp-deploy`. Because there is nothing beneath it, every field it needs
must be populated; an incomplete derivation is an error at deploy time, not a
mystery at run time. A user may hand-edit it, and thereby owns the result.

**P5. Everything reached when running an application goes through a loader.**
No vendor SDK appears as `DT_NEEDED` in any AdaptiveCpp binary. A thin loader
library per backend reads the application config and loads the real
implementation. This is the architecture OpenCL and Level Zero already use.

**P6. Application-side lookup is loader-relative, never executable-relative.**
Resolution uses `dladdr` on our own symbol, so a SYCL application shipped as a
shared library — a Python extension module, for example — finds its
configuration beside the AdaptiveCpp libraries rather than beside the host
interpreter.

**P7. Defaults preserve local builds.** With no options set, cmake writes the
`find_*` results into the installed toolchain config, and a toolchain built on a
machine works on that machine with no configuration. Relocatability is opt-in;
it changes what is *written*, never how it is *read*.

## 3. Naming

One stem per resource. Every surface derives from it mechanically, so knowing
two names lets a reader guess the rest.

```
stem              cuda-device-libs
cmake option      ACPP_CUDA_DEVICE_LIBS_PATH
environment       ACPP_CUDA_DEVICE_LIBS_PATH
config key        ACPP_CUDA_DEVICE_LIBS_PATH
driver flag       --acpp-cuda-device-libs-path
```

The configuration key and the environment variable are the same string because
the configuration file format is `<environment-variable>=<value>`, one per line.
They are one namespace, not two that must be kept in step.

`common::settings` already derives the environment name from a stem by
uppercasing and prefixing `ACPP_`, and already resolves environment before
configuration file. That mechanism is the one to use; no resource gets a
hand-written lookup.

## 4. Resolution

**When running an application**, for every resource:

```
environment variable  →  application config  →  error
```

There is no third tier. A missing value is a diagnosable error naming the stem,
not a fallback to something that happens to be on the machine.

**When driving the toolchain**, for every resource:

```
command-line flag  →  environment variable  →  toolchain config  →  error
```

**When building the toolchain**, cmake decides what the toolchain config will
contain, in escalating order of control:

1. **Default** — the `find_*` result for each resource, written verbatim.
   Not relocatable; correct for a toolchain that never leaves its machine.
2. **Granular override** — `ACPP_<STEM>_PATH` set at configure time replaces one
   entry. Whether the result is relocatable is the builder's business.
3. **Granular, relative** — the same overrides, interpreted relative to the
   install root, so a builder never hand-writes a placeholder.
4. **Relocatable** — every entry is set relative to the install root using the
   standard layout of §5, with individual rows still overridable for
   distributions that do not follow it.
5. **Deploy at build** — optionally, runtimes located by `find_*` are copied
   into their relocatable install locations, so a relocatable toolchain is also
   self-contained.

## 5. The install layout

One table gives the location of every resource relative to the install root. It
is the definition used by mode 4 above, and the deployment manifests are
generated from it, so a relocatable build and a deployed tree cannot disagree
about where a resource lives.

Directory names come from `GNUInstallDirs` rather than being rederived.

The table covers more than the artefacts we compile: vendor libraries and device
bitcode need rows that the deployment manifests do not have today.

## 6. Deployment

`acpp --acpp-deploy` is the canonical deployment mechanism, for command-line and
cmake users alike. It:

- copies the AdaptiveCpp runtime, the LLVM libraries it needs, and the loader
  libraries into the target tree;
- derives and writes the application configuration file;
- **skips any file already present at the destination**, so a package manager
  that already provides a component is not overwritten.

Skipping is by existence, not by identity. Verifying identity would require
recording the expected hash or version of each artefact — build-machine state in
a shipped file, which P1 forbids.

For cmake users, `add_sycl_to_target` arranges deployment so that no explicit
step is required; the configuration file reaches the binary directory as part of
the build.

Deployed binaries carry `$ORIGIN`-relative rpaths. Running a deployed
application must never require setting `LD_LIBRARY_PATH`.

## 7. What this deletes

- every path-valued compile definition
- `CMAKE_INSTALL_RPATH_USE_LINK_PATH`, which adds absolute link-time paths
- the distinction between "runtime settings" and "JIT settings" in the
  configuration file, which is why an environment variable cannot currently fix
  a device library lookup
- `DT_NEEDED` entries on vendor SDKs, and with them the tight version pins that
  downstream packages must carry
