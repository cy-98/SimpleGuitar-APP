import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var settings: AppSettings

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        section("声源") {
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(SoundId.allCases) { sound in
              Button {
                settings.sound = sound
                TonePlayer.shared.playTick(sound: sound, accent: true, upbeat: false)
              } label: {
                Text(sound.label)
                  .font(.system(size: 15, weight: .semibold))
                  .foregroundStyle(settings.sound == sound ? Color.white : settings.theme.ink)
                  .frame(maxWidth: .infinity, minHeight: 48)
                  .background(
                    settings.sound == sound ? settings.theme.ink : settings.theme.surface,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                  )
              }
              .buttonStyle(.plain)
            }
          }
        }

        section("音量") {
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

        section("反拍静音") {
          Toggle(isOn: $settings.muteUpbeats) {
            VStack(alignment: .leading, spacing: 4) {
              Text("只听正拍")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(settings.theme.ink)
              Text("反拍格子仍闪，不发声")
                .font(.system(size: 12))
                .foregroundStyle(settings.theme.inkMuted)
            }
          }
          .tint(settings.theme.accent)
          .padding(16)
          .background(settings.theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }

        section("配色") {
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(ThemeId.allCases) { id in
              let meta = ThemeMeta.meta(id)
              Button {
                settings.themeId = id
              } label: {
                VStack(spacing: 6) {
                  RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                      LinearGradient(
                        colors: [meta.canvas, meta.accentSoft],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                    )
                    .frame(height: 48)
                    .overlay {
                      if settings.themeId == id {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                          .stroke(settings.theme.ink, lineWidth: 2)
                      }
                    }
                  Text(id.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(settings.theme.inkMuted)
                }
              }
              .buttonStyle(.plain)
            }
          }
        }

        Text("前台练习：锁屏/后台不保证节拍继续。")
          .font(.system(size: 12))
          .foregroundStyle(settings.theme.inkMuted)
          .padding(.top, 8)
      }
      .padding(.bottom, 12)
    }
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
