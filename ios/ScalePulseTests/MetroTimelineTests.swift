import XCTest
@testable import ScalePulse

final class MetroPatternTests: XCTestCase {
  func testOnsetsStayWithinBeat() {
    for pattern in MetroPattern.allCases {
      XCTAssertFalse(pattern.onsets.isEmpty, pattern.rawValue)
      XCTAssertEqual(pattern.onsets.first ?? -1, 0, accuracy: 1e-12, pattern.rawValue)
      for onset in pattern.onsets {
        XCTAssertGreaterThanOrEqual(onset, 0, pattern.rawValue)
        XCTAssertLessThan(onset, 1, pattern.rawValue)
      }
      assertEqualDoubles(pattern.onsets, pattern.onsets.sorted())
    }
  }

  func testCellWeightsSumToOne() {
    for pattern in MetroPattern.allCases {
      let sum = pattern.cellWeights.reduce(0, +)
      XCTAssertEqual(Double(sum), 1, accuracy: 1e-9, pattern.rawValue)
      XCTAssertEqual(pattern.cellWeights.count, pattern.onsets.count, pattern.rawValue)
    }
  }

  func testEvenSubdivisionOnsets() {
    assertEqualDoubles(MetroPattern.quarter.onsets, [0])
    assertEqualDoubles(MetroPattern.eighth.onsets, [0, 0.5])
    assertEqualDoubles(MetroPattern.sixteenth.onsets, [0, 0.25, 0.5, 0.75])
  }

  func testMixedRhythmOnsets() {
    // 前八后十六 — 2:1:1
    assertEqualDoubles(MetroPattern.eighthThen16ths.onsets, [0, 0.5, 0.75])
    assertEqualDoubles(
      MetroPattern.eighthThen16ths.cellWeights.map { Double($0) },
      [0.5, 0.25, 0.25]
    )
    // 前十六后八 — 1:1:2
    assertEqualDoubles(MetroPattern.sixteenthsThenEighth.onsets, [0, 0.25, 0.5])
    assertEqualDoubles(
      MetroPattern.sixteenthsThenEighth.cellWeights.map { Double($0) },
      [0.25, 0.25, 0.5]
    )
  }
}

final class MetroTimelineTests: XCTestCase {
  func testBeatSecondsFromBpm() {
    XCTAssertEqual(MetroTimeline(bpm: 60).beatSeconds(), 1.0, accuracy: 1e-12)
    XCTAssertEqual(MetroTimeline(bpm: 120).beatSeconds(), 0.5, accuracy: 1e-12)
    XCTAssertEqual(MetroTimeline(bpm: 100).beatSeconds(), 0.6, accuracy: 1e-12)
  }

  func testBpmClampedToAtLeastOne() {
    XCTAssertEqual(MetroTimeline(bpm: 0).beatSeconds(), 60.0, accuracy: 1e-12)
    XCTAssertEqual(MetroTimeline(bpm: -40).beatSeconds(), 60.0, accuracy: 1e-12)
  }

  func testQuarterTickTimesAtSixtyBpm() {
    let tl = MetroTimeline(bpm: 60, beatsPerBar: 4, pattern: .quarter)
    XCTAssertEqual(tl.seconds(forTick: 0), 0, accuracy: 1e-12)
    XCTAssertEqual(tl.seconds(forTick: 1), 1, accuracy: 1e-12)
    XCTAssertEqual(tl.seconds(forTick: 4), 4, accuracy: 1e-12)
  }

  func testEighthTickTimesAtOneTwentyBpm() {
    let tl = MetroTimeline(bpm: 120, beatsPerBar: 4, pattern: .eighth)
    // Beat = 0.5s; onsets 0 and 0.5 → ticks at 0, 0.25, 0.5, 0.75…
    XCTAssertEqual(tl.seconds(forTick: 0), 0.0, accuracy: 1e-12)
    XCTAssertEqual(tl.seconds(forTick: 1), 0.25, accuracy: 1e-12)
    XCTAssertEqual(tl.seconds(forTick: 2), 0.5, accuracy: 1e-12)
    XCTAssertEqual(tl.seconds(forTick: 3), 0.75, accuracy: 1e-12)
  }

  func testSixteenthSpacingIsEven() {
    let tl = MetroTimeline(bpm: 60, pattern: .sixteenth)
    let times = (0..<8).map { tl.seconds(forTick: $0) }
    for i in 1..<times.count {
      XCTAssertEqual(times[i] - times[i - 1], 0.25, accuracy: 1e-12)
    }
  }

