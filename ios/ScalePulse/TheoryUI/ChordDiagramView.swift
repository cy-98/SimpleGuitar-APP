import SwiftUI

/// Classic guitar chord chart: nut/base at top, low E → high e left to right.
struct ChordDiagramView: View {
  @EnvironmentObject private var settings: AppSettings
  let diagram: ChordDiagram

  private let stringCount = 6
  private let fretCount = 4

  var body: some View {
    let start = diagram.windowStart
    let displayOrder = Array((0..<stringCount).reversed()) // low E … high e

    VStack(spacing: 1) {
      // Mutes / opens above nut
      HStack(spacing: 0) {
        ForEach(displayOrder, id: \.self) { s in
          let fret = diagram.frets[s]
          Text(marker(fret))
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(settings.theme.inkMuted)
            .frame(maxWidth: .infinity)
        }
      }
      .frame(height: 9)

      HStack(alignment: .top, spacing: 1) {
        Text(start > 1 ? "\(start)" : "")
          .font(.system(size: 8, weight: .bold).monospacedDigit())
          .foregroundStyle(settings.theme.inkMuted)
          .frame(width: 9, alignment: .trailing)
          .padding(.top, 1)

        ZStack(alignment: .topLeading) {
          Rectangle()
            .fill(settings.theme.ink.opacity(start == 1 ? 0.85 : 0.25))
            .frame(height: start == 1 ? 2.5 : 1)

          GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cellW = w / CGFloat(stringCount - 1)
            let cellH = h / CGFloat(fretCount)

            ForEach(0..<stringCount, id: \.self) { i in
              let x = cellW * CGFloat(i)
              Path { p in
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: h))
              }
              .stroke(settings.theme.ink.opacity(0.35), lineWidth: i == 0 || i == stringCount - 1 ? 1.2 : 0.9)
            }

            ForEach(1...fretCount, id: \.self) { f in
              let y = cellH * CGFloat(f)
              Path { p in
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: w, y: y))
              }
              .stroke(settings.theme.ink.opacity(0.2), lineWidth: 0.9)
            }

            ForEach(0..<stringCount, id: \.self) { i in
              let s = displayOrder[i]
              if let fret = diagram.frets[s], fret > 0 {
                let row = fret - start
                if row >= 0 && row < fretCount {
                  let x = cellW * CGFloat(i)
                  let y = cellH * (CGFloat(row) + 0.5)
                  Circle()
                    .fill(settings.theme.ink)
                    .frame(width: min(cellW, cellH) * 0.55, height: min(cellW, cellH) * 0.55)
                    .position(x: x, y: y)
                }
              }
            }
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
      }
    }
    .frame(width: 56)
    .accessibilityHidden(true)
  }

  private func marker(_ fret: Int?) -> String {
    guard let fret else { return "×" }
    return fret == 0 ? "○" : " "
  }
}
