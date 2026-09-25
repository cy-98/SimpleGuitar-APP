import SwiftUI
import UIKit

@main
struct ScalePulseApp: App {
  @UIApplicationDelegateAdaptor(OrientationAppDelegate.self) private var appDelegate
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var settings = AppSettings()
  @StateObject private var session = AppSession()

  var body: some Scene {
    WindowGroup {
      RootTabView()
        .environmentObject(settings)
        .environmentObject(session)
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { _, phase in
          // No background audio: pause metronome and release the audio session.
          if phase == .background {
            session.suspendForBackground()
          }
        }
    }
  }
}

/// Owns the system orientation mask used by `OrientationLock`.
final class OrientationAppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    OrientationLock.mask
  }
}

#Preview {
  RootTabView()
    .environmentObject(AppSettings())
    .environmentObject(AppSession())
}
