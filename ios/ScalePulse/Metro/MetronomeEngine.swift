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
  /// Wall time along the tick timeline when paused; resume continues from here.
  private var pausedElapsed: Double?

  private let lookahead: Double = 0.15
  /// Flash the grid early enough that SwiftUI paint lands with — or slightly before — the click.
  /// ~3 frames @ 60Hz; near-horizon ticks also force an immediate main-queue publish (see pump).
  private let visualLead: Double = 0.055

  /// Push live UI params into the engine (call from main).
  func apply(
    bpm: Int,
    beatsPerBar: Int,
    pattern: MetroPattern,
    sound: SoundId,
    muteUpbeats: Bool,
    accents: [Bool]
  ) {
    let topologyChanged = beatsPerBar != self.beatsPerBar || pattern != self.pattern
    self.bpm = bpm
    self.beatsPerBar = beatsPerBar
    self.pattern = pattern
    self.sound = sound
    self.muteUpbeats = muteUpbeats
    self.accents = accents
    if topologyChanged {
      queue.async { [weak self] in self?.clearPausedPositionLocked() }
    }
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
      self.pausedElapsed = nil
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

    if let elapsed = pausedElapsed {
      // Resume: shift anchor so the timeline continues from the pause point.
      let nowHost = mach_absolute_time()
      let offset = AVAudioTime.hostTime(forSeconds: max(0, elapsed))
      anchorHost = nowHost &- offset
      pausedElapsed = nil
    } else {
      anchorHost = mach_absolute_time()
      scheduleCursor = 0
      uiCursor = 0
    }

    DispatchQueue.main.async { self.isRunning = true }
    ensurePump()
    pumpSchedule(epoch: epoch)
  }

  private func stopLocked() {
    guard running else { return }
    let elapsed = secondsSinceAnchor()
    pausedElapsed = elapsed
    // Rewind past lookahead so resume re-schedules the next tick at/after pause.
    var n = scheduleCursor
    while n > 0 && seconds(forTick: n - 1) >= elapsed {
      n -= 1
    }
    scheduleCursor = n
    uiCursor = min(uiCursor, n)

    running = false
    epoch &+= 1
    pump?.schedule(deadline: .now(), repeating: .never)
    TonePlayer.shared.resetTickSchedule()
    DispatchQueue.main.async {
      self.isRunning = false
      // Keep `tick` so the grid stays on the paused beat.
      TonePlayer.shared.suspendIfIdle()
    }
  }

  private func clearPausedPositionLocked() {
    guard !running else { return }
    pausedElapsed = nil
    scheduleCursor = 0
    uiCursor = 0
    DispatchQueue.main.async { self.tick = nil }
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

  private var timeline: MetroTimeline {
    MetroTimeline(
      bpm: bpm,
      beatsPerBar: beatsPerBar,
      pattern: pattern,
      muteUpbeats: muteUpbeats,
      accents: accents
    )
  }

  private func seconds(forTick n: Int) -> Double {
    timeline.seconds(forTick: n)
  }

  private func info(forTick n: Int) -> TickInfo {
    timeline.info(forTick: n)
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

      // UI first (especially for near ticks) so paint isn't stuck behind the click.
      if uiObserving, n >= uiCursor, t >= now - 0.02 {
        scheduleVisual(info: info, tickTime: t, now: now, epoch: epoch)
        uiCursor = n + 1
      }

      if info.audible, t >= now - 0.003 {
        TonePlayer.shared.scheduleTick(
          sound: sound,
          accent: info.accent,
          upbeat: info.subdivIndex != 0,
          at: hostTime(forSecondsFromAnchor: t)
        )
      }

      scheduleCursor += 1
      steps += 1
    }
  }

  private func scheduleVisual(info: TickInfo, tickTime: Double, now: Double, epoch: UInt64) {
    let fireAt = tickTime - visualLead
    let delay = fireAt - now
    let publish = { [weak self] in
      guard let self, self.epoch == epoch, self.isRunning else { return }
      self.tick = info
    }
    if delay <= 0.001 {
      // Already inside the lead window — push UI immediately (before/with this audio).
      DispatchQueue.main.async(execute: publish)
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: publish)
    }
  }

  deinit {
    pump?.cancel()
  }
}
