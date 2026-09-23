import SwiftUI

struct SegControl<T: Hashable>: View {
  @EnvironmentObject private var settings: AppSettings
  let options: [(T, String)]
  @Binding var selection: T

  var body: some View {
    HStack(spacing: 4) {
      ForEach(options, id: \.0) { value, title in
        Button {
          selection = value
        } label: {
          Text(title)
            .font(.system(size: title.count <= 2 ? 18 : 15, weight: .semibold))
            .foregroundStyle(selection == value ? Color.white : settings.theme.ink.opacity(0.72))
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(
              selection == value ? settings.theme.ink : settings.theme.ink.opacity(0.08),
              in: Capsule()
            )
            .accessibilityLabel(
              (value as? MetroPattern)?.accessibilityLabel ?? title
            )
        }
        .buttonStyle(.plain)
      }
    }
  }
}
