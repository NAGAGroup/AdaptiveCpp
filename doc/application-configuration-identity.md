# How an application finds its configuration

Working notes, settled 2026-09-10. This is the design; the relocatable
overhaul specification will absorb it.

## The problem

A deployed application has to find the configuration that was written for it.
Upstream looks for `acpp-config.cfg` beside the host executable, which is
wrong whenever the SYCL code is not in the executable — a Python extension
module finds the interpreter's directory. Several apparent answers fail:

- **Loader-relative, by `dladdr` on our own symbol.** Under the `default`
  strategy our libraries never leave the toolchain, so every application
  built with that toolchain would share one configuration.
- **Reading two locations and merging.** An application's behaviour could
  then change because someone edited something in the toolchain's tree
  afterwards, which is what the two-file split exists to prevent.
- **Asking which object called us.** SYCL is header-heavy, so the object at
  the ABI boundary is the caller's translation unit, not necessarily the
  unit that owns the configuration.

## The design

**A binary carries the configuration's name and nothing else.** Not a path,
not a location — one string, chosen by whoever built it, embedded at link
time. Where the file lives is a search, not a recorded fact.

**The search, in order:**

1. `$XDG_CONFIG_HOME/AdaptiveCpp/app-cfgs/<name>.cfg`
2. the system configuration directory (`/etc/AdaptiveCpp/app-cfgs/`, or the
   platform equivalent)
3. relative to `$ACPP_LIB_PATH` — the directory holding our own libraries

User configuration beats system configuration, as everywhere else. A stray
file in `$XDG_CONFIG_HOME` can only affect applications carrying that name,
so name-keying already scopes what would otherwise be a footgun.

**Where the deploy step writes.** Under `bundled` and `full*` the
application's tree holds our libraries, so location 3 is inside it. Under
`default` nothing is copied, and the destination is a toolchain
configuration entry — `default-strategy-app-cfg-dir` — whose default value
is the XDG location, covering the common case of a user compiling for
themselves. A distribution maintainer building in `default` mode sets it to
`/etc/AdaptiveCpp/app-cfgs/` instead, which is why it is an entry rather
than a constant.

## One configuration per process

Two acpp-built objects in one process with different configurations is
**incoherent, not merely awkward**: the configuration names the JIT's
toolchain, so two answers means two toolchains compiling for the same
devices — different CUDA runtime versions, different device bitcode.

Mechanisms that pick a winner at run time do not work, because the
configuration is read lazily on first use and nothing prevents a dependency
from touching a SYCL API during its own static initialisation, before the
dependent's constructor has run. Any "last registration wins" rule loses
that race.

**So the name is made uniform at deploy time instead.** The embedded field
is fixed-size, padded to a maximum name length, and carries a magic header,
so the deploy step can find it, assert the header, assert the new name fits,
overwrite it, and read it back to verify. Every acpp object in the tree then
carries the same name by construction and there is no race to lose.

This is safe in a way that general binary patching is not: the layout is
ours, produced by our own toolchain, and verifiable before and after. The
rewrite happens **while copying** — deployment already copies dependencies
into the tree — so it never touches a system library shared with other
applications.

Under `default` nothing is copied, so there is no copy to patch. That is the
mode where a conflict remains possible and is reported.

## Who gets a configuration at all

- **A package of shared libraries only** does not get one. Its binaries
  carry the placeholder field so a later deployment can fill it, and nothing
  more.
- **A module** does get one — it may be loaded by something that is not a
  SYCL application at all, a Python interpreter being the obvious case.
- **An application** gets one, and the libraries deployed with it are
  patched to match.

For command-line users an `acpp` flag decides whether to embed. For cmake
users it is decided at install: the application gets one, and libraries
linked into it are patched to agree.

## Two roots, never one name

`$ACPP_PATH` in upstream resolves through `get_install_directory()` — a
`dladdr` on our own library — so it silently means the toolchain when
driving and the deployment when running. Both the Python driver and the C++
runtime implement it separately, and the driver additionally computes
`$ACPP_LIB_PATH` by joining a hardcoded `"lib"`, which is wrong on any
`lib64` distribution.

We deviate deliberately:

| context | name | resolved by |
|---|---|---|
| toolchain configuration values, manifest `src` | `{{ toolchain-path }}` | the driver, from its own location |
| manifest `dest` | bare relative paths | — |
| application configuration values | `$ACPP_PATH` | the runtime, from the deployment |

`{{ }}` expands at drive and deploy time; `$NAME` survives into the deployed
file. Neither name exists in the other's world, so a value that means the
wrong root is an unresolved-key error rather than a subtly wrong path.

## Open: the compatibility set

Projects built with one toolchain may be incompatible with another, and the
uniform-name rule above assumes the objects in a process can agree on one
toolchain. What actually has to match — LLVM version, device bitcode
version, runtime ABI, vendor runtime versions — has not been worked out, and
the answer decides what the deploy step should refuse rather than patch.
