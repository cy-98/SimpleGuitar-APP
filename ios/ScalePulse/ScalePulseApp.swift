import SwiftUI

@main
struct ScalePulseApp: App {
  @StateObject private var settings = AppSettings()

  var body: some Scene {
    WindowGroup {
      RootTabView()
        .environmentObject(settings)
        .preferredColorScheme(.light)
    }
  }
}
