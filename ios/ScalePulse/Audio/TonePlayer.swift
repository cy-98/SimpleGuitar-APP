import AVFoundation
import Foundation

/// Soft-synth clicks and sung tones. Tick / piano PCM cached; volume via mixer.
final class TonePlayer {
  static let shared = TonePlayer()

  /// 0…1 — applied on the mixer so cached tick buffers stay shared.
  var masterVolume: Float = 0.85 {
    didSet { engine.mainMixerNode.outputVolume = max(0, min(1, masterVolume)) }
  }

  private let engine = AVAudioEngine()
  private let tickPlayer = AVAudioPlayerNode()
  private let tonePlayer = AVAudioPlayerNode()
  private let sampleRate: Double = 22_050
  private let format: AVAudioFormat
  private var sessionActive = false

  private var tickCache: [TickKey: AVAudioPCMBuffer] = [:]
  private var pianoCache: [Int: AVAudioPCMBuffer] = [:]
  private var chordCache: [String: AVAudioPCMBuffer] = [:]
  private let cacheLock = NSLock()
  /// Serializes player scheduling (safe from metro queue + main).
  private let playLock = NSLock()

  private struct TickKey: Hashable {
    let sound: SoundId
    let accent: Bool
    let upbeat: Bool
  }

  private init() {
    format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    engine.attach(tickPlayer)
    engine.attach(tonePlayer)
    engine.connect(tickPlayer, to: engine.mainMixerNode, format: format)
    engine.connect(tonePlayer, to: engine.mainMixerNode, format: format)
    engine.mainMixerNode.outputVolume = masterVolume
  }

