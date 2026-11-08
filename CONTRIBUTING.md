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
| `Sources/Catalog.swift` | The 100+ mouse models and how devices are matched to them |
| `Sources/IconArt.swift` | Every icon, drawn in code (no image files) |
| `Sources/DevTools.swift` | Renders the README screenshots, app icon and social preview |

## Adding a mouse

Add one line to `Catalog.rows` in `Sources/Catalog.swift`:

```
Brand|Model name|match words|shape|body hex|accent hex|flags
```

`match words` is matched against the name the device reports (case and punctuation ignored); the longest
match wins. Shapes: `ambi`, `ergo`, `ambiLite`, `ergoLite` (honeycomb), `office`, `compact`, `vert`,
`ball`, `flat`, `trackpad`, `laptop`. Flag `rgb` adds a glow strip.

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
