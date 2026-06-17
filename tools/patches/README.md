# Isaac Sim 5.1.0 — debug_draw build fix (applied automatically)

Fixes the build/link error:

```
/usr/bin/ld: cannot find -lisaacsim.util.debug_draw.primitive_drawing: No such file or directory
  -> isaacsim.asset.gen.omap.plugin   (Error 1)
  -> isaacsim.sensors.physx.plugin    (Error 1)
BuildError: BUILD FAILED for release
```

## Cause

`isaacsim.asset.gen.omap` and `isaacsim.sensors.physx` statically link
`isaacsim.util.debug_draw.primitive_drawing`, which ships inside the prebuilt
`isaacsim.util.debug_draw` extension (pulled from the Omniverse registry, not
built from this repo). The registry's **defective** `3.1.0+107.3.3` package
ships only the `.so` plugin and omits the static library
`libisaacsim.util.debug_draw.primitive_drawing.a`. The sibling `3.1.0+107.3.1`
build (identical source) ships it correctly.

## Fix (no manual steps — happens during `./build.sh`)

Two changes are committed to source so a fresh clone builds in one pass:

1. **Version preference** — `source/apps/isaacsim.exp.extscache.kit` pins
   `isaacsim.util.debug_draw` to `3.1.0+107.3.1` (non-exact), so precache pulls
   the complete package when the registry serves it.
2. **Guaranteed static lib** — `repo.toml` `pre_build.commands` runs
   `tools/patches/inject_debug_draw_lib.sh` right after `precache_exts`. If the
   precached package is missing the `.a` (e.g. the registry only serves the
   defective `107.3.3`), it injects the vendored copy under
   `tools/patches/debug_draw/`. No-op when the `.a` is already present.

The non-exact pin matters: an `exact = true` pin to `107.3.1` would make
precache *fail* outright if the registry only serves `107.3.3`, before the
inject hook could run. Keeping the pin non-exact lets precache succeed with
whatever `3.1.0` build is available; the hook then guarantees the `.a`.

## Contents

```
tools/patches/inject_debug_draw_lib.sh                                # build hook (inject-only, idempotent)
tools/patches/debug_draw/libisaacsim.util.debug_draw.primitive_drawing.a  # vendored static lib (NVIDIA proprietary)
tools/patches/README.md                                              # this file
```

> The vendored `.a` is an NVIDIA proprietary binary taken from the working
> `isaacsim.util.debug_draw-3.1.0+107.3.1` package.
