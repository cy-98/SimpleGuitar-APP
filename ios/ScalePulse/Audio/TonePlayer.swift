import AVFoundation
import Foundation

/// Shared click / sung-tone player using AVAudioEngine.
final class TonePlayer {
  static let shared = TonePlayer()

  var masterVolume: Float = 0.85

  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let sampleRate: Double = 22_050
  private var started = false

  private init() {
    engine.attach(player)
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    engine.connect(player, to: engine.mainMixerNode, format: format)
    engine.mainMixerNode.outputVolume = 1
  }

  func ensureStarted() {
    guard !started else { return }
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)
      try engine.start()
      player.play()
      started = true
    } catch {
      // ignore session failures in previews
    }
  }

  func playTick(sound: SoundId, accent: Bool, upbeat: Bool) {
    ensureStarted()
    let samples = synthTick(sound: sound, accent: accent, upbeat: upbeat)
    schedule(samples)
  }

  func playSung(midi: Int) {
    ensureStarted()
    let freq = Pitch.midiToFreq(midi)
    schedule(synthTone(freq: freq))
  }

  func playSung(note: String, octave: Int = 4) {
    guard let midi = Pitch.noteToMidi(note, octave: octave) else { return }
    playSung(midi: midi)
  }

  private func schedule(_ samples: [Float]) {
    guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
    else { return }
    buffer.frameLength = AVAudioFrameCount(samples.count)
    if let channel = buffer.floatChannelData?[0] {
      for i in 0..<samples.count {
        channel[i] = samples[i] * masterVolume
      }
    }
    player.scheduleBuffer(buffer, completionHandler: nil)
  }

  private func synthTick(sound: SoundId, accent: Bool, upbeat: Bool) -> [Float] {
    let dur = accent ? 0.055 : (upbeat ? 0.028 : 0.04)
    let n = Int(sampleRate * dur)
    var out = [Float](repeating: 0, count: n)

    switch sound {
    case .clap:
      for i in 0..<n {
        let t = Double(i) / sampleRate
        let env = Float(exp(-t * (accent ? 55 : 70)))
        let noise = Float.random(in: -1...1) * env
        let band = Float(sin(2 * .pi * 1800 * t)) * env * 0.25
        out[i] = (noise * 0.85 + band) * (accent ? 0.95 : (upbeat ? 0.4 : 0.65))
      }
    case .drum:
      let f0 = accent ? 95.0 : 160.0
      for i in 0..<n {
        let t = Double(i) / sampleRate
        let env = Float(exp(-t * (accent ? 28 : 42)))
        let pitch = f0 * exp(-t * 8)
        let body = Float(sin(2 * .pi * pitch * t)) * env
        let click = Float.random(in: -1...1) * Float(exp(-t * 120)) * 0.35
        out[i] = (body + click) * (accent ? 0.95 : (upbeat ? 0.4 : 0.7))
      }
    case .wood:
      let freq = accent ? 920.0 : (upbeat ? 620.0 : 760.0)
      for i in 0..<n {
        let t = Double(i) / sampleRate
        let env = Float(exp(-t * 75))
        let fund = Float(sin(2 * .pi * freq * t))
        let harm = Float(sin(2 * .pi * freq * 2.4 * t)) * 0.35
        out[i] = (fund + harm) * env * (accent ? 0.85 : (upbeat ? 0.32 : 0.55))
      }
    case .click:
      let freq = accent ? 1450.0 : (upbeat ? 880.0 : 1120.0)
      for i in 0..<n {
        let t = Double(i) / sampleRate
        let env = Float(exp(-t * (accent ? 48 : 62)))
        out[i] = Float(sin(2 * .pi * freq * t)) * env * (accent ? 0.9 : (upbeat ? 0.35 : 0.55))
      }
    }
    return out
  }

  private func synthTone(freq: Double, duration: Double = 0.42) -> [Float] {
    let n = Int(sampleRate * duration)
    var out = [Float](repeating: 0, count: n)
    for i in 0..<n {
      let t = Double(i) / sampleRate
      let attack = Float(min(1, t / 0.018))
      let release = Float(exp(-t * 4.5))
      let env = attack * release
      out[i] =
        (Float(sin(2 * .pi * freq * t)) * 0.55
          + Float(sin(2 * .pi * freq * 2 * t)) * 0.1
          + Float(sin(2 * .pi * freq * 3 * t)) * 0.04) * env
    }
    return out
  }
}
