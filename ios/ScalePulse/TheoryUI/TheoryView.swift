import SwiftUI

struct TheoryView: View {
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var session: AppSession

  var body: some View {
    VStack(spacing: 12) {
      HStack(alignment: .center) {
        Text("\(session.theoryKey) Major")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(settings.theme.ink)
        Spacer()
        Button {
          session.fretboardFullscreen = true
        } label: {
          Label("Fretboard", systemImage: "guitars")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(settings.theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(settings.theme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open fretboard")
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(Scales.majorKeys, id: \.self) { k in
            Button {
              session.theoryKey = k
              TonePlayer.shared.playPiano(note: k)
            } label: {
              Text(k)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(k == session.theoryKey ? Color.white : settings.theme.inkMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                  k == session.theoryKey ? settings.theme.ink : settings.theme.surface,
                  in: Capsule()
                )
            }
            .buttonStyle(.plain)
          }
        }
      }

      SegControl(
        options: [(.ring, "Ring"), (.chords, "Chords")],
        selection: $session.theoryPane
      )

      Group {
        switch session.theoryPane {
        case .ring:
          NoteChartView(key: session.theoryKey) { note in
            TonePlayer.shared.playPiano(note: note)
          }
        case .chords:
          ChordDictView(key: session.theoryKey) { chord in
            TonePlayer.shared.playChord(notes: chord.notes)
          }
        }
      }
      .padding(12)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(settings.theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
    .fullScreenCover(isPresented: $session.fretboardFullscreen) {
      FretboardFullscreenView(
        key: session.theoryKey,
        positionId: $session.positionId,
        onClose: { session.fretboardFullscreen = false },
        onTap: handleDot,
        onSelectKey: { k in
          session.theoryKey = k
        }
      )
      .environmentObject(settings)
      .environmentObject(session)
    }
  }

  private func handleDot(_ dot: FretDot) {
    if dot.isTonic && Scales.isMajorKey(dot.degree.note) {
      session.theoryKey = dot.degree.note
    }
  }
}

private struct FretboardFullscreenView: View {
  @EnvironmentObject private var settings: AppSettings
  let key: String
  @Binding var positionId: String
  let onClose: () -> Void
  let onTap: (FretDot) -> Void
  let onSelectKey: (String) -> Void

  private var position: FretPosition { Fretboard.getPosition(positionId) }
  private var dotMap: [String: FretDot] {
    let dots = Fretboard.scaleDots(key: key)
    return Dictionary(uniqueKeysWithValues: dots.map { ($0.id, $0) })
  }

  var body: some View {
    ZStack {
      settings.theme.canvas.ignoresSafeArea()

      VStack(spacing: 12) {
        HStack {
          Text("\(key) Major")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(settings.theme.ink)
          Spacer()
          Button("Close", action: onClose)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(settings.theme.accent)
        }

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            ForEach(Scales.majorKeys, id: \.self) { k in
              Button {
                onSelectKey(k)
              } label: {
                Text(k)
                  .font(.system(size: 14, weight: .bold))
                  .foregroundStyle(k == key ? Color.white : settings.theme.inkMuted)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 8)
                  .background(k == key ? settings.theme.ink : settings.theme.surface, in: Capsule())
              }
              .buttonStyle(.plain)
            }
          }
        }

        FretboardView(dots: dotMap, position: position, onTap: onTap)
          .padding(12)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(settings.theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

        SegControl(
          options: Fretboard.positions.map { ($0.id, $0.label) },
          selection: $positionId
        )
      }
      .padding(16)
    }
  }
}

/// Vertical neck: frets top→bottom (0…12), strings left→right (e…E). Fits one screen.
private struct FretboardView: View {
  @EnvironmentObject private var settings: AppSettings
  let dots: [String: FretDot]
  let position: FretPosition
  let onTap: (FretDot) -> Void

  private let fretLabelW: CGFloat = 20
  private let headerH: CGFloat = 22
  private let frets = Array(Fretboard.fretMin...Fretboard.fretMax)
  private let stringCount = 6

  var body: some View {
    GeometryReader { geo in
      let boardW = max(0, geo.size.width - fretLabelW)
      let boardH = max(0, geo.size.height - headerH)
      let cellW = boardW / CGFloat(stringCount)
      let cellH = boardH / CGFloat(frets.count)
      let dotSize = min(cellW, cellH) * 0.72

      VStack(spacing: 0) {
        HStack(spacing: 0) {
          Color.clear.frame(width: fretLabelW, height: headerH)
          ForEach(0..<stringCount, id: \.self) { s in
            Text(Fretboard.stringLabels[s])
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(settings.theme.inkMuted)
              .frame(width: cellW, height: headerH)
          }
        }

        ZStack(alignment: .topLeading) {
          ForEach(0..<stringCount, id: \.self) { s in
            let x = fretLabelW + cellW * (CGFloat(s) + 0.5)
            Path { p in
              p.move(to: CGPoint(x: x, y: 0))
              p.addLine(to: CGPoint(x: x, y: boardH))
            }
            .stroke(
              settings.theme.ink.opacity(0.2),
              lineWidth: s == 0 || s == stringCount - 1 ? 1.5 : 1
            )
          }

          ForEach(frets, id: \.self) { fret in
            let y = cellH * CGFloat(fret)
            Path { p in
              p.move(to: CGPoint(x: fretLabelW, y: y))
              p.addLine(to: CGPoint(x: fretLabelW + boardW, y: y))
            }
            .stroke(
              settings.theme.ink.opacity(fret == 0 ? 0.5 : 0.12),
              lineWidth: fret == 0 ? 3 : 1
            )
          }

          VStack(spacing: 0) {
            ForEach(frets, id: \.self) { fret in
              HStack(spacing: 0) {
                Text(fret == 0 ? "0" : "\(fret)")
                  .font(.system(size: 10, weight: .semibold).monospacedDigit())
                  .foregroundStyle(settings.theme.inkMuted)
                  .frame(width: fretLabelW, height: cellH)

                ForEach(0..<stringCount, id: \.self) { s in
                  cell(string: s, fret: fret, dotSize: dotSize)
                    .frame(width: cellW, height: cellH)
                }
              }
            }
          }
        }
        .frame(width: fretLabelW + boardW, height: boardH)
      }
      .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
    }
  }

  @ViewBuilder
  private func cell(string: Int, fret: Int, dotSize: CGFloat) -> some View {
    let key = "\(string):\(fret)"
    if let dot = dots[key] {
      let dim = !Fretboard.inPosition(fret: fret, pos: position)
      Button {
        onTap(dot)
      } label: {
        Text(dot.degree.note)
          .font(.system(size: max(7, dotSize * 0.38), weight: .bold))
          .minimumScaleFactor(0.5)
          .lineLimit(1)
          .foregroundStyle(dot.isTonic ? Color.white : settings.theme.ink)
          .frame(width: dotSize, height: dotSize)
          .background(
            dot.isTonic ? settings.theme.accent : settings.theme.ink.opacity(0.12),
            in: Circle()
          )
          .opacity(dim ? 0.22 : 1)
      }
      .buttonStyle(.plain)
    } else {
      Color.clear
    }
  }
}

#Preview {
  TheoryView()
    .environmentObject(AppSettings())
    .environmentObject(AppSession())
    .padding()
}
