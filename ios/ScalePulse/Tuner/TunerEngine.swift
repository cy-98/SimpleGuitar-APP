import AVFoundation
import Foundation
import QuartzCore

/// Microphone pitch detection (YIN), matching webapp `tuner.ts`.
///
/// UI contract (GuitarTuna-style):
/// - `live` — high-rate needle / Hz only
/// - `activeStringId` — rare chrome highlight updates
final class TunerEngine: ObservableObject {
  let live = TunerLiveMetrics()
  @Published private(set) var activeStringId: TunerStringId?
  @Published private(set) var micState: TunerMicState = .pending
  @Published private(set) var isListening = false

  private let engine = AVAudioEngine()
  private var targets = TunerGeometry.defaultStringTargets()
  private var smoothMidi: Double?
  /// Stable pitch used while YIN drops out (wobble is applied on top, not accumulated).
  private var holdBaseMidi: Double?
  private var tapInstalled = false
  private var captureRunning = false
  private let processQueue = DispatchQueue(label: "app.scalepulse.tuner", qos: .userInteractive)

  /// Analysis rate (~60 Hz). UI publish is coalesced to one main-thread apply per runloop.
  private let minProcessInterval: CFTimeInterval = 1.0 / 60.0
  private var lastProcessAt: CFTimeInterval = 0
  private var lastPublished: TunerReading?
  private var lastPublishAt: CFTimeInterval = 0
  private var pendingUI: TunerReading?
  private var uiFlushScheduled = false
  /// When RMS drops, wait this long before hiding the detection line.
  private let silenceClearSeconds: CFTimeInterval = 0.40
  private var silenceBeganAt: CFTimeInterval = 0

  /// Reused scratch buffers to avoid per-callback allocations.
  private var sampleScratch: [Float] = []
  private var yinScratch: [Float] = []

  func setTargets(_ targets: StringTargets) {
    processQueue.async { self.targets = targets }
  }

  func start() {
    DispatchQueue.main.async { self.micState = .pending }
    requestMic { [weak self] granted in
      guard let self else { return }
      guard granted else {
        DispatchQueue.main.async {
          self.micState = .denied
          self.clearUILocked()
        }
        return
      }
      self.processQueue.async { self.startCaptureLocked() }
    }
  }

  func stop() {
    processQueue.async { self.stopCaptureLocked() }
  }

