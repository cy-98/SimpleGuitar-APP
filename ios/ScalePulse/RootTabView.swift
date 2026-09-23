import SwiftUI

enum AppTab: Hashable {
  case metro, theory, settings
}

private enum RootLayout {
  static let inset: CGFloat = 16
  static let tabPadding: CGFloat = 6
  static let contentToTab: CGFloat = 12
}

struct RootTabView: View {
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var session: AppSession
  @Namespace private var tabNamespace

  private let tabs: [(AppTab, String)] = [
    (.metro, "Metro"),
    (.theory, "Degrees"),
    (.settings, "Settings"),
  ]

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

      Group {
        switch session.tab {
        case .metro:
          MetroView()
        case .theory:
          TheoryView()
        case .settings:
          SettingsView()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.horizontal, RootLayout.inset)
      .padding(.top, RootLayout.inset)
      .safeAreaInset(edge: .bottom, spacing: RootLayout.contentToTab) {
        if !session.fretboardFullscreen {
          tabBar
            .padding(.horizontal, RootLayout.inset)
            .padding(.bottom, RootLayout.inset)
        }
      }
    }
  }

  private var tabBar: some View {
    HStack(spacing: 4) {
      ForEach(tabs, id: \.0) { id, title in
        tabButton(id, title)
      }
    }
    .padding(RootLayout.tabPadding)
    .background(settings.theme.surface, in: Capsule())
  }

  private func tabButton(_ id: AppTab, _ title: String) -> some View {
    Button {
      withAnimation(.spring(response: 0.38, dampingFraction: 0.82, blendDuration: 0)) {
        session.tab = id
      }
    } label: {
      Text(title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(session.tab == id ? Color.white : settings.theme.inkMuted)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background {
          if session.tab == id {
            Capsule()
              .fill(settings.theme.ink)
              .matchedGeometryEffect(id: "tab-pill", in: tabNamespace)
          }
        }
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  RootTabView()
    .environmentObject(AppSettings())
    .environmentObject(AppSession())
}
