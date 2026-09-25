import XCTest
@testable import ScalePulse

final class TunerGeometryMathTests: XCTestCase {
  func testDefaultTargetsMatchGuitarOpen() {
    let targets = TunerGeometry.defaultStringTargets()
    XCTAssertEqual(targets[.six], 40)
    XCTAssertEqual(targets[.five], 45)
    XCTAssertEqual(targets[.four], 50)
    XCTAssertEqual(targets[.three], 55)
    XCTAssertEqual(targets[.two], 59)
    XCTAssertEqual(targets[.one], 64)
  }

  func testColumnOrderIsThickToThinLeftToRight() {
    XCTAssertEqual(
      TunerLayout.tabColumns,
      [.six, .five, .four, .three, .two, .one]
    )
    XCTAssertEqual(TunerGeometry.columnIndex(for: .six), 0)
    XCTAssertEqual(TunerGeometry.columnIndex(for: .one), 5)
  }

  func testPitchYAtTargetIsNut() {
    let y = TunerGeometry.pitchYOnString(midi: 40, targetMidi: 40)
    XCTAssertEqual(y, TunerGeometry.nutYPercent(), accuracy: 1e-9)
  }

  func testPitchYTwelveFretsReachesBodyLine() {
    let y = TunerGeometry.pitchYOnString(midi: 52, targetMidi: 40) // +12
    XCTAssertEqual(Double(y), Double(TunerLayout.fretBodyYPercent), accuracy: 1e-9)
  }

  func testPitchYHigherPitchMovesDown() {
    let open = TunerGeometry.pitchYOnString(midi: 64, targetMidi: 64)
    let sharp = TunerGeometry.pitchYOnString(midi: 66, targetMidi: 64)
    XCTAssertGreaterThan(sharp, open)
  }

  func testTargetMidiFromNutIsFactoryOpen() {
    for id in TunerLayout.tabColumns {
      let midi = TunerGeometry.targetMidiFromTrackY(id: id, yPercentFromTop: TunerLayout.nutYPercent)
      XCTAssertEqual(midi, TunerGeometry.defaultOpenMidi(id))
    }
  }

  func testTargetMidiFromBodyIsPlusTwelveWhenInRange() {
    // Low E open 40 + 12 = 52, within midiMax 70
    let midi = TunerGeometry.targetMidiFromTrackY(id: .six, yPercentFromTop: TunerLayout.fretBodyYPercent)
    XCTAssertEqual(midi, 40 + TunerLayout.tuningSemitoneMax)
  }

  func testTargetMidiAboveNutGoesFlat() {
    let midi = TunerGeometry.targetMidiFromTrackY(id: .six, yPercentFromTop: 0)
    XCTAssertEqual(midi, 40 + TunerLayout.tuningSemitoneMin)
  }

  func testTargetMidiClampedToGlobalRange() {
    // High e open 64 + 12 = 76 but midiMax = 70
    let midi = TunerGeometry.targetMidiFromTrackY(id: .one, yPercentFromTop: 100)
    XCTAssertLessThanOrEqual(midi, TunerLayout.midiMax)
    XCTAssertEqual(midi, TunerLayout.midiMax)
  }

  func testGlobalPitchYMonotonic() {
    let low = TunerGeometry.globalPitchY(midi: Double(TunerLayout.midiMin))
    let mid = TunerGeometry.globalPitchY(midi: 52)
    let high = TunerGeometry.globalPitchY(midi: Double(TunerLayout.midiMax))
    XCTAssertEqual(low, TunerGeometry.globalYTop, accuracy: 1e-9)
    XCTAssertEqual(high, TunerGeometry.globalYBottom, accuracy: 1e-9)
    XCTAssertGreaterThan(mid, low)
    XCTAssertGreaterThan(high, mid)
  }

  func testGlobalPitchXMatchesAxis() {
    XCTAssertEqual(
      TunerGeometry.globalPitchX(midi: 52),
      TunerGeometry.globalPitchY(midi: 52),
      accuracy: 1e-9
    )
  }

  func testEvenColumnsAreUniform() {
    let xs = (0..<6).map { TunerGeometry.evenColumnX(index: $0) }
    XCTAssertEqual(xs[0], TunerGeometry.stringAxisStart, accuracy: 1e-9)
    XCTAssertEqual(xs[5], TunerGeometry.globalAxisEnd, accuracy: 1e-9)
    let gaps = zip(xs, xs.dropFirst()).map { $1 - $0 }
    for g in gaps {
      XCTAssertEqual(g, gaps[0], accuracy: 1e-9)
    }
  }

