import XCTest
@testable import ScalePulse

final class ChordsMathTests: XCTestCase {
  func testCMajorDiatonicTriads() {
    let chords = Chords.diatonicTriads(key: "C")
    XCTAssertEqual(chords.count, 7)
    XCTAssertEqual(chords.map(\.roman), ["I", "ii", "iii", "IV", "V", "vi", "vii°"])
    XCTAssertEqual(chords.map(\.symbol), ["C", "Dm", "Em", "F", "G", "Am", "B°"])
    XCTAssertEqual(chords[0].notes, ["C", "E", "G"])
    XCTAssertEqual(chords[1].notes, ["D", "F", "A"])
    XCTAssertEqual(chords[6].notes, ["B", "D", "F"])
    XCTAssertEqual(chords[6].quality, .diminished)
  }

  func testGMajorDiatonicTriadsUseKeyAccidentals() {
    let chords = Chords.diatonicTriads(key: "G")
    XCTAssertEqual(chords[0].notes, ["G", "B", "D"])
    XCTAssertEqual(chords[4].symbol, "D") // V
    XCTAssertEqual(chords[6].notes, ["F#", "A", "C"])
    XCTAssertEqual(chords[6].symbol, "F#°")
  }

  func testFMajorDiatonicTriads() {
    let chords = Chords.diatonicTriads(key: "F")
    XCTAssertEqual(chords[3].notes, ["Bb", "D", "F"]) // IV
    XCTAssertEqual(chords[3].symbol, "Bb")
    XCTAssertEqual(chords[6].notes, ["E", "G", "Bb"])
  }

  func testQualitiesFollowMajorKeyPattern() {
    let expected: [ChordQuality] = [
      .major, .minor, .minor, .major, .major, .minor, .diminished,
    ]
    for key in Scales.majorKeys {
      let chords = Chords.diatonicTriads(key: key)
      XCTAssertEqual(chords.map(\.quality), expected, key)
      XCTAssertEqual(chords.map(\.degree), Array(1...7), key)
    }
  }

  func testTriadPitchClassesFormClosedStack() {
    for key in Scales.majorKeys {
      for chord in Chords.diatonicTriads(key: key) {
        let pcs = chord.notes.compactMap(Pitch.notePitchClass)
        XCTAssertEqual(pcs.count, 3, "\(key) \(chord.symbol)")
        // Root → third is 3 or 4 semitones; third → fifth is 3 or 4; root → fifth is 6 or 7.
        let third = (pcs[1] - pcs[0] + 12) % 12
        let fifth = (pcs[2] - pcs[0] + 12) % 12
        switch chord.quality {
        case .major:
          XCTAssertEqual(third, 4, "\(key) \(chord.symbol)")
          XCTAssertEqual(fifth, 7, "\(key) \(chord.symbol)")
        case .minor:
          XCTAssertEqual(third, 3, "\(key) \(chord.symbol)")
          XCTAssertEqual(fifth, 7, "\(key) \(chord.symbol)")
        case .diminished:
          XCTAssertEqual(third, 3, "\(key) \(chord.symbol)")
          XCTAssertEqual(fifth, 6, "\(key) \(chord.symbol)")
        }
      }
    }
  }
}