  func testMixedPatternSpacing() {
    let tl = MetroTimeline(bpm: 60, pattern: .eighthThen16ths)
    XCTAssertEqual(tl.seconds(forTick: 0), 0.0, accuracy: 1e-12)
    XCTAssertEqual(tl.seconds(forTick: 1), 0.5, accuracy: 1e-12)
    XCTAssertEqual(tl.seconds(forTick: 2), 0.75, accuracy: 1e-12)
    XCTAssertEqual(tl.seconds(forTick: 3), 1.0, accuracy: 1e-12)
  }

  func testBeatIndexWrapsWithinBar() {
    let tl = MetroTimeline(bpm: 100, beatsPerBar: 3, pattern: .quarter)
    XCTAssertEqual(tl.info(forTick: 0).beatIndex, 0)
    XCTAssertEqual(tl.info(forTick: 1).beatIndex, 1)
    XCTAssertEqual(tl.info(forTick: 2).beatIndex, 2)
    XCTAssertEqual(tl.info(forTick: 3).beatIndex, 0)
    XCTAssertEqual(tl.ticksPerBar, 3)
  }

  func testSubdivIndexCyclesWithinBeat() {
    let tl = MetroTimeline(pattern: .sixteenth, muteUpbeats: false)
    for n in 0..<8 {
      XCTAssertEqual(tl.info(forTick: n).subdivIndex, n % 4)
    }
  }

  func testDefaultAccentOnlyOnFirstBeatDownbeat() {
    let tl = MetroTimeline(
      beatsPerBar: 4,
      pattern: .eighth,
      muteUpbeats: false,
      accents: [true, false, false, false]
    )
    XCTAssertTrue(tl.info(forTick: 0).accent)   // beat 0 downbeat
    XCTAssertFalse(tl.info(forTick: 1).accent)  // beat 0 upbeat
    XCTAssertFalse(tl.info(forTick: 2).accent)  // beat 1 downbeat
    XCTAssertFalse(tl.info(forTick: 3).accent)
  }

  func testCustomAccentOnThirdBeat() {
    let tl = MetroTimeline(
      beatsPerBar: 4,
      pattern: .quarter,
      accents: [false, false, true, false]
    )
    XCTAssertFalse(tl.info(forTick: 0).accent)
    XCTAssertFalse(tl.info(forTick: 1).accent)
    XCTAssertTrue(tl.info(forTick: 2).accent)
    XCTAssertFalse(tl.info(forTick: 3).accent)
  }

  func testMuteUpbeatsSilencesSubdivisions() {
    let muted = MetroTimeline(pattern: .eighth, muteUpbeats: true)
    XCTAssertTrue(muted.info(forTick: 0).audible)
    XCTAssertFalse(muted.info(forTick: 1).audible)

    let open = MetroTimeline(pattern: .eighth, muteUpbeats: false)
    XCTAssertTrue(open.info(forTick: 0).audible)
    XCTAssertTrue(open.info(forTick: 1).audible)
  }

  func testMissingAccentDefaultsFirstBeatOnly() {
    let tl = MetroTimeline(beatsPerBar: 4, pattern: .quarter, accents: [])
    XCTAssertTrue(tl.info(forTick: 0).accent)
    XCTAssertFalse(tl.info(forTick: 1).accent)
  }

  func testMonotonicIncreasingTimesAcrossBars() {
    let tl = MetroTimeline(bpm: 90, beatsPerBar: 4, pattern: .sixteenthsThenEighth)
    var previous = -1.0
    for n in 0..<tl.ticksPerBar * 3 {
      let t = tl.seconds(forTick: n)
      XCTAssertGreaterThan(t, previous)
      previous = t
    }
  }
}

final class AppSessionMetroTests: XCTestCase {
  func testResizingBeatsPerBarKeepsExistingAccents() {
    let session = AppSession()
    session.beatAccents = [true, false, true, false]
    session.beatsPerBar = 3
    XCTAssertEqual(session.beatAccents, [true, false, true])

    session.beatsPerBar = 5
    XCTAssertEqual(session.beatAccents, [true, false, true, false, false])
  }

  func testToggleAccent() {
    let session = AppSession()
    XCTAssertTrue(session.beatAccents[0])
    session.toggleAccent(at: 0)
    XCTAssertFalse(session.beatAccents[0])
    session.toggleAccent(at: 99)
    XCTAssertEqual(session.beatAccents.count, 4)
  }
}

private func assertEqualDoubles(
  _ expression: [Double],
  _ expected: [Double],
  accuracy: Double = 1e-12,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  XCTAssertEqual(expression.count, expected.count, file: file, line: line)
  for (a, b) in zip(expression, expected) {
    XCTAssertEqual(a, b, accuracy: accuracy, file: file, line: line)
  }
}