  func ensureStarted() {
    playLock.lock()
    defer { playLock.unlock() }
    if sessionActive {
      if !engine.isRunning {
        try? engine.start()
        tickPlayer.play()
        tonePlayer.play()
      }
      return
    }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true, options: [])
      try engine.start()
      tickPlayer.play()
      tonePlayer.play()
      sessionActive = true
      cacheLock.lock()
      warmSoundLocked(.click)
      cacheLock.unlock()
    } catch {
      // Preview / simulator session failures are non-fatal.
    }
  }

  /// Rebuild PCM for one sound (Settings switch). Keeps other sounds cached.
  func rebuildTickCache(for sound: SoundId? = nil) {
    cacheLock.lock()
    defer { cacheLock.unlock() }
    if let sound {
      clearTicksLocked(sound)
      warmSoundLocked(sound)
    } else {
      tickCache.removeAll(keepingCapacity: true)
      warmSoundLocked(.click)
    }
  }

  /// Release audio hardware when idle (saves battery). Keeps PCM caches.
  func suspendIfIdle() {
    playLock.lock()
    defer { playLock.unlock() }
    guard sessionActive else { return }
    tickPlayer.stop()
    tonePlayer.stop()
    engine.pause()
    try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    sessionActive = false
  }

  /// Sample-accurate click on the audio host timeline (metronome).
  func scheduleTick(sound: SoundId, accent: Bool, upbeat: Bool, at hostTime: AVAudioTime) {
    ensureStarted()
    guard let buffer = tickBuffer(sound: sound, accent: accent, upbeat: upbeat) else { return }
    playLock.lock()
    tickPlayer.scheduleBuffer(buffer, at: hostTime, options: [], completionHandler: nil)
    playLock.unlock()
  }

  /// Drop queued metronome clicks (tempo / pattern change or stop).
  func resetTickSchedule() {
    playLock.lock()
    defer { playLock.unlock() }
    guard sessionActive else { return }
    tickPlayer.stop()
    if engine.isRunning { tickPlayer.play() }
  }

  private func tickBuffer(sound: SoundId, accent: Bool, upbeat: Bool) -> AVAudioPCMBuffer? {
    let key = TickKey(sound: sound, accent: accent, upbeat: upbeat)
    cacheLock.lock()
    defer { cacheLock.unlock() }
    if let cached = tickCache[key] { return cached }
    let buf = makeBuffer(samples: synthTick(sound: sound, accent: accent, upbeat: upbeat))
    tickCache[key] = buf
    return buf
  }

  func playPiano(note: String, octave: Int = 4) {
    guard let midi = Pitch.noteToMidi(note, octave: octave) else { return }
    playPiano(midi: midi)
  }

  func playPiano(midi: Int) {
    ensureStarted()
    cacheLock.lock()
    let buffer: AVAudioPCMBuffer? = {
      if let cached = pianoCache[midi] { return cached }
      let buf = makeBuffer(samples: synthPiano(freq: Pitch.midiToFreq(midi)))
      if pianoCache.count > 48 { pianoCache.removeAll(keepingCapacity: true) }
      pianoCache[midi] = buf
      return buf
    }()
    cacheLock.unlock()
    guard let buffer else { return }
    playLock.lock()
    tonePlayer.stop()
    tonePlayer.play()
    tonePlayer.scheduleBuffer(buffer, completionHandler: nil)
    playLock.unlock()
  }

  /// Soft stacked piano for chord dictionary (cached by note set).
  func playChord(notes: [String], baseOctave: Int = 3) {
    let midis = ascendingMidis(notes: notes, baseOctave: baseOctave)
    guard !midis.isEmpty else { return }
    let cacheKey = midis.map(String.init).joined(separator: ",")
    ensureStarted()

    cacheLock.lock()
    let cached = chordCache[cacheKey]
    cacheLock.unlock()

    if let cached {
      playLock.lock()
      tonePlayer.stop()
      tonePlayer.play()
      tonePlayer.scheduleBuffer(cached, completionHandler: nil)
      playLock.unlock()
      return
    }

    // First hit: render off the hot path, then play + cache.
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let duration = 0.95
      let n = Int(self.sampleRate * duration)
      var mixed = [Float](repeating: 0, count: n)
      let gain = 1 / Float(sqrt(Double(midis.count)))
      for midi in midis {
        let tone = self.synthPiano(freq: Pitch.midiToFreq(midi), duration: duration)
        let count = min(mixed.count, tone.count)
        for i in 0..<count {
          mixed[i] += tone[i] * gain * 0.9
        }
      }
      guard let buffer = self.makeBuffer(samples: mixed) else { return }
      self.cacheLock.lock()
      if self.chordCache.count > 32 { self.chordCache.removeAll(keepingCapacity: true) }
      self.chordCache[cacheKey] = buffer
      self.cacheLock.unlock()
      self.playLock.lock()
      self.tonePlayer.stop()
      self.tonePlayer.play()
      self.tonePlayer.scheduleBuffer(buffer, completionHandler: nil)
      self.playLock.unlock()
    }
  }

  private func ascendingMidis(notes: [String], baseOctave: Int) -> [Int] {
    var result: [Int] = []
    var floor = 0
    for note in notes {
      guard var midi = Pitch.noteToMidi(note, octave: baseOctave) else { continue }
      while midi <= floor { midi += 12 }
      result.append(midi)
      floor = midi
    }
    return result
  }

  private func clearTicksLocked(_ sound: SoundId) {
    tickCache = tickCache.filter { $0.key.sound != sound }
  }

  private func warmSoundLocked(_ sound: SoundId) {
    for accent in [false, true] {
      for upbeat in [false, true] where !(accent && upbeat) {
        let key = TickKey(sound: sound, accent: accent, upbeat: upbeat)
        if tickCache[key] != nil { continue }
        tickCache[key] = makeBuffer(
          samples: synthTick(sound: sound, accent: accent, upbeat: upbeat)
        )
      }
    }
  }

  private func makeBuffer(samples: [Float]) -> AVAudioPCMBuffer? {
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
    else { return nil }
    buffer.frameLength = AVAudioFrameCount(samples.count)
    if let channel = buffer.floatChannelData?[0] {
      samples.withUnsafeBufferPointer { src in
        guard let base = src.baseAddress else { return }
        for i in 0..<samples.count {
          channel[i] = softClip(base[i])
        }
      }
    }
    return buffer
  }

  // MARK: - Ticks

  private func synthTick(sound: SoundId, accent: Bool, upbeat: Bool) -> [Float] {
    let level: Float = accent ? 1.05 : (upbeat ? 0.38 : 0.78)
    switch sound {
    case .click: return synthMetronomeClick(accent: accent, level: level)
    case .drum: return synthDrum(accent: accent, level: level)
    case .wood: return synthWoodblock(accent: accent, upbeat: upbeat, level: level)
    case .clap: return synthClap(accent: accent, level: level)
    }
  }

  private func synthMetronomeClick(accent: Bool, level: Float) -> [Float] {
    let dur = accent ? 0.07 : 0.045
    let n = Int(sampleRate * dur)
    var out = [Float](repeating: 0, count: n)
    let f1 = accent ? 380.0 : 320.0
    let f2 = accent ? 620.0 : 510.0
    var lp: Float = 0
    let invSr = 1.0 / sampleRate
    for i in 0..<n {
      let t = Double(i) * invSr
      let snap = Float(exp(-t * 95))
      let tip = Float(exp(-t * 280))
      let knock =
        Float(sin(2 * .pi * f1 * t)) * snap * 0.7
        + Float(sin(2 * .pi * f2 * t)) * snap * 0.25
      lp = lp * 0.55 + whiteNoise() * 0.45
      out[i] = (knock + lp * tip * 0.9) * level
    }
    return lowpass(out, cutoff: accent ? 1600 : 1300)
  }

  private func synthDrum(accent: Bool, level: Float) -> [Float] {
    let dur = accent ? 0.28 : 0.14
    let n = Int(sampleRate * dur)
    var out = [Float](repeating: 0, count: n)
    let invSr = 1.0 / sampleRate
    if accent {
      for i in 0..<n {
        let t = Double(i) * invSr
        let env = Float(exp(-t * 11))
        let f = 95.0 * exp(-t * 12) + 38
        let body = Float(sin(2 * .pi * f * t)) * env
        let sub = Float(sin(2 * .pi * (f * 0.5) * t)) * env * 0.35
        let beater = whiteNoise() * Float(exp(-t * 70)) * 0.18
        out[i] = tanh((body + sub) * 1.2 + beater) * level
      }
      return lowpass(out, cutoff: 1800)
    } else {
      var lp: Float = 0
      for i in 0..<n {
        let t = Double(i) * invSr
        let env = Float(exp(-t * 22))
        let shell = Float(sin(2 * .pi * 165 * t)) * Float(exp(-t * 30)) * 0.28
        lp = lp * 0.82 + whiteNoise() * 0.18
        out[i] = (shell + lp * env * 0.7) * level
      }
      return lowpass(out, cutoff: 4500)
    }
  }

  private func synthWoodblock(accent: Bool, upbeat: Bool, level: Float) -> [Float] {
    let dur = accent ? 0.11 : 0.07
    let n = Int(sampleRate * dur)
    var out = [Float](repeating: 0, count: n)
    let base = accent ? 740.0 : (upbeat ? 560.0 : 640.0)
    let modes: [(Double, Double, Float)] = [
      (1.0, 38, 1.0),
      (1.55, 52, 0.4),
      (2.15, 78, 0.15),
    ]
    let invSr = 1.0 / sampleRate
    for i in 0..<n {
      let t = Double(i) * invSr
      var s: Float = 0
      for (ratio, decay, amp) in modes {
        s += Float(sin(2 * .pi * base * ratio * t)) * Float(exp(-t * decay)) * amp
      }
      out[i] = (s * 0.5 + whiteNoise() * Float(exp(-t * 160)) * 0.35) * level
    }
    return lowpass(out, cutoff: 3200)
  }

  private func synthClap(accent: Bool, level: Float) -> [Float] {
    let dur = accent ? 0.32 : 0.22
    let n = Int(sampleRate * dur)
    var out = [Float](repeating: 0, count: n)
    let delays: [Double] = accent ? [0, 0.014, 0.028, 0.045] : [0, 0.013, 0.027]
    let amps: [Float] = accent ? [1.0, 0.75, 0.55, 0.35] : [1.0, 0.7, 0.45]
    var lp: Float = 0
    let invSr = 1.0 / sampleRate
    for i in 0..<n {
      let t = Double(i) * invSr
      var burst: Float = 0
      for (d, a) in zip(delays, amps) {
        let u = t - d
        if u >= 0 { burst += whiteNoise() * Float(exp(-u * 42)) * a }
      }
      lp = lp * 0.7 + burst * 0.3
      let chest = Float(sin(2 * .pi * 420 * t)) * Float(exp(-t * 14)) * 0.12
      out[i] = (lp + chest) * level * 0.9
    }
    return lowpass(out, cutoff: 3800)
  }

  /// Lighter piano: fewer partials, shorter default — less CPU / RAM per note.
  private func synthPiano(freq: Double, duration: Double = 0.85) -> [Float] {
    let n = Int(sampleRate * duration)
    var out = [Float](repeating: 0, count: n)
    let partials: [(Double, Float, Double)] = [
      (1.0, 1.0, 2.8),
      (2.0, 0.42, 4.5),
      (3.0, 0.18, 6.5),
      (4.0, 0.08, 9.0),
    ]
    let invSr = 1.0 / sampleRate
    let decayScale = (freq / 440 + 0.5) * 0.55
    for i in 0..<n {
      let t = Double(i) * invSr
      let hammer = Float(min(1, t / 0.004)) * Float(exp(-t * 55))
      var s: Float = 0
      for (ratio, amp, decay) in partials {
        let f = freq * ratio * (1 + 0.0006 * ratio * ratio)
        let env = Float(exp(-t * decay * decayScale))
        s += Float(sin(2 * .pi * f * t)) * amp * env
      }
      let noise = whiteNoise() * hammer * 0.1
      let body = Float(sin(2 * .pi * freq * 0.5 * t)) * Float(exp(-t * 3.2)) * 0.08
      out[i] = (s * 0.7 + noise + body) * 0.95
    }
    return lowpass(out, cutoff: min(5500, max(2200, freq * 8)))
  }

  private func whiteNoise() -> Float { Float.random(in: -1...1) }
  private func softClip(_ x: Float) -> Float { tanh(x * 1.05) }

  private func lowpass(_ input: [Float], cutoff: Double) -> [Float] {
    let rc = 1 / (2 * .pi * cutoff)
    let dt = 1 / sampleRate
    let a = Float(dt / (rc + dt))
    var y: Float = 0
    var out = input
    for i in 0..<out.count {
      y += a * (out[i] - y)
      out[i] = y
    }
    return out
  }
}
