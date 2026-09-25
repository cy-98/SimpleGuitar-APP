import SwiftUI
import UIKit

/// Global orientation gate. Info.plist lists portrait + landscape so the device
/// *can* rotate; this mask decides when it is *allowed*.
enum OrientationLock {
  static var mask: UIInterfaceOrientationMask = .portrait

  /// Portrait-only everywhere except Degrees fretboard fullscreen and Tuner.
  static func sync(tab: AppTab, fretboardFullscreen: Bool) {
    let allowLandscape = fretboardFullscreen || tab == .tuner
    apply(allowLandscape ? .allButUpsideDown : .portrait)
  }

  private static func apply(_ mask: UIInterfaceOrientationMask) {
    guard self.mask != mask else { return }
    self.mask = mask

    guard let scene = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first
    else { return }

    scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
    for window in scene.windows {
      window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
  }
}
