import XCTest
@testable import ScalePulse

final class ScalesMathTests: XCTestCase {
  func testCMajorScale() {
    XCTAssertEqual(
      Scales.majorScaleNotes(root: "C"),
      ["C", "D", "E", "F", "G", "A", "B"]
    )
  }

  func testGMajorScale() {
    XCTAssertEqual(
      Scales.majorScaleNotes(root: "G"),
      ["G", "A", "B", "C", "D", "E", "F#"]
    )
  }

  func testFMajorScale() {
    XCTAssertEqual(
      Scales.majorScaleNotes(root: "F"),
      ["F", "G", "A", "Bb", "C", "D", "E"]
    )
  }

  func testFSharpMajorScale() {
    XCTAssertEqual(
      Scales.majorScaleNotes(root: "F#"),
      ["F#", "G#", "A#", "B", "C#", "D#", "E#"]
    )
  }

  func testDbMajorScale() {
    XCTAssertEqual(
      Scales.majorScaleNotes(root: "Db"),
      ["Db", "Eb", "F", "Gb", "Ab", "Bb", "C"]
    )
  }

  func testMajorScaleDegreesHaveSevenSteps() {
    for key in Scales.majorKeys {
      let degrees = Scales.majorScaleDegrees(root: key)
      XCTAssertEqual(degrees.count, 7, key)
      XCTAssertEqual(degrees.map(\.degree), Array(1...7), key)
      XCTAssertEqual(degrees.map(\.solfege), Scales.solfege, key)
      XCTAssertEqual(degrees.map(\.note), Scales.majorScaleNotes(root: key), key)
    }
  }

  func testDegreesByLetterMapsNaturalLetters() {
    let map = Scales.degreesByLetter(root: "C")
    XCTAssertEqual(map["C"]?.degree, 1)
    XCTAssertEqual(map["D"]?.degree, 2)
    XCTAssertEqual(map["E"]?.solfege, "Mi")
    XCTAssertEqual(map["B"]?.degree, 7)
  }

  func testDegreesByLetterForSharpKeyUsesScaleLetters() {
    let map = Scales.degreesByLetter(root: "F#")
    XCTAssertEqual(map["F"]?.note, "F#")
    XCTAssertEqual(map["E"]?.note, "E#")
    XCTAssertEqual(map["B"]?.degree, 4)
  }

  func testIsMajorKey() {
    XCTAssertTrue(Scales.isMajorKey("C"))
    XCTAssertTrue(Scales.isMajorKey("Bb"))
    XCTAssertFalse(Scales.isMajorKey("C#"))
    XCTAssertFalse(Scales.isMajorKey(""))
  }

  func testMajorIntervalsMatchWWHWWWH() {
    XCTAssertEqual(Scales.majorIntervals, [0, 2, 4, 5, 7, 9, 11])
  }

  func testScalePitchClassesAreDistinct() {
    for key in Scales.majorKeys {
      let pcs = Scales.majorScaleNotes(root: key).compactMap(Pitch.notePitchClass)
      XCTAssertEqual(Set(pcs).count, 7, key)
    }
  }
}
