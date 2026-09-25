# Jita — iOS (SwiftUI)

Product: [`../APP.md`](../APP.md). Architecture: [`ARCHITECTURE.md`](./ARCHITECTURE.md). **Needs macOS + Xcode.**

## Open

```bash
brew install xcodegen   # if needed
cd ios
xcodegen generate
open ScalePulse.xcodeproj
```

Run `xcodegen generate` after adding/removing source files.

## Features

- **Metro**: BPM / meter / rhythm glyphs, per-beat accent, mute upbeats, host-time clicks
- **Degrees**: ring chart, diatonic chord dictionary + diagrams, fullscreen fretboard
- **Settings**: sound icons, volume, six themes (UserDefaults)

## Layout

```
ios/
├── project.yml
├── ARCHITECTURE.md
└── ScalePulse/
    ├── ScalePulseApp.swift / RootTabView.swift
    ├── Shared/ Theme/ Theory/ Audio/
    ├── Metro/ TheoryUI/ Settings/
    └── Assets.xcassets
```
