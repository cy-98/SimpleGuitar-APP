import Foundation
import Combine

struct TickInfo: Equatable {
  let beatIndex: Int
  let subdivIndex: Int
  let accent: Bool
  let audible: Bool
}

/// Wall-clock metronome with catch-up (foreground practice).
final class MetronomeEngine: ObservableObject {
  @Published private(set) var isRunning = false
  @Published private(set) var tick: TickInfo?

  var bpm: Int = 100
  var beatsPerBar: Int = 4
  var subdivision: Int = 1
  var sound: SoundId = .click
  var muteUpbeats = false

  private var timer: DispatchSourceTimer?
  private var beat = 0
  private var subdiv = 0
  private var nextAt: CFAbsoluteTime = 0
  private let queue = DispatchQueue(label: "app.scalepulse.metro")

  func start() {
    guard !isRunning else { return }
    TonePlayer.shared.ensureStarted()
    isRunning = true
    beat = 0
    subdiv = 0
    nextAt = CFAbsoluteTimeGetCurrent()
    arm()
  }

  func stop() {
    isRunning = false
    timer?.cancel()
    timer = nil
    DispatchQueue.main.async { self.tick = nil }
  }

  func toggle() {
    if isRunning { stop() } else { start() }
  }

  private func msPerTick() -> Double {
    60_000.0 / Double(bpm) / Double(subdivision)
  }

  private func arm() {
    timer?.cancel()
    let source = DispatchSource.makeTimerSource(queue: queue)
    let delay = max(0, nextAt - CFAbsoluteTimeGetCurrent())
    source.schedule(deadline: .now() + delay, repeating: .never)
    source.setEventHandler { [weak self] in self?.fire() }
    timer = source
    source.resume()
  }

  private func fire() {
    guard isRunning else { return }
    let now = CFAbsoluteTimeGetCurrent()
    let step = msPerTick() / 1000
    var skipped = 0
    while nextAt + step < now && skipped < 8 {
      advance()
      nextAt += step
      skipped += 1
    }

    let accent = beat == 0 && subdiv == 0
    let upbeat = subdiv != 0
    let audible = !upbeat || !muteUpbeats
    let info = TickInfo(
      beatIndex: beat,
      subdivIndex: subdiv,
      accent: accent,
      audible: audible
    )
    DispatchQueue.main.async { self.tick = info }
    if audible {
      TonePlayer.shared.playTick(sound: sound, accent: accent, upbeat: upbeat)
    }
    advance()
    nextAt += step
    arm()
  }

  private func advance() {
    subdiv += 1
    if subdiv >= subdivision {
      subdiv = 0
      beat = (beat + 1) % beatsPerBar
    }
  }
}
