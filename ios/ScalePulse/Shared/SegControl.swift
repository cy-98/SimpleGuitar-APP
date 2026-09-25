import SwiftUI

struct SegControl<T: Hashable>: View {
  @EnvironmentObject private var settings: AppSettings
  let options: [(T, String)]
  @Binding var selection: T
  var compact: Bool = false

  /// `nil` when `selection` is not in this control's options (e.g. Rhythm split across two rows).
  private var selectedIndex: Int? {
    options.firstIndex(where: { $0.0 == selection })
  }

  var body: some View {
    let pad: CGFloat = compact ? 3 : 4
    let minH: CGFloat = compact ? 30 : 34

    HStack(spacing: 0) {
      ForEach(Array(options.enumerated()), id: \.element.0) { _, item in
        let value = item.0
        let title = item.1
        let isSelected = selection == value
        Button {
          selection = value
        } label: {
          Text(title)
            .font(.system(
              size: compact ? (title.count <= 3 ? 14 : 13) : (title.count <= 2 ? 18 : 15),
              weight: .semibold
            ))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(isSelected ? Color.white : settings.theme.ink.opacity(0.72))
            .frame(maxWidth: .infinity, minHeight: minH)
            .contentShape(Rectangle())
            .accessibilityLabel(
              (value as? MetroPattern)?.accessibilityLabel ?? title
            )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(pad)
    .background {
      GeometryReader { geo in
        let count = max(options.count, 1)
        let innerW = geo.size.width - pad * 2
        let cellW = innerW / CGFloat(count)
        let thumbH = geo.size.height - pad * 2
        Capsule()
          .fill(settings.theme.ink.opacity(0.08))
        if let selectedIndex {
          Capsule()
            .fill(settings.theme.ink)
            .frame(width: cellW, height: thumbH)
            .offset(x: pad + CGFloat(selectedIndex) * cellW, y: pad)
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9), value: selectedIndex)
        }
      }
    }
  }
}
