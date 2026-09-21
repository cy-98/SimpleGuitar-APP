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
}
