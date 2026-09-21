import SwiftUI

enum AppTab: Hashable {
  case metro, theory, settings
}

struct RootTabView: View {
  @EnvironmentObject private var settings: AppSettings
  @State private var tab: AppTab = .metro

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          settings.theme.canvas,
          settings.theme.accentSoft.opacity(0.35),
          settings.theme.canvas,
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        Group {
          switch tab {
          case .metro:
            MetroView()
          case .theory:
            TheoryView()
          case .settings:
            SettingsView()
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)

        HStack(spacing: 4) {
          tabButton(.metro, "节拍")
          tabButton(.theory, "级数")
          tabButton(.settings, "设置")
        }
        .padding(6)
        .background(settings.theme.surface, in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
      }
    }
  }

  private func tabButton(_ id: AppTab, _ title: String) -> some View {
    Button {
      tab = id
    } label: {
      Text(title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(tab == id ? Color.white : settings.theme.inkMuted)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(tab == id ? settings.theme.ink : Color.clear, in: Capsule())
    }
    .buttonStyle(.plain)
  }
}
