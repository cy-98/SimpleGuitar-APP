import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var session: AppSession

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        section("Sound") {
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(SoundId.allCases) { sound in
              let selected = settings.sound == sound
              Button {
                applySound(sound)
              } label: {
                SoundGlyph(sound: sound)
                  .foregroundStyle(selected ? Color.white : settings.theme.ink)
                  .frame(maxWidth: .infinity, minHeight: 48)
                  .background(
                    selected ? settings.theme.ink : settings.theme.surface,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                  )
              }
              .buttonStyle(.plain)
              .accessibilityLabel(sound.label)
            }
          }
        }

        section("Volume") {
          HStack {
            Slider(value: $settings.volume, in: 0...1)
              .tint(settings.theme.accent)
            Text("\(Int(settings.volume * 100))%")
              .font(.system(size: 13, weight: .semibold).monospacedDigit())
              .foregroundStyle(settings.theme.inkMuted)
              .frame(width: 44, alignment: .trailing)
          }
          .padding(16)
          .background(settings.theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }

        section("Theme") {
          LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
          ) {
            ForEach(ThemeId.allCases) { id in
              let meta = ThemeMeta.meta(id)
              let selected = settings.themeId == id
              Button {
                settings.themeId = id
              } label: {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .fill(
                    LinearGradient(
                      colors: [meta.canvas, meta.accentSoft],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    )
                  )
                  .frame(height: 48)
                  .shadow(
                    color: selected ? settings.theme.ink.opacity(0.28) : .clear,
                    radius: selected ? 8 : 0,
                    y: selected ? 4 : 0
                  )
                  .padding(6)
              }
              .buttonStyle(.plain)
              .accessibilityLabel(id.label)
            }
          }
          .padding(4)
        }
      }
      .padding(.bottom, 12)
    }
  }

  private func applySound(_ sound: SoundId) {
    settings.sound = sound
    session.metronome.sound = sound
    TonePlayer.shared.rebuildTickCache(for: sound)
  }

  private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(settings.theme.inkMuted)
        .textCase(.uppercase)
      content()
    }
  }
}

/// Sound picker glyphs — SF Symbols where reliable; custom paths for drum / 木鱼.
private struct SoundGlyph: View {
  let sound: SoundId

  var body: some View {
    Group {
      switch sound {
      case .click:
        Image(systemName: "metronome")
          .font(.system(size: 22, weight: .semibold))
      case .clap:
        Image(systemName: "hands.clap.fill")
          .font(.system(size: 22, weight: .semibold))
      case .drum:
        DrumGlyph()
          .frame(width: 26, height: 22)
      case .wood:
        MuyuGlyph()
          .frame(width: 28, height: 20)
      }
    }
  }
}

/// Simple kick / tom: shell + batter head.
private struct DrumGlyph: View {
  var body: some View {
    Canvas { ctx, size in
      let w = size.width
      let h = size.height
      let line = max(1.6, w * 0.08)

      var shell = Path()
      shell.addRoundedRect(
        in: CGRect(x: w * 0.14, y: h * 0.38, width: w * 0.72, height: h * 0.5),
        cornerSize: CGSize(width: 3, height: 3)
      )
      ctx.stroke(shell, with: .foreground, lineWidth: line)

      var head = Path()
      head.addEllipse(in: CGRect(x: w * 0.1, y: h * 0.06, width: w * 0.8, height: h * 0.48))
      ctx.stroke(head, with: .foreground, lineWidth: line)
    }
    .accessibilityHidden(true)
  }
}

/// 木鱼：椭圆身 + 顶部敲击口（even-odd 挖空）。
private struct MuyuGlyph: View {
  var body: some View {
    Canvas { ctx, size in
      let w = size.width
      let h = size.height
      var path = Path()
      path.addEllipse(in: CGRect(x: w * 0.02, y: h * 0.16, width: w * 0.96, height: h * 0.76))
      path.addEllipse(in: CGRect(x: w * 0.26, y: h * 0.28, width: w * 0.48, height: h * 0.22))
      ctx.fill(path, with: .foreground, style: FillStyle(eoFill: true))
    }
    .accessibilityHidden(true)
  }
}

#Preview {
  SettingsView()
    .environmentObject(AppSettings())
    .environmentObject(AppSession())
    .padding()
}
