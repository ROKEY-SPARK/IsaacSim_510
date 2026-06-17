#!/usr/bin/env bash
#
# inject_debug_draw_lib.sh
# -------------------------------------------------------------------------
# Runs during the build (wired into repo.toml pre_build.commands, right
# after precache_exts) to guarantee the static library
#   libisaacsim.util.debug_draw.primitive_drawing.a
# exists in the precached isaacsim.util.debug_draw package.
#
# Why this is needed
# ------------------
# isaacsim.asset.gen.omap and isaacsim.sensors.physx statically link that
# library. The Omniverse registry's isaacsim.util.debug_draw 3.1.0+107.3.3
# package is defective: it ships only the .so plugin and omits the .a, so
# the C++ link step fails with:
#   /usr/bin/ld: cannot find -lisaacsim.util.debug_draw.primitive_drawing
# The sibling 3.1.0+107.3.1 build (identical source) ships the .a correctly.
# The extscache kit file prefers 107.3.1, but if the registry only serves
# the defective build this hook injects a vendored copy of the .a so the
# link still succeeds — eliminating the manual build-fail/patch/rebuild loop.
#
# Scope: only touches generated artifacts under _build/; never edits tracked
# source. Idempotent and safe to run on every build.
# -------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

EXT="isaacsim.util.debug_draw"
LIB="libisaacsim.util.debug_draw.primitive_drawing.a"
VENDORED_LIB="$SCRIPT_DIR/debug_draw/$LIB"

info() { printf '\033[1;34m[debug_draw-fix]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[debug_draw-fix]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[debug_draw-fix] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

fixed=0
shopt -s nullglob
for cfg_dir in "$ROOT"/_build/*/release "$ROOT"/_build/*/debug; do
    [ -d "$cfg_dir/extscache" ] || continue

    # Versioned precache packages.
    for pkg in "$cfg_dir"/extscache/${EXT}-*; do
        [ -d "$pkg/bin" ] || continue
        if [ ! -f "$pkg/bin/$LIB" ]; then
            [ -f "$VENDORED_LIB" ] || die "vendored static lib missing: $VENDORED_LIB"
            cp -f "$VENDORED_LIB" "$pkg/bin/$LIB"
            info "Injected $LIB into $(basename "$pkg")"
            fixed=1
        fi
    done

    # Version-less build-time link dir (extsbuild symlink target the linker uses).
    linkdir="$cfg_dir/extsbuild/$EXT"
    if [ -d "$linkdir/bin" ] && [ ! -f "$linkdir/bin/$LIB" ]; then
        [ -f "$VENDORED_LIB" ] || die "vendored static lib missing: $VENDORED_LIB"
        cp -f "$VENDORED_LIB" "$linkdir/bin/$LIB"
        info "Injected $LIB into extsbuild/$EXT/bin"
        fixed=1
    fi
done
shopt -u nullglob

if [ "$fixed" -eq 1 ]; then
    ok "debug_draw static library ensured."
else
    info "debug_draw static library already present; nothing to inject."
fi
