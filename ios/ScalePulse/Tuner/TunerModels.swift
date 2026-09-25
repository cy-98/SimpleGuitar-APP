import Combine
import CoreGraphics
import Foundation

enum TunerStringId: Int, CaseIterable, Hashable, Identifiable {
  case one = 1, two = 2, three = 3, four = 4, five = 5, six = 6
  var id: Int { rawValue }
}

typealias StringTargets = [TunerStringId: Int]

struct TunerReading: Equatable {
  var freq: Double
  var midi: Double
  var note: String
  var octave: Int
  var cents: Double
  var stringId: TunerStringId
  var inTune: Bool
  var level: Double
}

/// High-rate pitch metrics observed only by the needle / Hz label (GuitarTuna-style).
/// Updating this must NOT rebuild the static string chrome.
final class TunerLiveMetrics: ObservableObject {
  struct Snapshot: Equatable {
    var freq: Double = 0
    var midi: Double?
    var inTune = false
    var hasSignal = false
  }

  @Published private(set) var snapshot = Snapshot()

  var freq: Double { snapshot.freq }
  var midi: Double? { snapshot.midi }
  var inTune: Bool { snapshot.inTune }
  var hasSignal: Bool { snapshot.hasSignal }

  func apply(freq: Double, midi: Double, inTune: Bool) {
    let next = Snapshot(freq: freq, midi: midi, inTune: inTune, hasSignal: true)
    if snapshot != next { snapshot = next }
  }

  func clear() {
    guard snapshot.hasSignal || snapshot.freq != 0 || snapshot.midi != nil else { return }
    snapshot = Snapshot()
  }
}

enum TuningMode: String, Hashable {
  case standard, custom
}

enum TunerMicState {
  case pending, live, denied
}

enum TunerLayout {
  /// Columns left → right = 6弦 … 1弦.
  static let tabColumns: [TunerStringId] = [.six, .five, .four, .three, .two, .one]

  static let tabStringNames: [TunerStringId: String] = [
    .six: "E", .five: "A", .four: "D", .three: "G", .two: "B", .one: "e",
  ]

  static let yinThreshold: Float = 0.12
  static let minFreq: Double = 65
  static let maxFreq: Double = 520
  static let inTuneCents: Double = 5
  static let rmsGate: Float = 0.005

  static let midiMin = Pitch.guitarOpenMidi[0] - 6
  static let midiMax = Pitch.guitarOpenMidi[5] + 6

  static let nutYPercent: CGFloat = 10
  static let visibleFrets: CGFloat = 12
  static let fretBodyYPercent: CGFloat = 92

  static let tuningSemitoneMin = -6
  static let tuningSemitoneMax = 12
}

enum TunerGeometry {
  static func defaultStringTargets() -> StringTargets {
    [
      .six: Pitch.guitarOpenMidi[0],
      .five: Pitch.guitarOpenMidi[1],
      .four: Pitch.guitarOpenMidi[2],
      .three: Pitch.guitarOpenMidi[3],
      .two: Pitch.guitarOpenMidi[4],
      .one: Pitch.guitarOpenMidi[5],
    ]
  }

  static func tabStringName(_ id: TunerStringId) -> String {
    TunerLayout.tabStringNames[id] ?? "?"
  }

  static func columnIndex(for id: TunerStringId) -> Int {
    TunerLayout.tabColumns.firstIndex(of: id) ?? 0
  }

  static func defaultOpenMidi(_ id: TunerStringId) -> Int {
    defaultStringTargets()[id]!
  }

  static func nutYPercent() -> CGFloat { TunerLayout.nutYPercent }

  /// Y on a string: nut at headstock; higher pitch → toward body (down).
  static func pitchYOnString(midi: Double, targetMidi: Double) -> CGFloat {
    let semitones = midi - targetMidi
    let clamped = max(-0.55, min(Double(TunerLayout.visibleFrets) + 0.55, semitones))
    let travel = TunerLayout.fretBodyYPercent - TunerLayout.nutYPercent
    return TunerLayout.nutYPercent + CGFloat(clamped / Double(TunerLayout.visibleFrets)) * travel
  }

  /// Map pointer Y → target MIDI (nut = factory open; down = sharp, up = flat).
  static func targetMidiFromTrackY(id: TunerStringId, yPercentFromTop: CGFloat) -> Int {
    let y = max(0, min(100, yPercentFromTop))
    let nut = TunerLayout.nutYPercent
    var semitones = 0
    if y <= nut {
      let upTravel = max(1, nut)
      let up = (nut - y) / upTravel
      semitones = -Int((up * CGFloat(abs(TunerLayout.tuningSemitoneMin))).rounded())
    } else {
      let downTravel = TunerLayout.fretBodyYPercent - nut
      let down = (y - nut) / downTravel
      semitones = Int((down * CGFloat(TunerLayout.tuningSemitoneMax)).rounded())
    }
    semitones = max(TunerLayout.tuningSemitoneMin, min(TunerLayout.tuningSemitoneMax, semitones))
    let midi = defaultOpenMidi(id) + semitones
    return max(TunerLayout.midiMin, min(TunerLayout.midiMax, midi))
  }

