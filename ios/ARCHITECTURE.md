# Jita iOS — Architecture Overview

Phone-first **metronome + major-scale degree practice**. Spec: [`APP.md`](../APP.md). UI language: English.

---

## 1. Product shape

```
Jita
├── Metro      — tempo / meter / rhythm patterns, per-beat accent, mute upbeats
├── Degrees    — ring chart, diatonic chord dictionary + shapes, fullscreen fretboard
└── Settings   — sound icons, volume, themes
```

Session state (`AppSession`) survives tab switches. Only the active tab is mounted.

---

## 2. Module map

| Layer | Path | Role |
|-------|------|------|
| Shell | `ScalePulseApp` / `RootTabView` | Entry, spring tab pill, theme gradient |
| Session | `Theme/AppSession.swift` | Tab / metro / theory UI state |
| Theme | `Theme/AppSettings.swift` | Themes, sound, volume, mute; UserDefaults |
| Audio | `Audio/TonePlayer.swift` | Soft-synth ticks + piano / chords |
| Metro | `Metro/*` | Host-time engine + patterns + beat UI |
| Theory | `Theory/*` | Pitch / scales / fretboard / chords / shapes |
| Theory UI | `TheoryUI/*` | Ring, chord dict, fretboard |
| Shared | `Shared/SegControl.swift` | Capsule segmented control |

---

## 3. Metronome timing

`MetronomeEngine` schedules on the **audio host timeline**:

- Absolute tick index `n` → `t(n)` (closed form; no interval accumulation).
- Lookahead pump fills `AVAudioPlayerNode` with `scheduleBuffer(at:)`.
- UI flashes on the same timeline (slight visual lead for render latency).
- Patterns: quarter / eighths / 16ths / ♪♬ / ♬♪ (`MetroPattern`).
- Mute upbeats: only onset 0 of each beat sounds; cells still advance.

---

## 4. Audio

`AVAudioEngine` @ 22050 Hz mono. Tick / piano / chord PCM cached. Volume via mixer.

---

## 5. Theory

- **Pitch / Scales**: major spelling, solfege Do–Ti.
- **Fretboard**: EADGBE, frets 0–12, position windows.
- **Chords**: diatonic triads + open/barre diagrams (`ChordShapes`).
- Ring: Do darkest → Ti lightest (cumulative W/H steps); text auto white/ink.

---

## 6. Build

```bash
cd ios && xcodegen generate && open ScalePulse.xcodeproj
```

iOS 17+, Swift 5.9+.

---

## 7. Out of scope

CAGED labels, non-standard tunings, frets > 12, cloud sync, sampled solfege voices.
