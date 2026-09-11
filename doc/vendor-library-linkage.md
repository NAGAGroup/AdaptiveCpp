# How a deployed application finds its vendor libraries

Working notes, 2026-09-10. Scoped to the `generic` flow; see the last section
for why multi-pass is not affected. The vendor-specific configuration entries
themselves are not settled yet — this records the mechanism and the decisions
that follow from it.

## The mechanism, measured

Linking against a shared library records a **name** in `.dynamic`, never a
path. `librt-backend-cuda.so` as built records:

```
libacpp-rt.so  libacpp-common.so  libllvm-to-backend.so  libllvm-to-ptx.so
libcuda.so.1   libcudart.so.12    libc.so.6  libstdc++.so.6  libgcc_s.so.1
```

The recorded name is the dependency's SONAME, carrying its major version — a
deployment shipping `libcudart.so.12.9.79` satisfies it only if some
`libcudart.so.12` name resolves to it.

At load time those names are resolved in a fixed order: `DT_RPATH`, then
`LD_LIBRARY_PATH`, then `DT_RUNPATH`, then `/etc/ld.so.cache`, then the
default directories. **All of it happens before any of our code runs** — no
hook, no callback, no file the loader will read on our behalf. A configurable
location therefore cannot be expressed as a `DT_NEEDED` dependency.

`$ORIGIN` in a RUNPATH is the one useful escape hatch, and it expresses
exactly one idea: relative to the object being loaded. Ours is
`$ORIGIN/../`, and since the backends live in `<libdir>/hipSYCL/`, that
resolves to `<libdir>`.

## Why there are no loader shims

An earlier design had a generated forwarding library per vendor, so the
backend could call vendor symbols normally while we controlled the `dlopen`.
It is dropped, because **the two cases that occur in practice are already
served**:

- a system install, where `ld.so.cache` finds the vendor libraries;
- a prefix-shaped tree — conda, `pixi global install` — where they sit in
  `<libdir>`, which is exactly what `$ORIGIN/../` reaches.

The third case, a vendor library at an arbitrary path neither covers, is what
`LD_LIBRARY_PATH` and `ld.so.conf` exist for. Building a shim layer to solve
it would have cost nine artifacts for AMD alone, each exporting a vendor
symbol surface that could not be verified without building, in exchange for a
problem the ecosystem solved long ago.

The diagnostic argument for shims was also wrong: `common::load_library`
already appends `dlerror()`, so a missing vendor library is reported by name
today — *"Could not load library: …/librt-backend-cuda.so (libcudart.so.12:
cannot open shared object file)"*. It sits at debug-warning level, which is
the only thing worth improving.

## What that means for deployment

**Vendor libraries must land where the RUNPATH already looks**, which is
`<libdir>`, beside our own. A separate vendor zone under
`targets/<platform-arch>/` is not reachable from `$ORIGIN/../` and would
require baking the subdirectory name into every binary at link time.

The toolkit-shaped layout clang expects when handed `--cuda-path` is a
**driving-time** concern only: multi-pass compiles on the developer's machine
against the toolchain, the `generic` JIT reads device bitcode through its own
configuration entry, and the AMD JIT passes `-nogpuinc` precisely to avoid
the detector. No deployed application ever hands clang a toolkit root.

## The strategy matrix

The strategy chosen when *building* the toolchain decides the initial cfg
values and whether `cmake --install` copies vendor assets in. The strategy
chosen when *deploying* is the toolchain user's, and may differ. Not every
combination is coherent.

| toolchain built | deployed | outcome |
|---|---|---|
| `default` | `default` | the system install case; the loader finds vendor libraries as it always did |
| `default` | `bundled`/`full*` | works only if shared libraries land in `$ACPP_LIB_PATH`, the one place `$ORIGIN` reaches. A distributor expecting users to deploy this way should not build with `default`. |
| `bundled` | any | depends entirely on how the publisher laid out their tree. No general expectation can be stated; they must document it. |
| `full` | `full` | the simple case: deploy from the install tree to the same layout |
| `bundled`/`full-permissive-only` | `default` | **does not work.** The cfg describes a tree whose vendor assets were never placed there. These modes assume the user populates the toolchain's own install location. |

Deployment runs with no cmake and no discovery, so it can only resolve what
the configuration says — it cannot recover from a cfg describing assets that
are not there.

**The cfg records the strategy the toolchain was built with**, so the deploy
step knows both that and the strategy being asked for, and can warn on the
incoherent combinations naming the specific entries that will not resolve.
That does not remove the publisher's obligation to document, but it moves
discovery from first run to deploy time.

## Open: where vendor assets deploy *to*

A manifest row's source is a configuration entry, so a publisher can say
where assets are pulled *from*. The destination is currently `{{ libdir }}`,
which moves our libraries and the vendor's together. A publisher who wants
them to differ needs a destination entry per vendor-asset class, defaulting
to `{{ libdir }}`. Not yet written.

## Why multi-pass is exempt

In multi-pass, acpp adds the vendor link line to **the application's own
link**, so the application carries `DT_NEEDED: libcudart.so.12` with whatever
RUNPATH its builder chose. By the time the runtime `dlopen`s
`librt-backend-cuda.so`, a library with that SONAME is already loaded, and
the loader satisfies a `DT_NEEDED` from the already-loaded set without any
filesystem search. The backend's RUNPATH is never consulted.

In `generic` nothing has loaded it, so the backend's dependency triggers a
real search resolved entirely by decisions frozen when the toolchain was
built. **That is the asymmetry: `generic`'s vendor linkage is fixed before
the toolchain's first use; multi-pass's is decided when the user compiles
their application, and is theirs to control.**
