import Foundation

/// One guitar voicing: index 0 = high e … 5 = low E. `nil` = muted.
struct ChordDiagram: Equatable {
  let frets: [Int?]
  var baseFret: Int {
    frets.compactMap { $0 }.filter { $0 > 0 }.min() ?? 0
  }

  var windowStart: Int {
    let base = baseFret
    return base <= 1 ? 1 : base
  }
}

enum ChordShapes {
  private static var cache: [String: ChordDiagram] = [:]
  private static let cacheLock = NSLock()

  /// Prefer open / common shapes; fall back to E- or A-form barre (no DFS).
  static func diagram(for chord: DiatonicChord) -> ChordDiagram? {
    let key = "\(chord.root)|\(chord.quality.rawValue)"
    cacheLock.lock()
    if let hit = cache[key] {
      cacheLock.unlock()
      return hit
    }
    cacheLock.unlock()

    guard let rootPc = Pitch.notePitchClass(chord.root) else { return nil }
    let frets =
      openShape(rootPc: rootPc, quality: chord.quality)
      ?? barreShape(rootPc: rootPc, quality: chord.quality)
    guard let frets else { return nil }
    let diagram = ChordDiagram(frets: frets)

    cacheLock.lock()
    if cache.count > 64 { cache.removeAll(keepingCapacity: true) }
    cache[key] = diagram
    cacheLock.unlock()
    return diagram
  }

  // MARK: - Open (high e → low E)

  private static func openShape(rootPc: Int, quality: ChordQuality) -> [Int?]? {
    switch quality {
    case .major:
      switch rootPc {
      case 0: return [0, 1, 0, 2, 3, nil]
      case 2: return [2, 3, 2, 0, nil, nil]
      case 4: return [0, 0, 1, 2, 2, 0]
      case 5: return [1, 1, 2, 3, 3, 1]
      case 7: return [3, 0, 0, 0, 2, 3]
      case 9: return [0, 2, 2, 2, 0, nil]
      case 10: return [1, 3, 3, 3, 1, nil]
      case 11: return [2, 4, 4, 4, 2, nil]
      default: return nil
      }
    case .minor:
      switch rootPc {
      case 0: return [3, 4, 5, 5, 3, nil]
      case 2: return [1, 3, 2, 0, nil, nil]
      case 4: return [0, 0, 0, 2, 2, 0]
      case 5: return [1, 1, 1, 3, 3, 1]
      case 6: return [2, 2, 2, 4, 4, 2]
      case 7: return [3, 3, 3, 5, 5, 3]
      case 9: return [0, 1, 2, 2, 0, nil]
      case 10: return [1, 2, 3, 3, 1, nil]
      case 11: return [2, 3, 4, 4, 2, nil]
      default: return nil
      }
    case .diminished:
      // Movable dim shape relative to open Bdim (x x 0 1 0 1) shifted by root.
      // Root on G string (index 2) at fret f → [f+1, f, f+1, f, nil, nil]
      let openG = 7 // G pitch class
      let f = (rootPc - openG + 12) % 12
      if f <= 8 {
        return [f + 1, f, f + 1, f, nil, nil]
      }
      return nil
    }
  }

  // MARK: - Barre (E-form / A-form)

  private static func barreShape(rootPc: Int, quality: ChordQuality) -> [Int?]? {
    let eFret = (rootPc - 4 + 12) % 12
    let aFret = (rootPc - 9 + 12) % 12

    switch quality {
    case .major:
      if eFret >= 1 && eFret <= 8 {
        let f = eFret
        return [f, f, f + 1, f + 2, f + 2, f]
      }
      if aFret >= 1 && aFret <= 8 {
        let f = aFret
        return [f, f + 2, f + 2, f + 2, f, nil]
      }
    case .minor:
      if eFret >= 1 && eFret <= 8 {
        let f = eFret
        return [f, f, f, f + 2, f + 2, f]
      }
      if aFret >= 1 && aFret <= 8 {
        let f = aFret
        return [f, f + 1, f + 2, f + 2, f, nil]
      }
    case .diminished:
      if aFret >= 1 && aFret <= 7 {
        let f = aFret
        return [nil, f + 2, f + 3, f + 4, f, nil]
      }
      if eFret >= 1 && eFret <= 7 {
        let f = eFret
        return [f + 1, f, f + 1, f, nil, f]
      }
    }
    return nil
  }
}
