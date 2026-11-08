# Security

Squeak changes how your mouse and trackpad behave and, for the in-game multiplier, uses macOS's
Accessibility and Input Monitoring permissions, so security problems matter.

**Please report security problems privately**, not as a public issue:
[report a vulnerability](https://github.com/Ranbo-codez/Squeak/security/advisories/new).
Include what you found, how to reproduce it and which version you used.

## What Squeak does with its permissions

- **Accessibility** lets it scale mouse-movement events, only while an app you gave an in-game multiplier
  to is in front. It never reads, logs or sends keystrokes or what's on screen.
- **Input Monitoring** lets it see *which* device moved (your mouse or your trackpad), so the right
  multiplier applies. It only looks at movement timing, not button presses or anything you type.
- Squeak has no network code. Your settings stay in `~/Library/Application Support/Squeak/settings.json`.

## Downloads

Only the latest release gets security fixes. Download Squeak only from this repository's
[Releases](https://github.com/Ranbo-codez/Squeak/releases) page; copies from anywhere else may have
been changed. Each release lists the SHA-256 of its DMG so you can check your download:

```bash
shasum -a 256 ~/Downloads/Squeak.dmg
```

Releases are ad-hoc signed, not notarised by Apple (that needs a paid developer account). If you'd rather
not trust a prebuilt app, build it yourself from source: it takes about a minute (see the README).
