import Foundation

enum TheoryPane: Hashable {
  case ring, chords
}

/// In-memory practice UI state. Survives tab switches.
/// Metronome ticks are NOT rebroadcast here — only MetroView observes the engine (avoids redrawing every tab).
final class AppSession: ObservableObject {
  @Published var tab: AppTab = .metro

  @Published var bpm: Double = 100
  @Published var beatsPerBar = 4 {
    didSet { resizeAccents(to: beatsPerBar) }
  }
  /// Per-beat accent flags (index 0 = first beat). Tap a beat column to toggle.
  @Published var beatAccents: [Bool] = [true, false, false, false]
  @Published var pattern: MetroPattern = .quarter
  let metronome = MetronomeEngine()

  @Published var theoryKey = "C"
  @Published var theoryPane: TheoryPane = .ring
  @Published var positionId = "open"
  /// Match web `showNoteLetters`: on = note + degree; off = degree only.
  @Published var showNoteLetters = true
  @Published var fretboardFullscreen = false

  func toggleAccent(at index: Int) {
    guard beatAccents.indices.contains(index) else { return }
    beatAccents[index].toggle()
  }

  /// App left the foreground — stop metronome ticks and free the audio session.
  func suspendForBackground() {
    metronome.stop()
    TonePlayer.shared.suspendIfIdle()
  }

  private func resizeAccents(to count: Int) {
    let n = max(1, count)
    if beatAccents.count < n {
      beatAccents.append(contentsOf: Array(repeating: false, count: n - beatAccents.count))
    } else if beatAccents.count > n {
      beatAccents = Array(beatAccents.prefix(n))
    }
  }
}
