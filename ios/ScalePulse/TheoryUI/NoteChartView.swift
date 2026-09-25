import SwiftUI

struct NoteChartView: View {
  @EnvironmentObject private var settings: AppSettings
  let key: String
  let showNoteLetters: Bool
  let onPlay: (String) -> Void

  private let slice = 360.0 / 7.0
  /// Match webapp `cubic-bezier(0.16, 1, 0.3, 1)` + 0.9s.
  private let wheelAnimation = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.9)

  /// Outer edge fills the slot; inner ratios match web R0/R1/LABEL (52/92/72).
  fileprivate static let r1Frac: CGFloat = 0.50
  fileprivate static let r0Frac: CGFloat = 0.50 * (52.0 / 92.0)
  fileprivate static let labelFrac: CGFloat = 0.50 * (72.0 / 92.0)
  /// Match web `.note-chart-hub { width: 42% }`.
  fileprivate static let hubFrac: CGFloat = 0.42
  private static let designSide: CGFloat = 200

  /// Webapp: `--chart-rot: -tonicIdx * (360/7)`.
  private var rotationDegrees: Double {
    let tonicLetter = String(key.prefix(1)).uppercased()
    let tonicIdx = max(0, Scales.naturalCycle.firstIndex(of: tonicLetter) ?? 0)
    return -Double(tonicIdx) * slice
  }

  var body: some View {
    GeometryReader { geo in
      let side = min(geo.size.width, geo.size.height)
      let scale = side / Self.designSide
      let rot = rotationDegrees
      let byLetter = Scales.degreesByLetter(root: key)
      let labelR = side * Self.labelFrac
      let noteSize = 13 * scale
      let hubKeySize = 23 * scale
      let hubLabelSize = 10 * scale
      let hubSide = side * Self.hubFrac
      let fills = Scales.naturalCycle.enumerated().map { i, letter -> Color in
        sectorFill(index: i, tonic: byLetter[letter]?.degree == 1)
      }

      ZStack {
        // Soft under-plate — lifts the whole wheel off the canvas.
        Circle()
          .fill(settings.theme.accentSoft.opacity(0.50))
          .frame(width: side * 0.93, height: side * 0.93)
          .shadow(color: settings.theme.ink.opacity(0.10), radius: 20, y: 10)

        // Sector disc with a soft drop shadow (no edge stroke).
        Circle()
          .fill(settings.theme.surface)
          .frame(width: side * Self.r1Frac * 2, height: side * Self.r1Frac * 2)
          .shadow(color: settings.theme.ink.opacity(0.08), radius: 14, y: 6)

        // Sectors drawn in one Canvas pass (no Shape stroke / AA hairlines).
        Canvas { context, size in
          let cx = size.width / 2
          let cy = size.height / 2
          let r0 = min(size.width, size.height) * Self.r0Frac
          let r1 = min(size.width, size.height) * Self.r1Frac
          let center = CGPoint(x: cx, y: cy)

          for i in 0..<7 {
            let mid = Double(i) * slice - 90
            let a0 = Angle(degrees: mid - slice / 2)
            let a1 = Angle(degrees: mid + slice / 2)
            var path = Path()
            path.addArc(center: center, radius: r1, startAngle: a0, endAngle: a1, clockwise: false)
            path.addArc(center: center, radius: r0, startAngle: a1, endAngle: a0, clockwise: true)
            path.closeSubpath()
            context.fill(
              path,
              with: .color(fills[i]),
              style: FillStyle(antialiased: false)
            )
          }
        }
        .frame(width: side, height: side)
        .rotationEffect(.degrees(rot))
        .animation(wheelAnimation, value: rot)
        .allowsHitTesting(false)

        // Invisible hit targets (same geometry).
        ZStack {
          ForEach(Array(Scales.naturalCycle.enumerated()), id: \.offset) { i, letter in
            let deg = byLetter[letter]
            let spelled = deg?.note ?? letter
            DonutSlice(index: i, gap: 0)
              .fill(Color.white.opacity(0.001))
              .contentShape(DonutSlice(index: i, gap: 0))
              .onTapGesture { onPlay(spelled) }
          }
        }
        .frame(width: side, height: side)
        .rotationEffect(.degrees(rot))

        // Upright labels.
        ZStack {
          ForEach(Array(Scales.naturalCycle.enumerated()), id: \.offset) { i, letter in
            let deg = byLetter[letter]
            let spelled = deg?.note ?? letter
            let tonic = deg?.degree == 1
            let mid = Double(i) * slice - 90
            let rad = mid * .pi / 180

            Group {
              if showNoteLetters {
                Text(spelled)
                  .font(.system(size: noteSize, weight: .bold, design: .monospaced))
                  .tracking(-0.02 * noteSize)
                  .foregroundStyle(tonic ? settings.theme.accent : settings.theme.ink)
              } else if let deg {
                Text("\(deg.degree)")
                  .font(.system(size: noteSize, weight: .bold, design: .monospaced))
                  .tracking(-0.02 * noteSize)
                  .foregroundStyle(tonic ? settings.theme.accent : settings.theme.ink)
              }
            }
            .rotationEffect(.degrees(-rot))
            .position(
              x: side / 2 + CGFloat(cos(rad)) * labelR,
              y: side / 2 + CGFloat(sin(rad)) * labelR
            )
            .allowsHitTesting(false)
          }
        }
        .frame(width: side, height: side)
        .rotationEffect(.degrees(rot))

        // Elevated hub — soft shadow sits above the sectors.
        VStack(spacing: 2 * scale) {
          Text(key)
            .font(.system(size: hubKeySize, weight: .bold, design: .monospaced))
            .tracking(-0.03 * hubKeySize)
            .foregroundStyle(settings.theme.ink)
          Text("Major")
            .font(.system(size: hubLabelSize, weight: .semibold))
            .tracking(0.06 * hubLabelSize)
            .foregroundStyle(settings.theme.inkMuted)
            .textCase(.uppercase)
        }
        .frame(width: hubSide, height: hubSide)
        .background {
          Circle()
            .fill(settings.theme.surface)
            .shadow(color: settings.theme.ink.opacity(0.14), radius: 12, y: 5)
            .shadow(color: settings.theme.ink.opacity(0.05), radius: 2, y: 1)
        }
        .allowsHitTesting(false)
      }
      .frame(width: side, height: side)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  /// Web: zebra even = surface-soft; tonic = accent tint (slightly stronger for hierarchy).
  private func sectorFill(index: Int, tonic: Bool) -> Color {
    if tonic {
      return settings.theme.accent.opacity(0.38)
    }
    if index.isMultiple(of: 2) {
      return settings.theme.accentSoft.opacity(0.72)
    }
    return settings.theme.surface
  }
}

private struct DonutSlice: Shape {
  let index: Int
  let gap: Double
  private let slice = 360.0 / 7.0

  func path(in rect: CGRect) -> Path {
    let cx = rect.midX
    let cy = rect.midY
    let side = min(rect.width, rect.height)
    let r0 = side * NoteChartView.r0Frac
    let r1 = side * NoteChartView.r1Frac
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
