# Contributing to Squeak

Thanks for helping! Bug reports, missing mouse models, and ideas are all welcome as
[issues](https://github.com/Ranbo-codez/Squeak/issues). Pull requests are limited to collaborators.

## Building

You only need Apple's Command Line Tools (`xcode-select --install`). No Xcode project, no dependencies.

```bash
./build.sh            # build/Squeak.app (universal: Apple silicon + Intel)
./build.sh --install  # also copy to ~/Applications and launch it
./build.sh --dmg      # also make build/Squeak.dmg
```

## Code map

| File | What it does |
| --- | --- |
| `Sources/main.swift` | Menu-bar item, popover, app lifecycle |
| `Sources/Engine.swift` | Device detection (IOKit notifications), per-device speed, app rules, settings |
| `Sources/Scaler.swift` | Exact in-game multiplier (event tap) and game calibration |
| `Sources/UI.swift` | The panel (plain AppKit, built on demand and freed when closed) |
| `Sources/Catalog.swift` | The 106 mouse models and how devices are matched to them |
| `Sources/IconArt.swift` | Every icon, drawn in code (no image files) |
| `Sources/DevTools.swift` | Renders the README screenshots, app icon and social preview |

## Adding a mouse

Add one line to `Catalog.rows` in `Sources/Catalog.swift`:

```
Brand|Model name|match words|shape|body hex|accent hex|flags
```

`match words` is matched against the name the device reports (case and punctuation ignored); the longest
match wins. Shapes: `ambi`, `ergo`, `ambiLite`, `ergoLite` (lightweight shell), `office`, `compact`, `vert`,
`ball`, `flat`, `trackpad`, `laptop`.

Flags (space-separated) make the icon look like that model:

| Flag | Effect |
| --- | --- |
| `rgb`, `cable`, `dpi`, `sniper`, `paddle`, `wing`, `grid` | glow strip, cable, DPI button, sniper button, clutch paddle, wide thumb rest, MMO side grid |
| `side=N`, `rside=N` | thumb-side buttons (left), buttons on the right side too |
| `len=`, `wid=`, `mid=` | body length, width, where the widest point sits (0–1, low = hump at the back) |
| `pat=holes\|hex\|slots\|cut` | shell cut-outs |
| `glyph=tri\|ring\|chev\|bolt\|diamond\|plus\|x\|wave\|hex\|star\|sail\|dot\|none` | palm emblem (generic shapes, never brand logos) |
| `wheel=wide\|metal`, `stripe=hex`, `panel=hex`, `tile=hex` | scroll wheel style, centre stripe, two-tone side panels, tile colour |
| `ball=thumb\|big\|center`, `tilt=`, `nothumb`, `hinge` | trackball layout, vertical-mouse lean, no thumb wheel, Arc-style bend |

Then make sure your icon doesn't look like an existing one:

```bash
./build.sh && build/Squeak.app/Contents/MacOS/Squeak --distinct 15   # fails if any two icons are too alike
```

## README images

Screenshots use made-up demo devices and a throwaway settings folder, never your real hardware:

```bash
B=build/Squeak.app/Contents/MacOS/Squeak; export SQUEAK_DEMO=1 SQUEAK_DATA=$(mktemp -d)
$B --snapshot docs/devices.png;  $B --snapshot docs/devices-dark.png --dark
$B --snapshot docs/device.png Viper;  SQUEAK_CAL=1 $B --snapshot docs/calibrate.png Viper
$B --social docs/social-preview.png
```

## Ground rules

- Keep it tiny: no polling, no timers while idle, no dependencies.
- Keep it private: no network code, nothing leaves the Mac.
- Don't commit real device names, settings files or screenshots of your own setup.
