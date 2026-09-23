import Foundation

/// Onsets within one beat. Supports even subdivisions and common mixed rhythms.
enum MetroPattern: String, CaseIterable, Identifiable, Hashable {
  case quarter
  case eighth
  case sixteenth
  /// 前八后十六 — eighth + two sixteenths (durations 2:1:1).
  case eighthThen16ths
  /// 前十六后八 — two sixteenths + eighth (durations 1:1:2).
  case sixteenthsThenEighth

  var id: String { rawValue }

  var label: String {
    switch self {
    case .quarter: return "♩"
    case .eighth: return "♫"
    case .sixteenth: return "♬"
    case .eighthThen16ths: return "♪♬"
    case .sixteenthsThenEighth: return "♬♪"
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .quarter: return "Quarter notes"
    case .eighth: return "Eighth notes"
    case .sixteenth: return "Sixteenth notes"
    case .eighthThen16ths: return "Eighth then sixteenths"
    case .sixteenthsThenEighth: return "Sixteenths then eighth"
    }
  }

  /// Attack times in one beat, range [0, 1).
  var onsets: [Double] {
    switch self {
    case .quarter: return [0]
    case .eighth: return [0, 0.5]
    case .sixteenth: return [0, 0.25, 0.5, 0.75]
    case .eighthThen16ths: return [0, 0.5, 0.75]
    case .sixteenthsThenEighth: return [0, 0.25, 0.5]
    }
  }

  /// Relative cell heights for the beat grid (sum arbitrary).
  var cellWeights: [CGFloat] {
    let ends = onsets + [1]
    return zip(ends, ends.dropFirst()).map { CGFloat($1 - $0) }
  }
}
