import Foundation

enum Pitch {
  private static let naturalPC: [Character: Int] = [
    "C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11,
  ]

  static func notePitchClass(_ note: String) -> Int? {
    guard let first = note.uppercased().first,
          let base = naturalPC[first] else { return nil }
    var accidental = 0
    for ch in note.dropFirst() {
      if ch == "#" || ch == "\u{266F}" { accidental += 1 }
      else if ch == "b" || ch == "\u{266D}" { accidental -= 1 }
    }
    return ((base + accidental) % 12 + 12) % 12
  }

  static func noteToMidi(_ note: String, octave: Int = 4) -> Int? {
    guard let pc = notePitchClass(note) else { return nil }
    return (octave + 1) * 12 + pc
  }

  static func midiToFreq(_ midi: Int) -> Double {
    440 * pow(2, Double(midi - 69) / 12)
  }

  static func midiToFreq(_ midi: Double) -> Double {
    440 * pow(2, (midi - 69) / 12)
  }

  /// Continuous MIDI from Hz (A4 = 69 @ 440 Hz).
  static func freqToMidi(_ freq: Double) -> Double? {
    guard freq.isFinite, freq > 0 else { return nil }
    return 69 + 12 * log2(freq / 440)
  }

  private static let sharpNames = [
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B",
  ]

  /// Nearest spelled note + cents offset (−50…+50 before wrap).
  static func midiToNearestNote(_ midi: Double) -> (name: String, octave: Int, cents: Double, midiRounded: Int) {
    let midiRounded = Int(midi.rounded())
    let cents = (midi - Double(midiRounded)) * 100
    let pc = ((midiRounded % 12) + 12) % 12
    let octave = midiRounded / 12 - 1
    return (sharpNames[pc], octave, cents, midiRounded)
  }

  /// Cents from a target MIDI pitch (e.g. open string).
  static func centsFromTarget(_ midi: Double, targetMidi: Double) -> Double {
    (midi - targetMidi) * 100
  }

  /// Standard guitar open strings, thick → thin (6 → 1).
  static let guitarOpenMidi = [40, 45, 50, 55, 59, 64]
}