  private func requestMic(completion: @escaping (Bool) -> Void) {
    if #available(iOS 17.0, *) {
      AVAudioApplication.requestRecordPermission { granted in
        completion(granted)
      }
    } else {
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        completion(granted)
      }
    }
  }

  private func startCaptureLocked() {
    if captureRunning { return }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playAndRecord,
        mode: .measurement,
        options: [
          AVAudioSession.CategoryOptions.mixWithOthers,
          AVAudioSession.CategoryOptions.defaultToSpeaker,
          AVAudioSession.CategoryOptions.allowBluetoothHFP,
        ]
      )
      try session.setActive(true, options: [])

      let input = engine.inputNode
      let format = input.outputFormat(forBus: 0)
      guard format.sampleRate > 0, format.channelCount > 0 else {
        DispatchQueue.main.async {
          self.micState = .denied
          self.clearUILocked()
        }
        return
      }

      if tapInstalled {
        input.removeTap(onBus: 0)
        tapInstalled = false
      }

      let bufferSize: AVAudioFrameCount = 2048
      input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
        self?.process(buffer: buffer)
      }
      tapInstalled = true
      captureRunning = true
      smoothMidi = nil
      holdBaseMidi = nil
      lastPublished = nil
      pendingUI = nil
      silenceBeganAt = 0
      lastProcessAt = 0

      if !engine.isRunning {
        try engine.start()
      }

      DispatchQueue.main.async {
        self.isListening = true
        self.micState = .live
      }
    } catch {
      stopCaptureLocked()
      DispatchQueue.main.async {
        self.micState = .denied
        self.clearUILocked()
        self.isListening = false
      }
    }
  }

  private func stopCaptureLocked() {
    if tapInstalled {
      engine.inputNode.removeTap(onBus: 0)
      tapInstalled = false
    }
    if engine.isRunning {
      engine.stop()
    }
    captureRunning = false
    smoothMidi = nil
    holdBaseMidi = nil
    lastPublished = nil
    pendingUI = nil
    silenceBeganAt = 0
    // Hand the session back so metro / piano aren't stuck on quiet mic routing.
    TonePlayer.shared.restorePlaybackSession()
    DispatchQueue.main.async {
      self.isListening = false
      self.clearUILocked()
    }
  }

  private func clearUILocked() {
    live.clear()
    activeStringId = nil
  }

  private func process(buffer: AVAudioPCMBuffer) {
    let now = CACurrentMediaTime()
    if now - lastProcessAt < minProcessInterval { return }
    lastProcessAt = now

    guard let channel = buffer.floatChannelData?[0] else { return }
    let count = Int(buffer.frameLength)
    guard count > 0 else { return }

    if sampleScratch.count < count {
      sampleScratch = [Float](repeating: 0, count: count)
    }
    sampleScratch.withUnsafeMutableBufferPointer { dst in
      dst.baseAddress!.update(from: channel, count: count)
    }

    let level = rms(count: count)
    if level < TunerLayout.rmsGate {
      // True quiet: clear only after sustained silence (not a brief dip).
      clearAfterSilence(now: now)
      return
    }

    // Sound is present — cancel any silence countdown.
    silenceBeganAt = 0

    let sampleRate = buffer.format.sampleRate
    guard let freq = yinPitch(count: count, sampleRate: sampleRate),
          let midiRaw = Pitch.freqToMidi(freq)
    else {
      // YIN often flickers while the string is still ringing — keep the line wobbling.
      holdLastReading(level: level, now: now)
      return
    }

    // Smooth large leaps; pass small deltas almost raw so the line shows live jitter.
    if let prev = smoothMidi {
      let delta = midiRaw - prev
      let alpha = abs(delta) > 0.4 ? 0.42 : 0.90
      smoothMidi = prev + alpha * delta
    } else {
      smoothMidi = midiRaw
    }
    guard let midi = smoothMidi else {
      holdLastReading(level: level, now: now)
      return
    }

    let nearest = Pitch.midiToNearestNote(midi)
    let stringId = TunerGeometry.nearestString(midi: midi, targets: targets)
    let targetMidi = Double(targets[stringId] ?? TunerGeometry.defaultOpenMidi(stringId))
    let cents = Pitch.centsFromTarget(midi, targetMidi: targetMidi)
    let displayFreq = Pitch.midiToFreq(midi)
    holdBaseMidi = midi

    publish(
      TunerReading(
        freq: displayFreq,
        midi: midi,
        note: nearest.name,
        octave: nearest.octave,
        cents: cents,
        stringId: stringId,
        inTune: abs(cents) <= TunerLayout.inTuneCents,
        level: Double(level)
      ),
      now: now
    )
  }

  private func publish(_ value: TunerReading, now: CFTimeInterval) {
    lastPublished = value
    lastPublishAt = now
    scheduleUI(value)
  }

  /// Keep the line alive with a soft residual wobble while YIN briefly drops out.
  private func holdLastReading(level: Float, now: CFTimeInterval) {
    guard var last = lastPublished else { return }
    let base = holdBaseMidi ?? last.midi
    let amp = min(1.0, Double(level) / 0.03) * 0.035
    let wobble =
      sin(now * 27.0) * amp
      + sin(now * 43.0) * amp * 0.45
    let midi = base + wobble
    last.midi = midi
    last.freq = Pitch.midiToFreq(midi)
    last.level = Double(level)
    let targetMidi = Double(targets[last.stringId] ?? TunerGeometry.defaultOpenMidi(last.stringId))
    last.cents = Pitch.centsFromTarget(midi, targetMidi: targetMidi)
    last.inTune = abs(last.cents) <= TunerLayout.inTuneCents
    lastPublished = last
    lastPublishAt = now
    if let s = smoothMidi {
      smoothMidi = s + 0.2 * (midi - s)
    }
    scheduleUI(last)
  }

  private func clearAfterSilence(now: CFTimeInterval) {
    guard lastPublished != nil else { return }
    if silenceBeganAt == 0 {
      silenceBeganAt = now
      return
    }
    guard now - silenceBeganAt >= silenceClearSeconds else { return }

    silenceBeganAt = 0
    smoothMidi = nil
    holdBaseMidi = nil
    lastPublished = nil
    pendingUI = nil
    DispatchQueue.main.async {
      self.clearUILocked()
    }
  }

  /// One main-thread flush per runloop — drops intermediate frames instead of queuing them.
  private func scheduleUI(_ value: TunerReading) {
    pendingUI = value
    guard !uiFlushScheduled else { return }
    uiFlushScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.uiFlushScheduled = false
      guard let value = self.pendingUI else { return }
      self.pendingUI = nil
      self.live.apply(freq: value.freq, midi: value.midi, inTune: value.inTune)
      if self.activeStringId != value.stringId {
        self.activeStringId = value.stringId
      }
    }
  }

  private func rms(count: Int) -> Float {
    guard count > 0 else { return 0 }
    var sum: Float = 0
    for i in 0..<count {
      let x = sampleScratch[i]
      sum += x * x
    }
    return sqrt(sum / Float(count))
  }

  private func yinPitch(count: Int, sampleRate: Double, threshold: Float = TunerLayout.yinThreshold) -> Double? {
    let half = count / 2
    guard half > 2 else { return nil }

    if yinScratch.count < half {
      yinScratch = [Float](repeating: 0, count: half)
    }

    yinScratch[0] = 1
    var running: Float = 0
    for tau in 1..<half {
      var sum: Float = 0
      for i in 0..<half {
        let d = sampleScratch[i] - sampleScratch[i + tau]
        sum += d * d
      }
      yinScratch[tau] = sum
      running += yinScratch[tau]
      yinScratch[tau] = running > 0 ? (yinScratch[tau] * Float(tau)) / running : 1
    }

    let minTau = max(2, Int(sampleRate / TunerLayout.maxFreq))
    let maxTau = min(half - 1, Int(ceil(sampleRate / TunerLayout.minFreq)))
    guard minTau <= maxTau else { return nil }

    var bestTau = -1
    var tau = minTau
    while tau <= maxTau {
      if yinScratch[tau] < threshold {
        while tau + 1 <= maxTau, yinScratch[tau + 1] < yinScratch[tau] {
          tau += 1
        }
        bestTau = tau
        break
      }
      tau += 1
    }

    if bestTau < 0 {
      var minVal = Float.infinity
      for t in minTau...maxTau {
        if yinScratch[t] < minVal {
          minVal = yinScratch[t]
          bestTau = t
        }
      }
      if minVal >= threshold * 1.4 { return nil }
    }

    let x0 = bestTau > 0 ? bestTau - 1 : bestTau
    let x2 = bestTau + 1 < half ? bestTau + 1 : bestTau
    let s0 = yinScratch[x0]
    let s1 = yinScratch[bestTau]
    let s2 = yinScratch[x2]
    let denom = 2 * s1 - s2 - s0
    let betterTau = abs(denom) > 1e-6
      ? Double(bestTau) + Double(s2 - s0) / Double(2 * denom)
      : Double(bestTau)

    let freq = sampleRate / betterTau
    guard freq.isFinite, freq >= TunerLayout.minFreq, freq <= TunerLayout.maxFreq else { return nil }
    return freq
  }
}
