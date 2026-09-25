import XCTest
@testable import ScalePulse

final class PitchMathTests: XCTestCase {
  func testNaturalPitchClasses() {
    XCTAssertEqual(Pitch.notePitchClass("C"), 0)
    XCTAssertEqual(Pitch.notePitchClass("D"), 2)
    XCTAssertEqual(Pitch.notePitchClass("E"), 4)
    XCTAssertEqual(Pitch.notePitchClass("F"), 5)
    XCTAssertEqual(Pitch.notePitchClass("G"), 7)
    XCTAssertEqual(Pitch.notePitchClass("A"), 9)
    XCTAssertEqual(Pitch.notePitchClass("B"), 11)
  }

  func testAccidentals() {
    XCTAssertEqual(Pitch.notePitchClass("C#"), 1)
    XCTAssertEqual(Pitch.notePitchClass("Db"), 1)
    XCTAssertEqual(Pitch.notePitchClass("F#"), 6)
    XCTAssertEqual(Pitch.notePitchClass("Bb"), 10)
    XCTAssertEqual(Pitch.notePitchClass("E\u{266F}"), 5) // E♯
    XCTAssertEqual(Pitch.notePitchClass("B\u{266D}"), 10) // B♭
  }

  func testInvalidNoteReturnsNil() {
    XCTAssertNil(Pitch.notePitchClass(""))
    XCTAssertNil(Pitch.notePitchClass("H"))
    XCTAssertNil(Pitch.noteToMidi("X"))
  }

  func testNoteToMidiConcertPitch() {
    XCTAssertEqual(Pitch.noteToMidi("A", octave: 4), 69)
    XCTAssertEqual(Pitch.noteToMidi("C", octave: 4), 60)
    XCTAssertEqual(Pitch.noteToMidi("E", octave: 2), 40)
    XCTAssertEqual(Pitch.noteToMidi("E", octave: 4), 64)
  }

  func testMidiToFreqA4Is440() {
    XCTAssertEqual(Pitch.midiToFreq(69), 440, accuracy: 1e-9)
    XCTAssertEqual(Pitch.midiToFreq(69.0), 440, accuracy: 1e-9)
  }

  func testMidiToFreqOctaveDoubles() {
    let a3 = Pitch.midiToFreq(57)
    let a4 = Pitch.midiToFreq(69)
    let a5 = Pitch.midiToFreq(81)
    XCTAssertEqual(a4 / a3, 2, accuracy: 1e-9)
    XCTAssertEqual(a5 / a4, 2, accuracy: 1e-9)
  }

  func testFreqToMidiRoundTrip() {
    for midi in [40, 45, 55, 60, 64, 69, 76] {
      let freq = Pitch.midiToFreq(midi)
      let back = Pitch.freqToMidi(freq)
      XCTAssertNotNil(back)
      XCTAssertEqual(back!, Double(midi), accuracy: 1e-9)
    }
  }

  func testFreqToMidiRejectsInvalid() {
    XCTAssertNil(Pitch.freqToMidi(0))
    XCTAssertNil(Pitch.freqToMidi(-1))
    XCTAssertNil(Pitch.freqToMidi(.nan))
    XCTAssertNil(Pitch.freqToMidi(.infinity))
  }

  func testMidiToNearestNote() {
    let a4 = Pitch.midiToNearestNote(69)
    XCTAssertEqual(a4.name, "A")
    XCTAssertEqual(a4.octave, 4)
    XCTAssertEqual(a4.cents, 0, accuracy: 1e-9)
    XCTAssertEqual(a4.midiRounded, 69)

    let sharp = Pitch.midiToNearestNote(69.3)
    XCTAssertEqual(sharp.name, "A")
    XCTAssertEqual(sharp.cents, 30, accuracy: 1e-9)

    let flat = Pitch.midiToNearestNote(68.7)
    XCTAssertEqual(flat.name, "A")
    XCTAssertEqual(flat.cents, -30, accuracy: 1e-9)
  }

  func testCentsFromTarget() {
    XCTAssertEqual(Pitch.centsFromTarget(69.0, targetMidi: 69.0), 0, accuracy: 1e-9)
    XCTAssertEqual(Pitch.centsFromTarget(69.5, targetMidi: 69.0), 50, accuracy: 1e-9)
    XCTAssertEqual(Pitch.centsFromTarget(68.5, targetMidi: 69.0), -50, accuracy: 1e-9)
  }

  func testGuitarOpenMidiMatchesStandardTuning() {
    XCTAssertEqual(Pitch.guitarOpenMidi, [40, 45, 50, 55, 59, 64])
    XCTAssertEqual(Fretboard.standardTuningMidi.reversed(), Pitch.guitarOpenMidi)
  }
}
