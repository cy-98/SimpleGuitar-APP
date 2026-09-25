import XCTest
@testable import ScalePulse

final class FretboardMathTests: XCTestCase {
  func testOpenStringMidis() {
    XCTAssertEqual(Fretboard.standardTuningMidi, [64, 59, 55, 50, 45, 40])
    XCTAssertEqual(Fretboard.stringLabels.count, 6)
  }

  func testInPositionOpenWindowIsZeroToFour() {
    let open = Fretboard.getPosition("open")
    XCTAssertEqual(open.label, "0–4")
    XCTAssertTrue(Fretboard.inPosition(fret: 0, pos: open))
    XCTAssertTrue(Fretboard.inPosition(fret: 4, pos: open))
    XCTAssertFalse(Fretboard.inPosition(fret: 5, pos: open))
  }

  func testInPositionAllIncludesEverything() {
    let all = Fretboard.getPosition("all")
    XCTAssertEqual(all.label, "All")
    for fret in Fretboard.fretMin...Fretboard.fretMax {
      XCTAssertTrue(Fretboard.inPosition(fret: fret, pos: all))
    }
  }

  func testPortraitOmitsAll() {
    XCTAssertFalse(Fretboard.portraitPositions.contains { $0.id == "all" })
    XCTAssertTrue(Fretboard.landscapePositions.contains { $0.id == "all" })
  }

  func testInPositionWindow() {
    let mid = Fretboard.getPosition("mid")
    XCTAssertFalse(Fretboard.inPosition(fret: 4, pos: mid))
    XCTAssertTrue(Fretboard.inPosition(fret: 5, pos: mid))
    XCTAssertTrue(Fretboard.inPosition(fret: 9, pos: mid))
    XCTAssertFalse(Fretboard.inPosition(fret: 10, pos: mid))

    let midLow = Fretboard.getPosition("mid-low")
    XCTAssertTrue(Fretboard.inPosition(fret: 3, pos: midLow))
    XCTAssertTrue(Fretboard.inPosition(fret: 7, pos: midLow))
    XCTAssertFalse(Fretboard.inPosition(fret: 8, pos: midLow))
  }

  func testUnknownPositionFallsBackToOpen() {
    let pos = Fretboard.getPosition("nope")
    XCTAssertEqual(pos.id, "open")
  }

  func testScaleDotsOnlyContainScalePitchClasses() {
    let dots = Fretboard.scaleDots(key: "C")
    let scalePcs = Set(Scales.majorScaleNotes(root: "C").compactMap(Pitch.notePitchClass))
    XCTAssertFalse(dots.isEmpty)
    for dot in dots {
      let pc = ((dot.midi % 12) + 12) % 12
      XCTAssertTrue(scalePcs.contains(pc), "midi \(dot.midi)")
      XCTAssertEqual(dot.midi, Fretboard.standardTuningMidi[dot.string] + dot.fret)
    }
  }

  func testScaleDotsTonicMatchesDegreeOne() {
    for key in Scales.majorKeys {
      let dots = Fretboard.scaleDots(key: key)
      let tonics = dots.filter(\.isTonic)
      XCTAssertFalse(tonics.isEmpty, key)
      XCTAssertTrue(tonics.allSatisfy { $0.degree.degree == 1 }, key)
      XCTAssertTrue(dots.filter { !$0.isTonic }.allSatisfy { $0.degree.degree != 1 }, key)
    }
  }

  func testCMajorOpenHighEIsDegreeThree() {
    let dots = Fretboard.scaleDots(key: "C")
    let openHighE = dots.first { $0.string == 0 && $0.fret == 0 }
    XCTAssertEqual(openHighE?.degree.degree, 3) // E = Mi in C
    XCTAssertEqual(openHighE?.degree.solfege, "Mi")
  }

  func testTwelveFretCoverageHasSevenPcsPerStringWhenPossible() {
    // Across frets 0…12 each string spans 13 frets → all 12 pcs appear once or twice;
    // scale dots should include every scale degree somewhere on the neck.
    let dots = Fretboard.scaleDots(key: "G")
    let degrees = Set(dots.map { $0.degree.degree })
    XCTAssertEqual(degrees, Set(1...7))
  }
}
