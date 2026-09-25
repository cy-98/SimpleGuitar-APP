import SwiftUI

private struct ActiveTabKey: EnvironmentKey {
  static let defaultValue: AppTab = .metro
}

extension EnvironmentValues {
  var activeTab: AppTab {
    get { self[ActiveTabKey.self] }
    set { self[ActiveTabKey.self] = newValue }
  }
}
