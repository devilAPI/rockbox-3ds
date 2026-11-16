#!/usr/bin/env bash
# Install everything needed to build Rockbox for the 3DS, without root,
# pacman or docker:
#   - devkitARM + libctru + citro2d/citro3d + 3dstools (3dsxtool, smdhtool):
#     extracted from the official devkitpro/devkitarm Docker image, fetched
#     with curl through the Docker Hub registry HTTP API.
#   - CTRL and CTRDL (libdl for 3DS): built from source (pinned commits).
#   - makerom, bannertool: upstream GitHub release binaries (CIA packaging).
# Everything lands under build/toolchain (gitignored). ~600 MB on disk.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DL="$ROOT/build/dl"
TC="$ROOT/build/toolchain"
mkdir -p "$DL" "$TC/bin"

IMAGE=devkitpro/devkitarm
IMAGE_TAG="${DEVKITARM_IMAGE_TAG:-latest}"
CTRL_COMMIT=626a356e96f263cb3d88052a6756afab2f61da60
CTRDL_COMMIT=2fb8fa1f40be5e6a340da59ec9f8f25b7b2f8a14
MAKEROM_URL=https://github.com/3DSGuy/Project_CTR/releases/download/makerom-v0.19.0/makerom-v0.19.0-ubuntu_x86_64.zip
BANNERTOOL_URL=https://github.com/carstene1ns/3ds-bannertool/releases/download/1.2.3/bannertool-1.2.3-linux.tar.gz

json() { python3 -c "import json,sys; d=json.load(sys.stdin); $1"; }

# ---- 1. devkitARM from the Docker image --------------------------------
if [ ! -x "$TC/opt/devkitpro/devkitARM/bin/arm-none-eabi-gcc" ]; then
    echo ">> fetching $IMAGE:$IMAGE_TAG from Docker Hub"
    token=$(curl -fsS "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$IMAGE:pull" | json "print(d['token'])")
    reg="https://registry-1.docker.io/v2/$IMAGE"
    accept="Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json"
    manifest=$(curl -fsS -H "Authorization: Bearer $token" -H "$accept" "$reg/manifests/$IMAGE_TAG")
    if echo "$manifest" | grep -q '"manifests"'; then
        digest=$(echo "$manifest" | json "print([m['digest'] for m in d['manifests'] if m['platform']['architecture']=='amd64' and m['platform']['os']=='linux'][0])")
        manifest=$(curl -fsS -H "Authorization: Bearer $token" -H "$accept" "$reg/manifests/$digest")
    fi
    for layer in $(echo "$manifest" | json "print(' '.join(l['digest'] for l in d['layers']))"); do
        f="$DL/${layer#sha256:}.tgz"
        if [ ! -f "$f" ]; then
            echo ">> layer $layer"
            curl -fsSL -H "Authorization: Bearer $token" "$reg/blobs/$layer" -o "$f.part"
            echo "${layer#sha256:}  $f.part" | sha256sum -c --quiet
            mv "$f.part" "$f"
        fi
        # only layers that contain /opt/devkitpro matter; skip NDS/GBA bits
        if tar tzf "$f" opt/devkitpro >/dev/null 2>&1; then
            tar xzf "$f" -C "$TC" \
                --exclude='opt/devkitpro/examples' --exclude='opt/devkitpro/calico' \
                --exclude='opt/devkitpro/libgba' --exclude='opt/devkitpro/libnds' \
                --exclude='opt/devkitpro/libtonc' --exclude='opt/devkitpro/libmirko' \
                --exclude='opt/devkitpro/portlibs/nds' --exclude='opt/devkitpro/portlibs/gba' \
                --exclude='opt/devkitpro/portlibs/armv4t' --exclude='opt/devkitpro/portlibs/gp2x' \
                opt/devkitpro
        fi
    done
fi
. "$ROOT/scripts/env.sh"
arm-none-eabi-gcc --version | head -1

# ---- 2. makerom + bannertool ---------------------------------------------
if [ ! -x "$TC/bin/makerom" ]; then
    curl -fsSL "$MAKEROM_URL" -o "$DL/makerom.zip"
    python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extract('makerom', sys.argv[2])" "$DL/makerom.zip" "$TC/bin"
    chmod +x "$TC/bin/makerom"
fi
if [ ! -x "$TC/bin/bannertool" ]; then
    curl -fsSL "$BANNERTOOL_URL" -o "$DL/bannertool.tar.gz"
    mkdir -p "$DL/bannertool" && tar xzf "$DL/bannertool.tar.gz" -C "$DL/bannertool"
    cp "$(find "$DL/bannertool" -type f -name bannertool | head -1)" "$TC/bin/bannertool"
    chmod +x "$TC/bin/bannertool"
fi

# ---- 3. CTRL + CTRDL into portlibs/3ds -----------------------------------
fetch() { # name url commit
    if [ ! -d "$DL/$1/.git" ]; then git clone -q "$2" "$DL/$1"; fi
    git -C "$DL/$1" fetch -q origin && git -C "$DL/$1" checkout -q "$3"
    git -C "$DL/$1" submodule update -q --init --recursive
}
PORTLIBS="$DEVKITPRO/portlibs/3ds"
if [ ! -e "$PORTLIBS/lib/libCTRL.a" ]; then
    fetch CTRL https://github.com/kynex7510/CTRL "$CTRL_COMMIT"
    cmake -S "$DL/CTRL" -B "$DL/CTRL/Build" -G "Unix Makefiles" \
        -DCMAKE_TOOLCHAIN_FILE="$DEVKITPRO/cmake/3DS.cmake" -DCMAKE_BUILD_TYPE=Release
    cmake --build "$DL/CTRL/Build" -j"$(nproc)"
    cmake --install "$DL/CTRL/Build" --prefix "$PORTLIBS"
fi
if [ ! -e "$PORTLIBS/lib/libdl.a" ]; then
    fetch CTRDL https://github.com/kynex7510/CTRDL "$CTRDL_COMMIT"
    cmake -S "$DL/CTRDL/ResGen" -B "$DL/CTRDL/Build/ResGen" -DCMAKE_BUILD_TYPE=Release
    cmake --build "$DL/CTRDL/Build/ResGen" -j"$(nproc)"
    cmake --install "$DL/CTRDL/Build/ResGen" --prefix "$DL/CTRDL/Build/ResGen/Release"
    cmake -S "$DL/CTRDL" -B "$DL/CTRDL/Build" -G "Unix Makefiles" \
        -DCMAKE_TOOLCHAIN_FILE="$DEVKITPRO/cmake/3DS.cmake" -DCMAKE_BUILD_TYPE=Release \
        -DRESGEN_PATH="$DL/CTRDL/Build/ResGen/Release/bin"
    cmake --build "$DL/CTRDL/Build" -j"$(nproc)"
    cmake --install "$DL/CTRDL/Build" --prefix "$PORTLIBS"
fi
echo ">> toolchain ready in $TC ($(du -sh "$TC" | cut -f1))"
