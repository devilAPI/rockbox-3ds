# Progress log

## 2026-11-16

- Researched prior art: upstream Rockbox already has a hosted 3DS target; chose to build on it.
- Added upstream as submodule at 0ee9d424f9d7b47c849d7e4447898a1fe686d1f3.
- Toolchain: extracted devkitARM/libctru from the devkitpro/devkitarm Docker
  image via curl; built CTRL + CTRDL from source; fetched makerom + bannertool.
- `configure --target=3ds --type=N && make && make fullzip` builds cleanly with
  devkitARM GCC 16.1.0, no patches: rockbox.3dsx (1.2 MB), rockbox.cia, rockbox-full.zip (81 MB).
- Azahar 2126.2 (Xephyr + llvmpipe): boots to main menu; D-pad/A navigate
  Files -> Music; a generated 440 Hz FLAC plays (flac.codec loaded through
  CTRDL, WPS progress advances, A/V dump audio RMS about -28 dBFS).
  Without sdmc:/3ds/dspfirm.cdc playback stays at 0:00 (ndspInit fails).
- Not verified: the pitch/quality of the output, any real hardware, other codecs, plugins, CIA.