  func testDetectionXSilentIsZeroHzEdge() {
    let targets = TunerGeometry.defaultStringTargets()
    XCTAssertEqual(
      TunerGeometry.detectionXPercent(freq: 0, midi: nil, targets: targets),
      TunerGeometry.zeroHzX,
      accuracy: 1e-9
    )
    // 0 Hz is off-screen; first string is the start of the visible band.
    XCTAssertLessThan(TunerGeometry.zeroHzX, 0)
    XCTAssertLessThan(TunerGeometry.zeroHzX, TunerGeometry.stringAxisStart)
    XCTAssertEqual(TunerGeometry.evenColumnX(index: 0), TunerGeometry.stringAxisStart, accuracy: 1e-9)
  }

  func testDetectionXHitsEvenColumnWhenInTune() {
    let targets = TunerGeometry.defaultStringTargets()
    for (i, id) in TunerLayout.tabColumns.enumerated() {
      let midi = Double(targets[id]!)
      let freq = Pitch.midiToFreq(midi)
      let x = TunerGeometry.detectionXPercent(freq: freq, midi: midi, targets: targets)
      XCTAssertEqual(x, TunerGeometry.evenColumnX(index: i), accuracy: 1e-6)
    }
  }

  func testMidiFromGlobalYRoundTrip() {
    for midi in [40, 45, 55, 64] {
      let y = TunerGeometry.globalPitchY(midi: Double(midi))
      XCTAssertEqual(TunerGeometry.midiFromGlobalY(y), midi)
      XCTAssertEqual(TunerGeometry.midiFromGlobalX(y), midi)
    }
  }

  func testCentsToColumnShiftClamps() {
    XCTAssertEqual(TunerGeometry.centsToColumnShift(0), 0, accuracy: 1e-9)
    XCTAssertEqual(TunerGeometry.centsToColumnShift(50), 42, accuracy: 1e-9)
    XCTAssertEqual(TunerGeometry.centsToColumnShift(-50), -42, accuracy: 1e-9)
    XCTAssertEqual(TunerGeometry.centsToColumnShift(100), 42, accuracy: 1e-9)
    XCTAssertEqual(TunerGeometry.centsToColumnShift(-100), -42, accuracy: 1e-9)
  }

  func testNearestStringPicksClosestTarget() {
    let targets = TunerGeometry.defaultStringTargets()
    XCTAssertEqual(TunerGeometry.nearestString(midi: 40.2, targets: targets), .six)
    XCTAssertEqual(TunerGeometry.nearestString(midi: 64.1, targets: targets), .one)
    XCTAssertEqual(TunerGeometry.nearestString(midi: 55, targets: targets), .three)
  }

  func testTuningPairLabelEEqualsBStyle() {
    // Drop low E (40) to G? Wait - E string to B would be unusual; use A string to B
    // Low E (id 6) retuned to G2 (midi 43): E=G
    XCTAssertEqual(TunerGeometry.tuningPairLabel(id: .six, targetMidi: 43), "E=G")
    // High e to same pitch name different octave should include octave
    let label = TunerGeometry.tuningPairLabel(id: .one, targetMidi: 52) // E3 vs open E4
    XCTAssertTrue(label.hasPrefix("e="))
    XCTAssertTrue(label.contains("3") || label.contains("E"), label)
  }

  func testCustomTuningNotationOnlyChangedStrings() {
    var targets = TunerGeometry.defaultStringTargets()
    XCTAssertEqual(TunerGeometry.customTuningNotation(targets), "Standard open")

    targets[.six] = 38 // D
    let notation = TunerGeometry.customTuningNotation(targets)
    XCTAssertEqual(notation, "E=D")
    XCTAssertFalse(notation.contains("A="))
  }

  func testCustomTuningStoreRoundTrip() {
    let key = "scale-pulse-custom-tuning"
    let previous = UserDefaults.standard.object(forKey: key)
    defer {
      if let previous {
        UserDefaults.standard.set(previous, forKey: key)
      } else {
        UserDefaults.standard.removeObject(forKey: key)
      }
    }

    var targets = TunerGeometry.defaultStringTargets()
    targets[.six] = 38
    targets[.one] = 62
    CustomTuningStore.store(targets)
    let loaded = CustomTuningStore.read()
    XCTAssertEqual(loaded[.six], 38)
    XCTAssertEqual(loaded[.one], 62)
    XCTAssertEqual(loaded[.five], 45)
  }
}
