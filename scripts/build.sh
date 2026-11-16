#!/usr/bin/env bash
# Configure + build upstream Rockbox for the 3DS (configure target "3ds").
# Outputs in build/rockbox-3ds: rockbox.3dsx, rockbox.cia, rockbox-full.zip
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/env.sh"
[ -x "$DEVKITARM/bin/arm-none-eabi-gcc" ] || { echo "run scripts/setup-toolchain.sh first"; exit 1; }
[ -f "$ROOT/rockbox/tools/configure" ] || git -C "$ROOT" submodule update --init rockbox
for p in "$ROOT"/patches/*.patch; do
    [ -e "$p" ] || continue
    git -C "$ROOT/rockbox" apply --check "$p" 2>/dev/null && git -C "$ROOT/rockbox" apply "$p" && echo "applied $(basename "$p")"
done
B="$ROOT/build/rockbox-3ds"
mkdir -p "$B" && cd "$B"
[ -f Makefile ] || "$ROOT/rockbox/tools/configure" --target=3ds --type=N
make -j"$(nproc)"
make fullzip
ls -la "$B"/rockbox.3dsx "$B"/rockbox.cia "$B"/rockbox-full.zip
