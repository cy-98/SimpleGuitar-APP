import Foundation

struct FretPosition: Identifiable, Equatable {
  let id: String
  let label: String
  let fretFrom: Int
  let fretTo: Int
}

struct FretDot: Identifiable, Equatable {
  var id: String { "\(string):\(fret)" }
  let string: Int
  let fret: Int
  let midi: Int
  let degree: ScaleDegree
  let isTonic: Bool
}

enum Fretboard {
  static let fretMin = 0
  static let fretMax = 12
  /// String 0 = high E … 5 = low E
  static let standardTuningMidi = [64, 59, 55, 50, 45, 40]
  static let stringLabels = ["e", "B", "G", "D", "A", "E"]

  static let positions: [FretPosition] = [
    FretPosition(id: "all", label: "All", fretFrom: fretMin, fretTo: fretMax),
    FretPosition(id: "open", label: "Open", fretFrom: 0, fretTo: 4),
    FretPosition(id: "mid-low", label: "3–7", fretFrom: 3, fretTo: 7),
    FretPosition(id: "mid", label: "5–9", fretFrom: 5, fretTo: 9),
    FretPosition(id: "mid-high", label: "7–11", fretFrom: 7, fretTo: 11),
    FretPosition(id: "high", label: "9–12", fretFrom: 9, fretTo: 12),
  ]

  static func getPosition(_ id: String) -> FretPosition {
    positions.first { $0.id == id } ?? positions[0]
  }

  static func inPosition(fret: Int, pos: FretPosition) -> Bool {
    if pos.id == "all" { return true }
    return fret >= pos.fretFrom && fret <= pos.fretTo
  }

  static func scaleDots(key: String) -> [FretDot] {
    let degrees = Scales.majorScaleDegrees(root: key)
    var byPc: [Int: ScaleDegree] = [:]
    for d in degrees {
      if let pc = Pitch.notePitchClass(d.note) {
        byPc[pc] = d
      }
    }
    var dots: [FretDot] = []
    for s in 0..<6 {
      for fret in fretMin...fretMax {
        let midi = standardTuningMidi[s] + fret
        let pc = ((midi % 12) + 12) % 12
        guard let degree = byPc[pc] else { continue }
        dots.append(
          FretDot(
            string: s,
            fret: fret,
            midi: midi,
            degree: degree,
            isTonic: degree.degree == 1
          )
        )
      }
    }
    return dots
  }
}
