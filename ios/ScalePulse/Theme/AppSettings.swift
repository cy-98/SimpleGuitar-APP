import SwiftUI
import Combine

enum ThemeId: String, CaseIterable, Identifiable {
  case meadow, mist, blush, graphite, flare, tide

  var id: String { rawValue }

  var label: String {
    switch self {
    case .meadow: return "草地"
    case .mist: return "薄雾"
    case .blush: return "暮粉"
    case .graphite: return "石墨"
    case .flare: return "焰橘"
    case .tide: return "潮汐"
    }
  }
}

struct ThemeMeta {
  let id: ThemeId
  let canvas: Color
  let surface: Color
  let ink: Color
  let inkMuted: Color
  let accent: Color
  let accentSoft: Color

  static func meta(_ id: ThemeId) -> ThemeMeta {
    switch id {
    case .meadow:
      return ThemeMeta(
        id: id,
        canvas: Color(hex: 0xEEFCE3),
        surface: .white,
        ink: Color(hex: 0x1F3D2A),
        inkMuted: Color(hex: 0x5A7A62),
        accent: Color(hex: 0x3D9A55),
        accentSoft: Color(hex: 0x96E6A1)
      )
    case .mist:
      return ThemeMeta(
        id: id,
        canvas: Color(hex: 0xF5F7FA),
        surface: .white,
        ink: Color(hex: 0x12324A),
        inkMuted: Color(hex: 0x5B7F94),
        accent: Color(hex: 0x209CFF),
        accentSoft: Color(hex: 0xC3CFE2)
      )
    case .blush:
      return ThemeMeta(
        id: id,
        canvas: Color(hex: 0xFEF9D7),
        surface: .white,
        ink: Color(hex: 0x4A2C3D),
        inkMuted: Color(hex: 0x8A6A7A),
        accent: Color(hex: 0xC46A9E),
        accentSoft: Color(hex: 0xD299C2)
      )
    case .graphite:
      return ThemeMeta(
        id: id,
        canvas: Color(hex: 0x6E6E6E),
        surface: Color(hex: 0xF2F2F2),
        ink: Color(hex: 0x1A1A1A),
        inkMuted: Color(hex: 0x555555),
        accent: Color(hex: 0x333333),
        accentSoft: Color(hex: 0x989898)
      )
    case .flare:
      return ThemeMeta(
        id: id,
        canvas: Color(hex: 0xFFF3EE),
        surface: .white,
        ink: Color(hex: 0x3D2218),
        inkMuted: Color(hex: 0x8A6558),
        accent: Color(hex: 0xD4654A),
        accentSoft: Color(hex: 0xF0C4B0)
      )
    case .tide:
      return ThemeMeta(
        id: id,
        canvas: Color(hex: 0xE8F7FF),
        surface: .white,
        ink: Color(hex: 0x12324A),
        inkMuted: Color(hex: 0x5B7F94),
        accent: Color(hex: 0x209CFF),
        accentSoft: Color(hex: 0x68E0CF)
      )
    }
  }
}

extension Color {
  init(hex: UInt32, alpha: Double = 1) {
    let r = Double((hex >> 16) & 0xFF) / 255
    let g = Double((hex >> 8) & 0xFF) / 255
    let b = Double(hex & 0xFF) / 255
    self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
  }
}

enum SoundId: String, CaseIterable, Identifiable {
  case click, drum, wood, clap

  var id: String { rawValue }

  var label: String {
    switch self {
    case .click: return "滴答"
    case .drum: return "鼓声"
    case .wood: return "木鱼"
    case .clap: return "拍手"
    }
  }
}

final class AppSettings: ObservableObject {
  @Published var themeId: ThemeId {
    didSet { UserDefaults.standard.set(themeId.rawValue, forKey: Keys.theme) }
  }
  @Published var sound: SoundId {
    didSet { UserDefaults.standard.set(sound.rawValue, forKey: Keys.sound) }
  }
  @Published var volume: Double {
    didSet {
      UserDefaults.standard.set(volume, forKey: Keys.volume)
      TonePlayer.shared.masterVolume = Float(volume)
    }
  }
  @Published var muteUpbeats: Bool {
    didSet { UserDefaults.standard.set(muteUpbeats, forKey: Keys.muteUpbeats) }
  }

  var theme: ThemeMeta { ThemeMeta.meta(themeId) }

  private enum Keys {
    static let theme = "scale-pulse-theme"
    static let sound = "scale-pulse-sound"
    static let volume = "scale-pulse-volume"
    static let muteUpbeats = "scale-pulse-mute-upbeats"
  }

  init() {
    let t = UserDefaults.standard.string(forKey: Keys.theme).flatMap(ThemeId.init) ?? .mist
    let s = UserDefaults.standard.string(forKey: Keys.sound).flatMap(SoundId.init) ?? .click
    let v = UserDefaults.standard.object(forKey: Keys.volume) as? Double ?? 0.85
    let m = UserDefaults.standard.bool(forKey: Keys.muteUpbeats)
    themeId = t
    sound = s
    volume = v
    muteUpbeats = m
    TonePlayer.shared.masterVolume = Float(v)
  }
}
