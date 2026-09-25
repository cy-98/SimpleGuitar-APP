import XCTest
@testable import ScalePulse

final class ChordShapesMathTests: XCTestCase {
  func testOpenCMajorShapePitchClasses() {
    let chord = Chords.diatonicTriads(key: "C")[0]
    let diagram = ChordShapes.diagram(for: chord)
    XCTAssertNotNil(diagram)
    // Open C: x 3 2 0 1 0 → frets high-e…low-E
    XCTAssertEqual(diagram?.frets, [0, 1, 0, 2, 3, nil])
    assertDiagramContainsOnlyChordTones(diagram!, chord: chord)
  }

  func testOpenGMajorShape() {
    let chord = Chords.diatonicTriads(key: "G")[0]
    let diagram = ChordShapes.diagram(for: chord)
    XCTAssertEqual(diagram?.frets, [3, 0, 0, 0, 2, 3])
    assertDiagramContainsOnlyChordTones(diagram!, chord: chord)
  }

  func testOpenAMinorShape() {
    let am = Chords.diatonicTriads(key: "C").first { $0.symbol == "Am" }
    XCTAssertNotNil(am)
    let diagram = ChordShapes.diagram(for: am!)
    XCTAssertEqual(diagram?.frets, [0, 1, 2, 2, 0, nil])
    assertDiagramContainsOnlyChordTones(diagram!, chord: am!)
  }

  func testEveryDiatonicTriadHasADiagram() {
    for key in Scales.majorKeys {
      for chord in Chords.diatonicTriads(key: key) {
        let diagram = ChordShapes.diagram(for: chord)
        XCTAssertNotNil(diagram, "\(key) \(chord.symbol)")
        XCTAssertEqual(diagram?.frets.count, 6, "\(key) \(chord.symbol)")
        let sounding = diagram!.frets.compactMap { $0 }
        XCTAssertFalse(sounding.isEmpty, "\(key) \(chord.symbol)")
        assertDiagramContainsOnlyChordTones(diagram!, chord: chord)
      }
    }
  }

  func testMajorAndMinorOpenShapesAreChordTones() {
    // Known open / common shapes should be pure triads.
    let samples: [(key: String, symbol: String)] = [
      ("C", "C"), ("C", "Dm"), ("C", "Em"), ("C", "F"), ("C", "G"), ("C", "Am"),
      ("G", "G"), ("G", "Am"), ("G", "C"), ("G", "D"), ("G", "Em"),
      ("F", "F"), ("F", "Bb"), ("F", "C"), ("F", "Dm"),
    ]
    for sample in samples {
      let chord = Chords.diatonicTriads(key: sample.key).first { $0.symbol == sample.symbol }
      XCTAssertNotNil(chord, "\(sample.key) \(sample.symbol)")
      let diagram = ChordShapes.diagram(for: chord!)
      XCTAssertNotNil(diagram, "\(sample.key) \(sample.symbol)")
      assertDiagramContainsOnlyChordTones(diagram!, chord: chord!)
    }
  }

  func testBaseFretAndWindow() {
    let open = ChordDiagram(frets: [0, 1, 0, 2, 3, nil])
    XCTAssertEqual(open.baseFret, 1)
    XCTAssertEqual(open.windowStart, 1)

    let barre = ChordDiagram(frets: [5, 5, 6, 7, 7, 5])
    XCTAssertEqual(barre.baseFret, 5)
    XCTAssertEqual(barre.windowStart, 5)
  }

  private func assertDiagramContainsOnlyChordTones(
    _ diagram: ChordDiagram,
    chord: DiatonicChord,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let allowed = Set(chord.notes.compactMap(Pitch.notePitchClass))
    XCTAssertFalse(allowed.isEmpty, file: file, line: line)
    for (string, fret) in diagram.frets.enumerated() {
      guard let fret else { continue }
      let midi = Fretboard.standardTuningMidi[string] + fret
      let pc = ((midi % 12) + 12) % 12
      XCTAssertTrue(
        allowed.contains(pc),
        "string \(string) fret \(fret) pc \(pc) not in \(allowed) for \(chord.symbol)",
        file: file,
        line: line
      )
    }
  }
}
