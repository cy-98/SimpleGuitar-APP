import Foundation

enum ChordQuality: String {
  case major, minor, diminished

  var shortLabel: String {
    switch self {
    case .major: return "maj"
    case .minor: return "min"
    case .diminished: return "dim"
    }
  }

  var symbolSuffix: String {
    switch self {
    case .major: return ""
    case .minor: return "m"
    case .diminished: return "°"
    }
  }
}

struct DiatonicChord: Identifiable, Equatable {
  let degree: Int
  let roman: String
  let root: String
  let quality: ChordQuality
  let notes: [String]

  var id: Int { degree }

  var symbol: String { root + quality.symbolSuffix }

  var notesLabel: String { notes.joined(separator: " · ") }
}

enum Chords {
  /// Major-key triad qualities by scale degree (1…7).
  private static let majorTriadQualities: [ChordQuality] = [
    .major, .minor, .minor, .major, .major, .minor, .diminished,
  ]

  private static let romans = ["I", "ii", "iii", "IV", "V", "vi", "vii°"]

  /// Seven diatonic triads for a major key, spelled with scale-tone accidentals.
  static func diatonicTriads(key: String) -> [DiatonicChord] {
    let scale = Scales.majorScaleNotes(root: key)
    guard scale.count == 7 else { return [] }

    return (0..<7).map { i in
      let notes = [
        scale[i],
        scale[(i + 2) % 7],
        scale[(i + 4) % 7],
      ]
      return DiatonicChord(
        degree: i + 1,
        roman: romans[i],
        root: scale[i],
        quality: majorTriadQualities[i],
        notes: notes
      )
    }
  }
}
