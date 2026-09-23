import AVFoundation
import Combine
import Foundation

struct TickInfo: Equatable {
  let beatIndex: Int
  let subdivIndex: Int
  let accent: Bool
  let audible: Bool
}

/// Host-time metronome: absolute tick index → audio + UI on the same timeline.
final class MetronomeEngine: ObservableObject {
  @Published private(set) var isRunning = false
  @Published private(set) var tick: TickInfo?

  var bpm: Int = 100
  var beatsPerBar: Int = 4
  var pattern: MetroPattern = .quarter
  var sound: SoundId = .click
  var muteUpbeats = true
  var accents: [Bool] = [true, false, false, false]
  var uiObserving = false

  private let queue = DispatchQueue(label: "app.scalepulse.metro", qos: .userInteractive)
  private var pump: DispatchSourceTimer?

  private var running = false
  private var anchorHost: UInt64 = 0
  private var scheduleCursor = 0
  private var uiCursor = 0
  private var epoch: UInt64 = 0

  private let lookahead: Double = 0.15
  /// Flash the grid slightly early so SwiftUI paint lands with the audible click.
  private let visualLead: Double = 0.012

  /// Push live UI params into the engine (call from main).
  func apply(
    bpm: Int,
    beatsPerBar: Int,
    pattern: MetroPattern,
    sound: SoundId,
    muteUpbeats: Bool,
    accents: [Bool]
  ) {
    self.bpm = bpm
    self.beatsPerBar = beatsPerBar
    self.pattern = pattern
    self.sound = sound
    self.muteUpbeats = muteUpbeats
    self.accents = accents
  }

  func start() {
    queue.async { [weak self] in self?.startLocked() }
  }

  func stop() {
    queue.async { [weak self] in self?.stopLocked() }
  }

  func toggle() {
    queue.async { [weak self] in
      guard let self else { return }
      if self.running { self.stopLocked() } else { self.startLocked() }
    }
  }

  func resyncTimeline() {
    queue.async { [weak self] in
      guard let self, self.running else { return }
      self.epoch &+= 1
      TonePlayer.shared.resetTickSchedule()
      self.anchorHost = mach_absolute_time()
      self.scheduleCursor = 0
      self.uiCursor = 0
      self.pumpSchedule(epoch: self.epoch)
    }
  }

  // MARK: - Lifecycle

  private func startLocked() {
    guard !running else { return }
    TonePlayer.shared.ensureStarted()
    TonePlayer.shared.resetTickSchedule()
    epoch &+= 1
    running = true
    anchorHost = mach_absolute_time()
    scheduleCursor = 0
    uiCursor = 0
    DispatchQueue.main.async { self.isRunning = true }
    ensurePump()
    pumpSchedule(epoch: epoch)
  }

  private func stopLocked() {
    guard running else { return }
    running = false
    epoch &+= 1
    pump?.schedule(deadline: .now(), repeating: .never)
    TonePlayer.shared.resetTickSchedule()
    DispatchQueue.main.async {
      self.isRunning = false
      self.tick = nil
      TonePlayer.shared.suspendIfIdle()
    }
  }

  private func ensurePump() {
    if pump == nil {
      let source = DispatchSource.makeTimerSource(queue: queue)
      source.setEventHandler { [weak self] in
        guard let self else { return }
        self.pumpSchedule(epoch: self.epoch)
      }
      pump = source
      source.resume()
    }
    pump?.schedule(deadline: .now(), repeating: .milliseconds(20), leeway: .milliseconds(4))
  }

  // MARK: - Absolute timeline

  private func beatSeconds() -> Double {
    60.0 / Double(max(1, bpm))
  }

  private func seconds(forTick n: Int) -> Double {
    let onsets = pattern.onsets
    let perBeat = max(1, onsets.count)
    let beat = n / perBeat
    let sub = n % perBeat
    let dur = beatSeconds()
    return Double(beat) * dur + onsets[sub] * dur
  }

  private func info(forTick n: Int) -> TickInfo {
    let onsets = pattern.onsets
    let perBeat = max(1, onsets.count)
    let absoluteBeat = n / perBeat
    let subdiv = n % perBeat
    let beatIndex = absoluteBeat % max(1, beatsPerBar)
    let downbeatAccent = accents.indices.contains(beatIndex) ? accents[beatIndex] : (beatIndex == 0)
    let accent = subdiv == 0 && downbeatAccent
    let upbeat = subdiv != 0
    let audible = !upbeat || !muteUpbeats
    return TickInfo(
      beatIndex: beatIndex,
      subdivIndex: subdiv,
      accent: accent,
      audible: audible
    )
  }

  private func secondsSinceAnchor() -> Double {
    let delta = mach_absolute_time() &- anchorHost
    return AVAudioTime.seconds(forHostTime: delta)
  }

  private func hostTime(forSecondsFromAnchor seconds: Double) -> AVAudioTime {
    let offset = AVAudioTime.hostTime(forSeconds: max(0, seconds))
    return AVAudioTime(hostTime: anchorHost &+ offset)
  }

  // MARK: - Lookahead: audio + UI share the same tick times

  private func pumpSchedule(epoch: UInt64) {
    guard running, epoch == self.epoch else { return }

    let now = secondsSinceAnchor()
    let horizon = now + lookahead

    var steps = 0
    while seconds(forTick: scheduleCursor) < horizon && steps < 64 {
      let n = scheduleCursor
      let t = seconds(forTick: n)
      let info = info(forTick: n)

      if info.audible, t >= now - 0.003 {
        TonePlayer.shared.scheduleTick(
          sound: sound,
          accent: info.accent,
          upbeat: info.subdivIndex != 0,
          at: hostTime(forSecondsFromAnchor: t)
        )
      }

      // UI on the same timeline (not the 20ms poll) — slight lead for render latency.
      if uiObserving, n >= uiCursor, t >= now - 0.02 {
        let delay = max(0, t - now - visualLead)
        let tickN = n
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
          guard let self, self.epoch == epoch, self.isRunning else { return }
          self.tick = info
        }
        uiCursor = tickN + 1
      }

      scheduleCursor += 1
      steps += 1
    }
  }

  deinit {
    pump?.cancel()
  }
}