  static func tuningTargetName(targetMidi: Int, referenceMidi: Int) -> String {
    let nearest = Pitch.midiToNearestNote(Double(targetMidi))
    let refOct = Pitch.midiToNearestNote(Double(referenceMidi)).octave
    if nearest.octave != refOct { return "\(nearest.name)\(nearest.octave)" }
    return nearest.name
  }

  static func tuningPairLabel(id: TunerStringId, targetMidi: Int) -> String {
    let open = tabStringName(id)
    let ref = defaultOpenMidi(id)
    let target = tuningTargetName(targetMidi: targetMidi, referenceMidi: ref)
    return "\(open)=\(target)"
  }

  static func isDefaultTuningTarget(id: TunerStringId, targetMidi: Int) -> Bool {
    targetMidi == defaultOpenMidi(id)
  }

  /// Left → right; only strings that differ from factory.
  static func customTuningNotation(_ targets: StringTargets) -> String {
    let parts = TunerLayout.tabColumns.compactMap { id -> String? in
      guard let midi = targets[id], !isDefaultTuningTarget(id: id, targetMidi: midi) else { return nil }
      return tuningPairLabel(id: id, targetMidi: midi)
    }
    return parts.isEmpty ? "Standard open" : parts.joined(separator: " ")
  }

  /// Horizontal nudge within a column (−50…+50 cents → roughly ±42%).
  static func centsToColumnShift(_ cents: Double) -> CGFloat {
    let c = max(-50, min(50, cents))
    return CGFloat(c / 50) * 42
  }

  /// Virtual 0 Hz — off-screen to the leading side. Phone viewport shows the six strings only.
  static let zeroHzX: CGFloat = -28
  /// Visible band: evenly spaced string baselines (E…e).
  static let stringAxisStart: CGFloat = 10
  static let globalAxisEnd: CGFloat = 90

  /// Custom-handle / MIDI axis stays inside the visible string band.
  static let globalAxisStart: CGFloat = stringAxisStart

  static let globalYTop: CGFloat = globalAxisStart
  static let globalYBottom: CGFloat = globalAxisEnd

  /// Six string baselines: equal gaps across the on-screen band.
  static func evenColumnX(index: Int, count: Int = TunerLayout.tabColumns.count) -> CGFloat {
    guard count > 1 else { return 50 }
    let i = max(0, min(count - 1, index))
    let t = CGFloat(i) / CGFloat(count - 1)
    return stringAxisStart + t * (globalAxisEnd - stringAxisStart)
  }

  static func evenColumnX(for id: TunerStringId) -> CGFloat {
    evenColumnX(index: columnIndex(for: id))
  }

  private static func targetMidis(_ targets: StringTargets) -> [Double] {
    TunerLayout.tabColumns.map { Double(targets[$0] ?? defaultOpenMidi($0)) }
  }

