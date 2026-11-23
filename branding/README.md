# Legix brand assets

- `legix-mark.svg`: the logo (V5, "visor with L fins"). viewBox 0 0 200 200.
- `legix-logo.txt`: the mark as fastfetch ASCII art (colour slots `$1` visor, `$2` fins,
  `$3`/`$4` gem).
- `legix-wordmark.svg`: "LEGIX" in Chakra Petch Bold, outlined to paths (no font needed).
- `plymouth/`: the logo split into the parts the boot animation moves (`l-left`,
  `l-right`, `v`, `gem`, `gem-glow`), each on the same 200×200 canvas, plus the
  wordmark and progress-bar swatches. The image build renders them to PNG
  (`build_files/plymouth/render.sh`) for the `legix` Plymouth theme.

Palette: Forge Red `#E5432D`, fins `#B8321F`, Ember `#FF6A3D` / `#FF9A55`, Ash `#0B0C0E`,
Steel `#ECEEF1`. Design canvas: https://claude.ai/artifact/QnhNk1iYRTaemyE6tRh2LG

`ChakraPetch-Bold.ttf` is used to draw the wordmark in the Steam videos.
The Steam videos use a pure black background, not Ash. They can't be transparent,
and Steam draws black around the suspend video, so any other colour shows up as a box.

`superseded-video-md5sums`: checksums of earlier Legix Steam videos. Add the old
sums here whenever the videos change, so `legix-steam-videos` replaces copies
users already have.

Chakra Petch is licensed under the SIL Open Font License 1.1 (`plymouth/ChakraPetch-OFL.txt`).
Legix is not affiliated with or endorsed by Lenovo.
