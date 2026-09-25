import CoreGraphics
import Foundation

/// Pure metronome timeline math (no audio / timers). Used by `MetronomeEngine` and unit tests.
struct MetroTimeline: Equatable {
  var bpm: Int
  var beatsPerBar: Int
  var pattern: MetroPattern
  var muteUpbeats: Bool
  var accents: [Bool]

  init(
    bpm: Int = 100,
    beatsPerBar: Int = 4,
    pattern: MetroPattern = .quarter,
    muteUpbeats: Bool = true,
    accents: [Bool] = [true, false, false, false]
  ) {
    self.bpm = bpm
    self.beatsPerBar = beatsPerBar
    self.pattern = pattern
    self.muteUpbeats = muteUpbeats
    self.accents = accents
  }

  /// Duration of one beat in seconds.
  func beatSeconds() -> Double {
    60.0 / Double(max(1, bpm))
  }

  /// Absolute time of tick `n` (0-based) from an arbitrary anchor, in seconds.
  func seconds(forTick n: Int) -> Double {
    let onsets = pattern.onsets
    let perBeat = max(1, onsets.count)
    let beat = n / perBeat
    let sub = n % perBeat
    let dur = beatSeconds()
    return Double(beat) * dur + onsets[sub] * dur
  }

  /// Beat / subdiv / accent / audible for absolute tick index `n`.
  func info(forTick n: Int) -> TickInfo {
    let onsets = pattern.onsets
    let perBeat = max(1, onsets.count)
    let absoluteBeat = n / perBeat
    let subdiv = n % perBeat
    let beatIndex = absoluteBeat % max(1, beatsPerBar)
    let downbeatAccent = accents.indices.contains(beatIndex) ? accents[beatIndex] : (beatIndex == 0)
    let accent = subdiv == 0 && downbeatAccent
    let upbeat = subdiv != 0
    let audible = !upbeat || !muteUpbeats
    return TickInfo(
      beatIndex: beatIndex,
      subdivIndex: subdiv,
      accent: accent,
      audible: audible
    )
  }

  /// Number of ticks in one bar.
  var ticksPerBar: Int {
    max(1, pattern.onsets.count) * max(1, beatsPerBar)
  }
}
