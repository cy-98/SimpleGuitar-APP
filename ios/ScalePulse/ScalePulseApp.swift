import SwiftUI

@main
struct ScalePulseApp: App {
  @StateObject private var settings = AppSettings()
  @StateObject private var session = AppSession()

  var body: some Scene {
    WindowGroup {
      RootTabView()
        .environmentObject(settings)
        .environmentObject(session)
        .preferredColorScheme(.light)
    }
  }
}

#Preview {
  RootTabView()
    .environmentObject(AppSettings())
    .environmentObject(AppSession())
}
