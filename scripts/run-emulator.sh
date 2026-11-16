#!/usr/bin/env bash
# Run the build in the Azahar emulator with an isolated config/SD directory
# (build/emu), optionally inside a nested X server (Xephyr) for scripted tests.
#   scripts/run-emulator.sh            # on your current display
#   NESTED=1 scripts/run-emulator.sh   # in Xephyr :99, drive with emu-keys.py
#   DUMP=out.mkv ...                   # record video+audio (Azahar -d)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
E="$ROOT/build/emu"; mkdir -p "$E"; cd "$E"
if [ ! -x squashfs-root/AppRun ]; then
    curl -fsSL -o azahar.AppImage https://github.com/azahar-emu/azahar/releases/download/2126.2/azahar.AppImage
    chmod +x azahar.AppImage && ./azahar.AppImage --appimage-extract >/dev/null && rm azahar.AppImage
fi
export XDG_DATA_HOME="$E/data" XDG_CONFIG_HOME="$E/config"
SD="$E/data/azahar-emu/sdmc"; mkdir -p "$SD/Music" "$SD/3ds"
python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$ROOT/build/rockbox-3ds/rockbox-full.zip" "$SD"
# libctru's ndspInit() needs sdmc:/3ds/dspfirm.cdc to exist. Azahar's HLE DSP
# ignores its contents, so a zero-filled placeholder is enough IN THE EMULATOR.
# On real hardware Rockbox dumps the real one from your own console at first start.
[ -f "$SD/3ds/dspfirm.cdc" ] || head -c 49152 /dev/zero > "$SD/3ds/dspfirm.cdc"
if [ ! -f "$SD/Music/tone.flac" ] && command -v ffmpeg >/dev/null; then
    ffmpeg -loglevel error -f lavfi -i "sine=frequency=440:duration=30" -ac 2 -ar 44100 \
        -metadata title="Test Tone" -metadata artist="rockbox-3ds" "$SD/Music/tone.flac"
fi
if [ -n "${NESTED:-}" ]; then
    pgrep -x Xephyr >/dev/null || { Xephyr :99 -screen 1024x768 -ac >xephyr.log 2>&1 & sleep 2; }
    export DISPLAY=:99
fi
exec squashfs-root/AppRun ${DUMP:+-d "$DUMP"} "$SD/3ds/.rockbox/rockbox.3dsx"
