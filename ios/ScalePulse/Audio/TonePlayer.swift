import AVFoundation
import Foundation

/// Soft-synth clicks and sung tones. Tick / piano PCM cached; volume via mixer.
final class TonePlayer {
  static let shared = TonePlayer()

  /// 0…1 — applied on the mixer so cached tick buffers stay shared.
  var masterVolume: Float = 1.0 {
    didSet { engine.mainMixerNode.outputVolume = max(0, min(1, masterVolume)) }
  }

  private let engine = AVAudioEngine()
  private let tickPlayer = AVAudioPlayerNode()
  private let tonePlayer = AVAudioPlayerNode()
  private let sampleRate: Double = 44_100
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
      try configurePlaybackSession()
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

  /// Loud speaker output. Call after leaving the tuner mic session.
  func restorePlaybackSession() {
    playLock.lock()
    defer { playLock.unlock() }
    try? activateLoudPlayback()
  }

  private func configurePlaybackSession() throws {
    let session = AVAudioSession.sharedInstance()
    if session.category == .playAndRecord {
      // Tuner is capturing — keep the mic, but force the loud speaker for tones.
      try session.overrideOutputAudioPort(.speaker)
      try session.setActive(true, options: [])
      return
    }
    try activateLoudPlayback()
  }

  private func activateLoudPlayback() throws {
    let session = AVAudioSession.sharedInstance()
    // `.playback` ignores the Ring/Silent switch and uses the loud speaker —
    // unlike leftover `.playAndRecord` + `.measurement` from the tuner.
    try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    try session.setActive(true, options: [])
    try? session.overrideOutputAudioPort(.none)
  }

  private func preferAudibleRoute() {
    let session = AVAudioSession.sharedInstance()
    guard session.category == .playAndRecord else { return }
    try? session.overrideOutputAudioPort(.speaker)
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
    preferAudibleRoute()
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
    preferAudibleRoute()
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
    preferAudibleRoute()

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
    let level: Float = accent ? 1.0 : (upbeat ? 0.42 : 0.78)
    let raw: [Float]
    switch sound {
    case .click: raw = synthMetronomeClick(accent: accent, level: level)
    case .drum: raw = synthDrum(accent: accent, level: level)
    case .wood: raw = synthWoodblock(accent: accent, upbeat: upbeat, level: level)
    case .clap: raw = synthClap(accent: accent, level: level)
    }
    return polishTick(raw)
  }

  /// Soft edges remove the “digital click / zipper” at buffer start & end.
  private func polishTick(_ samples: [Float], fadeIn: Double = 0.0012, fadeOut: Double = 0.014) -> [Float] {
    var out = samples
    let n = out.count
    guard n > 8 else { return out }
    let ain = max(2, Int(sampleRate * fadeIn))
    let aout = max(4, Int(sampleRate * fadeOut))
    for i in 0..<min(ain, n) {
      let w = Float(i + 1) / Float(ain)
      let s = 0.5 - 0.5 * cos(Float.pi * w)
      out[i] *= s
    }
    for j in 0..<min(aout, n) {
      let i = n - 1 - j
      let w = Float(j + 1) / Float(aout)
      let s = 0.5 - 0.5 * cos(Float.pi * w)
      out[i] *= s
    }
    return out
  }

  private func synthMetronomeClick(accent: Bool, level: Float) -> [Float] {
    let dur = accent ? 0.065 : 0.042
    let n = Int(sampleRate * dur)
    var out = [Float](repeating: 0, count: n)
    let f1 = accent ? 920.0 : 780.0
    let f2 = accent ? 1480.0 : 1220.0
    var lp: Float = 0
    let invSr = 1.0 / sampleRate
    for i in 0..<n {
      let t = Double(i) * invSr
      let env = Float(exp(-t * (accent ? 70 : 95)))
      let tip = Float(exp(-t * 220))
      let knock =
        Float(sin(2 * .pi * f1 * t)) * env * 0.62
        + Float(sin(2 * .pi * f2 * t)) * env * 0.22
      lp = lp * 0.72 + whiteNoise() * 0.28
      out[i] = (knock + lp * tip * 0.35) * level
    }
    return lowpass(out, cutoff: accent ? 2400 : 2000)
  }

  private func synthDrum(accent: Bool, level: Float) -> [Float] {
    let dur = accent ? 0.34 : 0.18
    let n = Int(sampleRate * dur)
    var out = [Float](repeating: 0, count: n)
    let invSr = 1.0 / sampleRate
    if accent {
      for i in 0..<n {
        let t = Double(i) * invSr
        let attack = Float(min(1, t / 0.005))
        let env = Float(exp(-t * 8.2)) * attack
        let f = 72.0 * exp(-t * 9.0) + 40
        let body = Float(sin(2 * .pi * f * t)) * env
        let sub = Float(sin(2 * .pi * (f * 0.5) * t)) * env * 0.5
        let thump = Float(sin(2 * .pi * 48 * t)) * Float(exp(-t * 12)) * attack * 0.2
        let beater = whiteNoise() * Float(exp(-t * 130)) * attack * 0.045
        out[i] = tanh((body + sub + thump) * 0.9 + beater) * level * 0.9
      }
      return lowpass(out, cutoff: 850)
    } else {
      var lp: Float = 0
      for i in 0..<n {
        let t = Double(i) * invSr
        let attack = Float(min(1, t / 0.004))
        let env = Float(exp(-t * 15)) * attack
        let shell = Float(sin(2 * .pi * 118 * t)) * Float(exp(-t * 20)) * 0.4
        let body = Float(sin(2 * .pi * 82 * t)) * env * 0.5
        lp = lp * 0.9 + whiteNoise() * 0.1
        out[i] = (shell + body + lp * env * 0.2) * level * 0.88
      }
      return lowpass(out, cutoff: 1400)
    }
  }

