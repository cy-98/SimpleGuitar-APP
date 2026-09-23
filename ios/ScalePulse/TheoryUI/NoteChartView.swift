import SwiftUI

struct NoteChartView: View {
  @EnvironmentObject private var settings: AppSettings
  let key: String
  let onPlay: (String) -> Void

  private let slice = 360.0 / 7.0

  /// Steps Do→Re … La→Ti (1 = half, 2 = whole). Color accumulates along the scale.
  private static let ascendingSteps = [2, 2, 1, 2, 2, 2]
  private static let halfBoost = 40.0
  private static let wholeBoost = 80.0
  /// Do darkest; Ti lightest — cumulative along the scale (dark → light).
  private static let doAlpha255 = 200.0
  private static let tiAlpha255 = 28.0
  private static let maxBoost: Double = {
    ascendingSteps.reduce(0.0) { $0 + ($1 == 1 ? halfBoost : wholeBoost) }
  }()

  var body: some View {
    GeometryReader { geo in
      let size = min(geo.size.width, geo.size.height)
      let tonicLetter = String(key.prefix(1)).uppercased()
      let tonicIdx = max(0, Scales.naturalCycle.firstIndex(of: tonicLetter) ?? 0)
      let rot = -Double(tonicIdx) * slice
      let byLetter = Scales.degreesByLetter(root: key)

      ZStack {
        ForEach(Array(Scales.naturalCycle.enumerated()), id: \.offset) { i, letter in
          let deg = byLetter[letter]
          let spelled = deg?.note ?? letter

          DonutSlice(index: i, gap: -0.35)
            .fill(sectorFill(degree: deg?.degree))
            .contentShape(DonutSlice(index: i, gap: -0.35))
            .rotationEffect(.degrees(rot))
            .onTapGesture { onPlay(spelled) }

          let mid = Double(i) * slice - 90 + rot
          let rad = mid * .pi / 180
          let r = size * 0.36
          let alpha = deg.map { Self.alpha(forDegree: $0.degree) } ?? 0
          let onDark = alpha > 0.42
          VStack(spacing: 2) {
            Text(spelled)
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(onDark ? Color.white : settings.theme.ink)
            if let deg {
              Text(deg.solfege)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(onDark ? Color.white.opacity(0.85) : settings.theme.inkMuted)
            }
          }
          .position(
            x: size / 2 + CGFloat(cos(rad)) * r,
            y: size / 2 + CGFloat(sin(rad)) * r
          )
          .allowsHitTesting(false)
        }

        VStack(spacing: 2) {
          Text(key)
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(settings.theme.ink)
          Text("Major")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(settings.theme.inkMuted)
            .textCase(.uppercase)
        }
        .allowsHitTesting(false)
      }
      .frame(width: size, height: size)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func sectorFill(degree: Int?) -> Color {
    guard let degree, (1...7).contains(degree) else {
      return settings.theme.surface
    }
    return settings.theme.accent.opacity(Self.alpha(forDegree: degree))
  }

  /// Cumulative: Do = darkest; each whole +80, each half +40 along Do→Ti (fades to light).
  private static func alpha(forDegree degree: Int) -> Double {
    var boost = 0.0
    if degree > 1 {
      for i in 0..<(degree - 1) {
        boost += ascendingSteps[i] == 1 ? halfBoost : wholeBoost
      }
    }
    // boost 0 → doAlpha (dark); boost max → tiAlpha (light)
    let alpha255 = doAlpha255 + boost * (tiAlpha255 - doAlpha255) / maxBoost
    return alpha255 / 255.0
  }
}

private struct DonutSlice: Shape {
  let index: Int
  let gap: Double
  private let slice = 360.0 / 7.0

  func path(in rect: CGRect) -> Path {
    let cx = rect.midX
    let cy = rect.midY
    let r0 = min(rect.width, rect.height) * 0.26
    let r1 = min(rect.width, rect.height) * 0.46
    let mid = Double(index) * slice - 90
    let a0 = Angle(degrees: mid - slice / 2 + gap / 2)
    let a1 = Angle(degrees: mid + slice / 2 - gap / 2)

    var p = Path()
    p.addArc(center: CGPoint(x: cx, y: cy), radius: r1, startAngle: a0, endAngle: a1, clockwise: false)
    p.addArc(center: CGPoint(x: cx, y: cy), radius: r0, startAngle: a1, endAngle: a0, clockwise: true)
    p.closeSubpath()
    return p
  }
}
