import SwiftUI

enum AppTab: Hashable, CaseIterable, Identifiable {
  case metro, theory, tuner, settings

  var id: Self { self }

  var title: String {
    switch self {
    case .metro: return "Metro"
    case .theory: return "Degrees"
    case .tuner: return "Tuner"
    case .settings: return "Settings"
    }
  }

  var index: Int {
    AppTab.allCases.firstIndex(of: self) ?? 0
  }
}

private enum RootLayout {
  static let inset: CGFloat = 16
  static let tabPadding: CGFloat = 6
  static let contentToTab: CGFloat = 12
  static let tabMinHeight: CGFloat = 48
}

struct RootTabView: View {
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var session: AppSession

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

      TabView(selection: $session.tab) {
        MetroView()
          .tag(AppTab.metro)
        TheoryView()
          .tag(AppTab.theory)
        TunerView()
          .tag(AppTab.tuner)
        SettingsView()
          .tag(AppTab.settings)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      // Keep page turn light — spring here tanks swipe FPS.
      .transaction { $0.animation = .easeInOut(duration: 0.18) }
      .environment(\.activeTab, session.tab)
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
    .onAppear { syncOrientation() }
    .onChange(of: session.tab) { _, _ in syncOrientation() }
    .onChange(of: session.fretboardFullscreen) { _, _ in syncOrientation() }
  }

  private func syncOrientation() {
    OrientationLock.sync(tab: session.tab, fretboardFullscreen: session.fretboardFullscreen)
  }

  private var tabBar: some View {
    let pad = RootLayout.tabPadding
    let tabs = AppTab.allCases

    return HStack(spacing: 4) {
      ForEach(tabs) { id in
        Button {
          session.tab = id
        } label: {
          Text(id.title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(session.tab == id ? Color.white : settings.theme.inkMuted)
            .frame(maxWidth: .infinity, minHeight: RootLayout.tabMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .padding(pad)
    .background {
      GeometryReader { geo in
        let count = CGFloat(tabs.count)
        let gap: CGFloat = 4
        let innerW = geo.size.width - pad * 2
        let cellW = (innerW - gap * (count - 1)) / count
        let thumbH = geo.size.height - pad * 2
        let idx = CGFloat(session.tab.index)
        Capsule()
          .fill(settings.theme.surface)
        Capsule()
          .fill(settings.theme.ink)
          .frame(width: cellW, height: thumbH)
          .offset(x: pad + idx * (cellW + gap), y: pad)
          .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9), value: session.tab)
      }
    }
  }
}

#Preview {
  RootTabView()
    .environmentObject(AppSettings())
    .environmentObject(AppSession())
}
