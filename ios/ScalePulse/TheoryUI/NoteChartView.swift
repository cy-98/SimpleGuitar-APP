import SwiftUI

struct NoteChartView: View {
  @EnvironmentObject private var settings: AppSettings
  let key: String
  let showSolfege: Bool
  let onPlay: (String) -> Void

  private let slice = 360.0 / 7.0

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
          let tonic = letter == tonicLetter
          DonutSlice(index: i, gap: -0.35)
            .fill(tonic ? settings.theme.accent.opacity(0.28) : (i % 2 == 1 ? settings.theme.canvas.opacity(0.65) : settings.theme.surface))
            .rotationEffect(.degrees(rot))

          let mid = Double(i) * slice - 90 + rot
          let rad = mid * .pi / 180
          let r = size * 0.36
          VStack(spacing: 2) {
            Text(spelled)
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(tonic ? settings.theme.accent : settings.theme.ink)
            if let deg {
              Text(showSolfege ? "\(deg.degree) · \(deg.solfege)" : "\(deg.degree)")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(settings.theme.inkMuted)
            }
          }
          .position(
            x: size / 2 + CGFloat(cos(rad)) * r,
            y: size / 2 + CGFloat(sin(rad)) * r
          )
          .onTapGesture { onPlay(spelled) }
        }

        VStack(spacing: 2) {
          Text(key)
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(settings.theme.ink)
          Text("大调")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(settings.theme.inkMuted)
            .textCase(.uppercase)
        }
      }
      .frame(width: size, height: size)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
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