  private func synthWoodblock(accent: Bool, upbeat: Bool, level: Float) -> [Float] {
    let dur = accent ? 0.10 : 0.065
    let n = Int(sampleRate * dur)
    var out = [Float](repeating: 0, count: n)
    let base = accent ? 980.0 : (upbeat ? 720.0 : 860.0)
    // Inharmonic wooden partials — less metallic grit.
    let modes: [(Double, Double, Float)] = [
      (1.0, 42, 1.0),
      (1.47, 58, 0.32),
      (2.05, 90, 0.10),
    ]
    let invSr = 1.0 / sampleRate
    for i in 0..<n {
      let t = Double(i) * invSr
      let attack = Float(min(1, t / 0.0015))
      var s: Float = 0
      for (ratio, decay, amp) in modes {
        s += Float(sin(2 * .pi * base * ratio * t)) * Float(exp(-t * decay)) * amp
      }
      let tick = whiteNoise() * Float(exp(-t * 240)) * 0.12
      out[i] = (s * 0.48 + tick) * attack * level
    }
    return lowpass(out, cutoff: 2800)
  }

  private func synthClap(accent: Bool, level: Float) -> [Float] {
    let dur = accent ? 0.28 : 0.20
    let n = Int(sampleRate * dur)
    var out = [Float](repeating: 0, count: n)
    let delays: [Double] = accent ? [0, 0.012, 0.024, 0.038] : [0, 0.011, 0.023]
    let amps: [Float] = accent ? [1.0, 0.7, 0.48, 0.28] : [1.0, 0.65, 0.4]
    var lp: Float = 0
    let invSr = 1.0 / sampleRate
    for i in 0..<n {
      let t = Double(i) * invSr
      var burst: Float = 0
      for (d, a) in zip(delays, amps) {
        let u = t - d
        if u >= 0 { burst += whiteNoise() * Float(exp(-u * 48)) * a }
      }
      lp = lp * 0.78 + burst * 0.22
      let palm = Float(sin(2 * .pi * 180 * t)) * Float(exp(-t * 18)) * 0.08
      out[i] = (lp * 0.85 + palm) * level * 0.82
    }
    return bandpassish(lowpass(out, cutoff: 3200), hipass: 400)
  }

  /// Lighter piano: clean partials, soft hammer, smooth release.
  private func synthPiano(freq: Double, duration: Double = 0.9) -> [Float] {
    let n = Int(sampleRate * duration)
    var out = [Float](repeating: 0, count: n)
    let partials: [(Double, Float, Double)] = [
      (1.0, 1.0, 2.4),
      (2.0, 0.38, 4.0),
      (3.0, 0.14, 6.0),
      (4.0, 0.06, 8.5),
    ]
    let invSr = 1.0 / sampleRate
    let decayScale = (freq / 440 + 0.45) * 0.5
    for i in 0..<n {
      let t = Double(i) * invSr
      let attack = Float(min(1, t / 0.006))
      let hammer = attack * Float(exp(-t * 48))
      var s: Float = 0
      for (ratio, amp, decay) in partials {
        let f = freq * ratio * (1 + 0.0004 * ratio * ratio)
        let env = Float(exp(-t * decay * decayScale))
        s += Float(sin(2 * .pi * f * t)) * amp * env
      }
      let noise = whiteNoise() * hammer * 0.045
      let body = Float(sin(2 * .pi * freq * 0.5 * t)) * Float(exp(-t * 2.8)) * 0.06
      out[i] = (s * 0.68 + noise + body) * attack * 0.92
    }
    return polishTick(lowpass(out, cutoff: min(4800, max(1800, freq * 7))), fadeIn: 0.002, fadeOut: 0.06)
  }

  private func whiteNoise() -> Float { Float.random(in: -1...1) }
  private func softClip(_ x: Float) -> Float { tanh(x * 1.15) }

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

  /// Light one-pole high-pass then leave already-lowpassed signal (clap air without rumble).
  private func bandpassish(_ input: [Float], hipass: Double) -> [Float] {
    let rc = 1 / (2 * .pi * hipass)
    let dt = 1 / sampleRate
    let a = Float(rc / (rc + dt))
    var prevX: Float = 0
    var prevY: Float = 0
    var out = input
    for i in 0..<out.count {
      let x = out[i]
      let y = a * (prevY + x - prevX)
      prevX = x
      prevY = y
      out[i] = y
    }
    return out
  }
}
