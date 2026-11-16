# Design notes

## Prior art (checked 2026-11-16)

- **Upstream Rockbox has a 3DS port.** `tools/configure` target `3ds`
  (id 290, `app_type=3ds-homebrew`, model `N3DS`). It is a *hosted* target
  under `firmware/target/hosted/game_console/3ds` (shared console layer with
  a PSP port): LCD via citro2d/citro3d on the bottom screen (320x240, touch),
  buttons/circle pad via hid, audio via ndsp (`pcm-3ds.c`), SD via FSUSER,
  codecs and plugins as shared objects loaded with CTRDL (a `dlopen` for 3DS),
  packaging to .3dsx and .cia in `packaging/3ds`. Author: Mauricio Garrido,
  first merged 2025, still marked WIP.
- A GitHub search for "rockbox 3ds" found no other maintained port.

Decision: build on upstream instead of writing a new hosted target. This repo
pins upstream as a submodule and carries only tooling, docs and (future) patches.

## Toolchain without pacman/docker/root

devkitPro's pacman repo refuses non-pacman clients, so `scripts/setup-toolchain.sh`:

1. pulls the official `devkitpro/devkitarm` image layers from Docker Hub with
   curl (registry v2 API, sha256-verified) and extracts only `/opt/devkitpro`
   (devkitARM GCC 16.1, libctru, citro2d, citro3d, 3dsxtool, smdhtool, portlibs);
2. builds CTRL and CTRDL (github.com/kynex7510) from pinned commits with the
   devkitPro CMake toolchain file and installs them into `portlibs/3ds`;
3. downloads makerom (3DSGuy/Project_CTR) and bannertool
   (carstene1ns/3ds-bannertool) release binaries for CIA packaging.

The image tag is `latest` (override with `DEVKITARM_IMAGE_TAG`); pinning a
digest is a TODO for reproducibility.

## Emulator testing

Azahar has no headless mode and its AppImage only ships xcb/wayland Qt
plugins. `scripts/run-emulator.sh` with `NESTED=1` runs it in Xephyr with
llvmpipe GL, `scripts/emu-keys.py` injects keys via XTEST, and Azahar's
`-d file.mkv` dumps both screens plus audio, which gives screenshots and an
audio check without touching the real desktop session or config
(XDG dirs point into `build/emu`).

Emulator-only caveats seen: `mcu::HWC` (volume slider, battery) and
`gsp::Lcd` backlight calls are unimplemented in Azahar and just log errors;
ndsp needs a placeholder `dspfirm.cdc`.

## Roadmap

1. Test on a real Old 3DS (performance at 268 MHz, codecs beyond FLAC,
   sleep/lid, HOME button - upstream has a TODO for aptMainLoop handling).
2. Use the top screen for something useful (album art / WPS) instead of the
   debug console in non-debug builds.
3. CI: build the .3dsx/.cia in GitHub Actions using the devkitpro container.
4. Later, separate phase: a native bare-metal Rockbox target (own drivers for
   SD, LCD, codec/I2S, MCU), in the spirit of a real Rockbox firmware port.
   Nothing exists for that yet.
