import Foundation

struct ScaleDegree: Equatable {
  let degree: Int
  let solfege: String
  let note: String
}

enum Scales {
  static let naturalCycle = ["C", "D", "E", "F", "G", "A", "B"]
  static let majorIntervals = [0, 2, 4, 5, 7, 9, 11]
  static let solfege = ["Do", "Re", "Mi", "Fa", "Sol", "La", "Ti"]
  static let majorKeys = [
    "C", "G", "D", "A", "E", "B", "F#", "F", "Bb", "Eb", "Ab", "Db",
  ]

  private static let naturalPC: [Character: Int] = [
    "C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11,
  ]

  static func isMajorKey(_ value: String) -> Bool {
    majorKeys.contains(value)
  }

  static func majorScaleNotes(root: String) -> [String] {
    let parsed = parseRoot(root)
    let rootPc = ((naturalPC[Character(parsed.letter)]! + parsed.accidental) % 12 + 12) % 12
    let startIdx = naturalCycle.firstIndex(of: parsed.letter)!

    return majorIntervals.enumerated().map { i, semitones in
      let scaleLetter = naturalCycle[(startIdx + i) % 7]
      let natural = naturalPC[Character(scaleLetter)]!
      let target = (rootPc + semitones) % 12
      let acc = normalizeAccidental(target - natural)
      return scaleLetter + formatAccidental(acc)
    }
  }

  static func majorScaleDegrees(root: String) -> [ScaleDegree] {
    let notes = majorScaleNotes(root: root)
    return notes.enumerated().map { i, note in
      ScaleDegree(degree: i + 1, solfege: solfege[i], note: note)
    }
  }

  static func degreesByLetter(root: String) -> [String: ScaleDegree] {
    let letter = parseRoot(root).letter
    let startIdx = naturalCycle.firstIndex(of: letter)!
    let degrees = majorScaleDegrees(root: root)
    var map: [String: ScaleDegree] = [:]
    for i in 0..<degrees.count {
      let scaleLetter = naturalCycle[(startIdx + i) % 7]
      map[scaleLetter] = degrees[i]
    }
    return map
  }

  private struct ParsedRoot {
    let letter: String
    let accidental: Int
  }

  private static func parseRoot(_ root: String) -> ParsedRoot {
    let letter = String(root.prefix(1).uppercased())
    var accidental = 0
    for ch in root.dropFirst() {
      if ch == "#" || ch == "\u{266F}" { accidental += 1 }
      else if ch == "b" || ch == "\u{266D}" { accidental -= 1 }
    }
    return ParsedRoot(letter: letter, accidental: accidental)
  }

  private static func formatAccidental(_ n: Int) -> String {
    if n == 0 { return "" }
    if n > 0 { return String(repeating: "#", count: n) }
    return String(repeating: "b", count: -n)
  }

  private static func normalizeAccidental(_ delta: Int) -> Int {
    var d = ((delta % 12) + 12) % 12
    if d > 6 { d -= 12 }
    return d
  }
}
