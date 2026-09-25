import SwiftUI

struct TheoryView: View {
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var session: AppSession
  @State private var fretShakeY: CGFloat = 0

  var body: some View {
    VStack(spacing: 12) {
      HStack(alignment: .center) {
        Text("\(session.theoryKey) Major")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(settings.theme.ink)
        Spacer()
        Button {
          shakeFretboardThenOpen()
        } label: {
          Image(systemName: "guitars")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(settings.theme.ink)
            .frame(width: 40, height: 40)
            .background(settings.theme.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .offset(y: fretShakeY)
        .accessibilityLabel("Open fretboard")
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(Scales.majorKeys, id: \.self) { k in
            Button {
              var t = Transaction()
              t.disablesAnimations = true
              withTransaction(t) {
                session.theoryKey = k
              }
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

      ZStack {
        if session.theoryPane == .ring {
          ZStack(alignment: .bottomTrailing) {
            NoteChartView(
              key: session.theoryKey,
              showNoteLetters: session.showNoteLetters
            ) { note in
              TonePlayer.shared.playPiano(note: note)
            }

            HStack(spacing: 8) {
              Text("Letters")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(settings.theme.ink)
              Toggle("Letters", isOn: $session.showNoteLetters)
                .labelsHidden()
                .tint(settings.theme.accent)
                .fixedSize()
            }
            .padding(.trailing, 10)
            .padding(.bottom, 8)
            .accessibilityElement(children: .combine)
          }
          .transition(.identity)
        }

        if session.theoryPane == .chords {
          ChordDictView(key: session.theoryKey) { chord in
            TonePlayer.shared.playChord(notes: chord.notes)
          }
          .transition(.identity)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      // Keep pane swap instant so SegControl spring doesn't crossfade both panes.
      .transaction { $0.animation = nil }

      SegControl(
        options: [(.ring, "Ring"), (.chords, "Chords")],
        selection: $session.theoryPane
      )
    }
    .fullScreenCover(isPresented: $session.fretboardFullscreen) {
      FretboardFullscreenView(
        key: session.theoryKey,
        positionId: $session.positionId,
        showNoteLetters: session.showNoteLetters,
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

  private func shakeFretboardThenOpen() {
    Task { @MainActor in
      withAnimation(.easeOut(duration: 0.07)) { fretShakeY = 7 }
      try? await Task.sleep(nanoseconds: 70_000_000)
      withAnimation(.easeInOut(duration: 0.08)) { fretShakeY = 0 }
      try? await Task.sleep(nanoseconds: 70_000_000)
      withAnimation(.easeOut(duration: 0.07)) { fretShakeY = 5 }
      try? await Task.sleep(nanoseconds: 70_000_000)
      withAnimation(.easeInOut(duration: 0.09)) { fretShakeY = 0 }
      try? await Task.sleep(nanoseconds: 50_000_000)
      session.fretboardFullscreen = true
    }
  }

  private func handleDot(_ dot: FretDot) {
    TonePlayer.shared.playPiano(midi: dot.midi)
    if dot.isTonic && Scales.isMajorKey(dot.degree.note) {
      session.theoryKey = dot.degree.note
    }
  }
}

private struct FretboardFullscreenView: View {
  @EnvironmentObject private var settings: AppSettings
  let key: String
  @Binding var positionId: String
  let showNoteLetters: Bool
  let onClose: () -> Void
  let onTap: (FretDot) -> Void
  let onSelectKey: (String) -> Void

  private var position: FretPosition { Fretboard.getPosition(positionId) }
  private var dotMap: [String: FretDot] {
    let dots = Fretboard.scaleDots(key: key)
    return Dictionary(uniqueKeysWithValues: dots.map { ($0.id, $0) })
  }

  var body: some View {
    GeometryReader { geo in
      let landscape = geo.size.width > geo.size.height

      ZStack {
        settings.theme.canvas.ignoresSafeArea()

        VStack(spacing: landscape ? 8 : 12) {
          HStack {
            Text("\(key) Major")
              .font(.system(size: landscape ? 18 : 20, weight: .bold))
              .foregroundStyle(settings.theme.ink)
            Spacer()
            Button("Close", action: onClose)
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(settings.theme.accent)
          }

          if !landscape {
            keyChips
          }

          FretboardView(
            dots: dotMap,
            position: position,
            showNoteLetters: showNoteLetters,
            onTap: onTap
          )
          .padding(landscape ? 8 : 12)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(settings.theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

          if landscape {
            HStack(spacing: 8) {
              keyChips
              SegControl(
                options: Fretboard.landscapePositions.map { ($0.id, $0.label) },
                selection: $positionId,
                compact: true
              )
              .frame(maxWidth: 340)
            }
          } else {
            SegControl(
              options: Fretboard.portraitPositions.map { ($0.id, $0.label) },
              selection: $positionId
            )
            .onAppear {
              if positionId == "all" { positionId = "open" }
            }
          }
        }
        .padding(landscape ? 12 : 16)
      }
    }
  }

  private var keyChips: some View {
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
  }
}

/// Nut left, frets → right. Portrait: page-snap scroll + minimap. Landscape: show all frets.
private struct FretboardView: View {
  @EnvironmentObject private var settings: AppSettings
  let dots: [String: FretDot]
  let position: FretPosition
  let showNoteLetters: Bool
  let onTap: (FretDot) -> Void

  private let stringLabelW: CGFloat = 22
  private let fretHeaderH: CGFloat = 20
  private let frets = Array(Fretboard.fretMin...Fretboard.fretMax)
  private let stringCount = 6
  /// Portrait: how many frets fit in one snap page.
  private let portraitVisibleCount = 5

  /// Leading fret of the portrait viewport (page-aligned).
  @State private var leadingFret: Int = 0

  private var maxLeadingFret: Int {
    max(0, frets.count - portraitVisibleCount)
  }

  /// One page per valid leading fret (0…maxLeading).
  private var pageLeads: [Int] {
    Array(0...maxLeadingFret)
  }

  var body: some View {
    GeometryReader { geo in
      let landscape = geo.size.width > geo.size.height
      Group {
        if landscape {
          fittedBoard(in: geo.size)
        } else {
          scrollableBoard(in: geo.size)
        }
      }
      .onAppear { jumpToPosition(animated: false) }
      .onChange(of: position.id) { _, _ in
        jumpToPosition(animated: true)
      }
    }
  }

  private func leadingFret(for position: FretPosition) -> Int {
    // Align the portrait page so the position window fills the 5-fret viewport.
    // e.g. 0–4 → lead 0; 9–12 → lead 8 (shows 8…12, covering 9–12).
    let ideal = position.fretTo - portraitVisibleCount + 1
    let preferred = min(position.fretFrom, max(0, ideal))
    return max(0, min(maxLeadingFret, preferred))
  }

  private func jumpToPosition(animated: Bool) {
    let target = leadingFret(for: position)
    guard target != leadingFret else { return }
    if animated {
      withAnimation(.easeOut(duration: 0.22)) {
        leadingFret = target
      }
    } else {
      leadingFret = target
    }
  }

  private func fittedBoard(in size: CGSize) -> some View {
    let boardW = max(0, size.width - stringLabelW)
    let boardH = max(0, size.height - fretHeaderH)
    let cellW = boardW / CGFloat(frets.count)
    let cellH = boardH / CGFloat(stringCount)
    let dotSize = min(cellW, cellH) * 0.78
    return boardGrid(cellW: cellW, cellH: cellH, dotSize: dotSize, includeStringLabels: true)
      .frame(width: size.width, height: size.height, alignment: .center)
  }

  private func scrollableBoard(in size: CGSize) -> some View {
    let minimapH: CGFloat = 48
    let gap: CGFloat = 10
    let mainH = max(0, size.height - minimapH - gap)
    let boardH = max(0, mainH - fretHeaderH)
    let cellH = boardH / CGFloat(stringCount)
    let boardViewportW = max(0, size.width - stringLabelW)
    let cellW = boardViewportW / CGFloat(portraitVisibleCount)
    let dotSize = min(cellW, cellH) * 0.78

    return VStack(spacing: gap) {
      HStack(spacing: 0) {
        // Sticky string labels
        VStack(spacing: 0) {
          Color.clear.frame(width: stringLabelW, height: fretHeaderH)
          ForEach(0..<stringCount, id: \.self) { s in
            Text(Fretboard.stringLabels[s])
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(settings.theme.inkMuted)
              .frame(width: stringLabelW, height: cellH)
          }
        }

        // Page-snap: each page is exactly `portraitVisibleCount` frets wide.
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(spacing: 0) {
            ForEach(pageLeads, id: \.self) { lead in
              HStack(spacing: 0) {
                ForEach(0..<portraitVisibleCount, id: \.self) { offset in
                  let fret = lead + offset
                  fretColumn(fret: fret, cellW: cellW, cellH: cellH, dotSize: dotSize)
                }
              }
              .frame(width: boardViewportW, height: mainH, alignment: .topLeading)
              .id(lead)
            }
          }
          .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: Binding(
          get: { Optional(leadingFret) },
          set: { newValue in
            if let newValue {
              leadingFret = max(0, min(maxLeadingFret, newValue))
            }
          }
        ))
      }
      .frame(height: mainH)

      FretMinimap(
        dots: dots,
        position: position,
        frets: frets,
        stringCount: stringCount,
        leadingFret: leadingFret,
        visibleCount: portraitVisibleCount,
        onSeekLeading: { fret in
          let clamped = max(0, min(maxLeadingFret, fret))
          withAnimation(.easeOut(duration: 0.18)) {
            leadingFret = clamped
          }
        }
      )
      .frame(height: minimapH)
    }
    .frame(width: size.width, height: size.height)
  }

  /// One fret as a column (header + 6 strings).
  private func fretColumn(fret: Int, cellW: CGFloat, cellH: CGFloat, dotSize: CGFloat) -> some View {
    VStack(spacing: 0) {
      Text(fret == 0 ? "" : "\(fret)")
        .font(.system(size: 10, weight: .semibold).monospacedDigit())
        .foregroundStyle(settings.theme.inkMuted)
        .opacity(0.55)
        .frame(width: cellW, height: fretHeaderH)

      ZStack(alignment: .leading) {
        ForEach(0..<stringCount, id: \.self) { s in
          let y = cellH * (CGFloat(s) + 0.5)
          Path { p in
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: cellW, y: y))
          }
          .stroke(settings.theme.ink.opacity(0.28), lineWidth: 1)
        }

        Path { p in
          p.move(to: CGPoint(x: 0, y: 0))
          p.addLine(to: CGPoint(x: 0, y: cellH * CGFloat(stringCount)))
        }
        .stroke(
          settings.theme.ink.opacity(fret == 0 ? 0.5 : 0.12),
          lineWidth: fret == 0 ? 3 : 1
        )

        VStack(spacing: 0) {
          ForEach(0..<stringCount, id: \.self) { s in
            cell(string: s, fret: fret, dotSize: dotSize)
              .frame(width: cellW, height: cellH)
          }
        }
      }
      .frame(width: cellW, height: cellH * CGFloat(stringCount))
    }
    .frame(width: cellW)
  }

  @ViewBuilder
  private func boardGrid(
    cellW: CGFloat,
    cellH: CGFloat,
    dotSize: CGFloat,
    includeStringLabels: Bool
  ) -> some View {
    let boardW = cellW * CGFloat(frets.count)
    let boardH = cellH * CGFloat(stringCount)
    let labelW: CGFloat = includeStringLabels ? stringLabelW : 0

    VStack(spacing: 0) {
      HStack(spacing: 0) {
        if includeStringLabels {
          Color.clear.frame(width: stringLabelW, height: fretHeaderH)
        }
        ForEach(frets, id: \.self) { fret in
          Text(fret == 0 ? "" : "\(fret)")
            .font(.system(size: 10, weight: .semibold).monospacedDigit())
            .foregroundStyle(settings.theme.inkMuted)
            .opacity(0.55)
            .frame(width: cellW, height: fretHeaderH)
        }
      }

      ZStack(alignment: .topLeading) {
        ForEach(0..<stringCount, id: \.self) { s in
          let y = cellH * (CGFloat(s) + 0.5)
          Path { p in
            p.move(to: CGPoint(x: labelW, y: y))
            p.addLine(to: CGPoint(x: labelW + boardW, y: y))
          }
          .stroke(settings.theme.ink.opacity(0.28), lineWidth: 1)
        }

        ForEach(frets, id: \.self) { fret in
          let x = labelW + cellW * CGFloat(fret)
          Path { p in
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: boardH))
          }
          .stroke(
            settings.theme.ink.opacity(fret == 0 ? 0.5 : 0.12),
            lineWidth: fret == 0 ? 3 : 1
          )
        }

        VStack(spacing: 0) {
          ForEach(0..<stringCount, id: \.self) { s in
            HStack(spacing: 0) {
              if includeStringLabels {
                Text(Fretboard.stringLabels[s])
                  .font(.system(size: 11, weight: .bold))
                  .foregroundStyle(settings.theme.inkMuted)
                  .frame(width: stringLabelW, height: cellH)
              }
              ForEach(frets, id: \.self) { fret in
                cell(string: s, fret: fret, dotSize: dotSize)
                  .frame(width: cellW, height: cellH)
              }
            }
          }
        }
      }
      .frame(width: labelW + boardW, height: boardH)
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
        Text(showNoteLetters ? dot.degree.note : "\(dot.degree.degree)")
          .font(.system(size: max(7, dotSize * 0.42), weight: .bold, design: .monospaced))
          .minimumScaleFactor(0.5)
          .lineLimit(1)
          .foregroundStyle(dot.isTonic ? Color.white : settings.theme.ink)
          .frame(width: dotSize, height: dotSize)
          .background(
            dot.isTonic ? settings.theme.accent : settings.theme.ink.opacity(0.12),
            in: Circle()
          )
          .shadow(
            color: dot.isTonic
              ? settings.theme.accent.opacity(0.35)
              : settings.theme.ink.opacity(0.08),
            radius: dot.isTonic ? 4 : 2,
            y: 1
          )
          .opacity(dim ? 0.22 : 1)
      }
      .buttonStyle(.plain)
    } else {
      Color.clear
    }
  }
}

/// Thumbnail of the whole neck; window tracks leading fret; drag snaps to frets.
private struct FretMinimap: View {
  @EnvironmentObject private var settings: AppSettings
  let dots: [String: FretDot]
  let position: FretPosition
  let frets: [Int]
  let stringCount: Int
  let leadingFret: Int
  let visibleCount: Int
  let onSeekLeading: (Int) -> Void

  private var maxLeading: Int {
    max(0, frets.count - visibleCount)
  }

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      let cellW = w / CGFloat(max(frets.count, 1))
      let cellH = h / CGFloat(max(stringCount, 1))
      let visibleFraction = CGFloat(visibleCount) / CGFloat(max(frets.count, 1))
      let windowW = max(20, w * visibleFraction)
      let travel = max(w - windowW, 1)
      let lead = max(0, min(maxLeading, leadingFret))
      let windowX = maxLeading > 0
        ? CGFloat(lead) / CGFloat(maxLeading) * travel
        : 0

      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(settings.theme.ink.opacity(0.05))
          .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .strokeBorder(settings.theme.ink.opacity(0.08), lineWidth: 1)
          }

        ForEach(0..<stringCount, id: \.self) { s in
          ForEach(frets, id: \.self) { fret in
            let key = "\(s):\(fret)"
            if let dot = dots[key] {
              let dim = !Fretboard.inPosition(fret: fret, pos: position)
              Circle()
                .fill(dot.isTonic ? settings.theme.accent : settings.theme.ink.opacity(0.32))
                .frame(width: min(cellW, cellH) * 0.42, height: min(cellW, cellH) * 0.42)
                .opacity(dim ? 0.18 : 1)
                .position(
                  x: cellW * (CGFloat(fret) + 0.5),
                  y: cellH * (CGFloat(s) + 0.5)
                )
            }
          }
        }

        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(settings.theme.accent.opacity(0.14))
          .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .strokeBorder(settings.theme.accent, lineWidth: 2)
          }
          .frame(width: windowW, height: h - 4)
          .offset(x: windowX, y: 2)
          .animation(.easeOut(duration: 0.12), value: leadingFret)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let x = value.location.x - windowW / 2
            let frac = max(0, min(1, x / travel))
            let fret = Int((frac * CGFloat(maxLeading)).rounded())
            onSeekLeading(fret)
          }
      )
      .accessibilityLabel("Fretboard overview")
      .accessibilityHint("Drag to jump to a fret position")
    }
  }
}

#Preview {
  TheoryView()
    .environmentObject(AppSettings())
    .environmentObject(AppSession())
    .padding()
}