  private static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
    a + CGFloat(max(0, min(1, t))) * (b - a)
  }

  /// Detection line: 0 Hz at `zeroHzX`; live pitch interpolates across even string columns.
  static func detectionXPercent(freq: Double, midi: Double?, targets: StringTargets) -> CGFloat {
    guard freq > 0, let midi else { return zeroHzX }

    let midis = targetMidis(targets)
    guard let first = midis.first, let last = midis.last else { return zeroHzX }

    if midi <= first {
      let firstFreq = max(Pitch.midiToFreq(first), 1)
      let t = max(0, min(1, freq / firstFreq))
      return lerp(zeroHzX, evenColumnX(index: 0), t)
    }
    if midi >= last {
      let hi = Double(TunerLayout.midiMax)
      let span = max(0.001, hi - last)
      let lastIndex = TunerLayout.tabColumns.count - 1
      return lerp(evenColumnX(index: lastIndex), globalAxisEnd, (midi - last) / span)
    }

    for i in 0..<(midis.count - 1) {
      if midi <= midis[i + 1] {
        let span = max(0.001, midis[i + 1] - midis[i])
        return lerp(evenColumnX(index: i), evenColumnX(index: i + 1), (midi - midis[i]) / span)
      }
    }
    return evenColumnX(index: TunerLayout.tabColumns.count - 1)
  }

  /// Inverse of detection mapping (custom-mode drag along the detection axis).
  static func midiFromDetectionX(_ percent: CGFloat, targets: StringTargets) -> Int {
    let midis = targetMidis(targets)
    guard let first = midis.first, let last = midis.last else {
      return TunerLayout.midiMin
    }
    let x = max(zeroHzX, min(globalAxisEnd, percent))
    let firstX = evenColumnX(index: 0)
    let lastX = evenColumnX(index: TunerLayout.tabColumns.count - 1)

    if x <= firstX {
      let span = max(0.001, firstX - zeroHzX)
      let t = Double((x - zeroHzX) / span)
      let firstFreq = Pitch.midiToFreq(first)
      let freq = t * firstFreq
      guard let midi = Pitch.freqToMidi(max(freq, 1)), freq > 0 else {
        return TunerLayout.midiMin
      }
      return max(TunerLayout.midiMin, min(TunerLayout.midiMax, Int(midi.rounded())))
    }
    if x >= lastX {
      let span = max(0.001, globalAxisEnd - lastX)
      let t = Double((x - lastX) / span)
      let midi = last + t * (Double(TunerLayout.midiMax) - last)
      return max(TunerLayout.midiMin, min(TunerLayout.midiMax, Int(midi.rounded())))
    }

    for i in 0..<(midis.count - 1) {
      let a = evenColumnX(index: i)
      let b = evenColumnX(index: i + 1)
      if x <= b {
        let span = max(0.001, b - a)
        let t = Double((x - a) / span)
        let midi = midis[i] + t * (midis[i + 1] - midis[i])
        return max(TunerLayout.midiMin, min(TunerLayout.midiMax, Int(midi.rounded())))
      }
    }
    return Int(last.rounded())
  }

  /// Global pitch map along an axis (low MIDI near start, high MIDI toward end).
  static func globalPitchAxis(_ midi: Double) -> CGFloat {
    let lo = Double(TunerLayout.midiMin)
    let hi = Double(TunerLayout.midiMax)
    let span = max(1, hi - lo)
    let t = max(0, min(1, (midi - lo) / span))
    return globalAxisStart + CGFloat(t) * (globalAxisEnd - globalAxisStart)
  }

  static func globalPitchY(midi: Double) -> CGFloat { globalPitchAxis(midi) }
  static func globalPitchX(midi: Double) -> CGFloat { globalPitchAxis(midi) }

  static func midiFromGlobalAxis(_ percent: CGFloat) -> Int {
    let travel = globalAxisEnd - globalAxisStart
    let t = Double((max(globalAxisStart, min(globalAxisEnd, percent)) - globalAxisStart) / travel)
    let midi = Double(TunerLayout.midiMin) + t * Double(TunerLayout.midiMax - TunerLayout.midiMin)
    return max(TunerLayout.midiMin, min(TunerLayout.midiMax, Int(midi.rounded())))
  }

  static func midiFromGlobalY(_ yPercentFromTop: CGFloat) -> Int { midiFromGlobalAxis(yPercentFromTop) }
  static func midiFromGlobalX(_ xPercentFromLeading: CGFloat) -> Int { midiFromGlobalAxis(xPercentFromLeading) }

  static func nearestString(midi: Double, targets: StringTargets) -> TunerStringId {
    var best: TunerStringId = .six
    var bestDist = Double.infinity
    for id in TunerLayout.tabColumns {
      let dist = abs(midi - Double(targets[id] ?? defaultOpenMidi(id)))
      if dist < bestDist {
        bestDist = dist
        best = id
      }
    }
    return best
  }
}

enum CustomTuningStore {
  private static let key = "scale-pulse-custom-tuning"

  static func read() -> StringTargets {
    var base = TunerGeometry.defaultStringTargets()
    guard let raw = UserDefaults.standard.dictionary(forKey: key) else {
      return base
    }
    for id in TunerLayout.tabColumns {
      let key = String(id.rawValue)
      let value: Int?
      if let n = raw[key] as? NSNumber {
        value = n.intValue
      } else if let v = raw[key] as? Int {
        value = v
      } else if let d = raw[key] as? Double {
        value = Int(d.rounded())
      } else {
        value = nil
      }
      if let value {
        base[id] = max(TunerLayout.midiMin, min(TunerLayout.midiMax, value))
      }
    }
    return base
  }

  static func store(_ targets: StringTargets) {
    var dict: [String: Int] = [:]
    for id in TunerLayout.tabColumns {
      dict[String(id.rawValue)] = targets[id] ?? TunerGeometry.defaultOpenMidi(id)
    }
    UserDefaults.standard.set(dict, forKey: key)
  }
}
