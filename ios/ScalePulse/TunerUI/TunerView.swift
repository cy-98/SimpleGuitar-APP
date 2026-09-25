import SwiftUI

struct TunerView: View {
  @EnvironmentObject private var settings: AppSettings
  @Environment(\.activeTab) private var activeTab
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var engine = TunerEngine()
  @State private var mode: TuningMode = .standard
  @State private var customTargets = CustomTuningStore.read()

  private var activeTargets: StringTargets {
    mode == .standard ? TunerGeometry.defaultStringTargets() : customTargets
  }

  var body: some View {
    VStack(spacing: 12) {
      topBar
      // Observes `live` only — not the whole engine.
      TunerStatusLine(live: engine.live)
      TunerStage(
        live: engine.live,
        mode: mode,
        targets: activeTargets,
        activeStringId: engine.activeStringId,
        onTapTarget: { midi in
          TonePlayer.shared.playPiano(midi: midi)
        },
        onDragTarget: { id, midi in
          updateCustomTarget(id, midi: midi)
        }
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      if engine.micState == .denied {
        deniedFooter
      }
    }
    .onAppear { syncListening() }
    .onDisappear { engine.stop() }
    .onChange(of: activeTab) { _, _ in syncListening() }
    .onChange(of: scenePhase) { _, _ in syncListening() }
    .onChange(of: mode) { _, _ in syncTargets() }
    .onChange(of: customTargets) { _, _ in syncTargets() }
  }

  private func syncListening() {
    if activeTab == .tuner, scenePhase == .active {
      syncTargets()
      engine.start()
    } else {
      engine.stop()
    }
  }

  private var topBar: some View {
    HStack(alignment: .center, spacing: 10) {
      SegControl(
        options: [
          (TuningMode.standard, "Std"),
          (TuningMode.custom, "Custom"),
        ],
        selection: $mode,
        compact: true
      )
      .frame(width: 138)

      Spacer(minLength: 0)

      if mode == .custom {
        Button {
          resetCustom()
        } label: {
          Text("Reset")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(settings.theme.accent)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(settings.theme.accent.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
      }
    }
    .frame(minHeight: 36)
  }

  private var deniedFooter: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Microphone access is required for tuning. Allow it in Settings.")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(Color(hex: 0xC92A2A))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xFFF5F5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

      Button {
        engine.start()
      } label: {
        Text("Retry")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(Color.white)
          .frame(maxWidth: .infinity, minHeight: 44)
          .background(settings.theme.ink, in: Capsule())
      }
      .buttonStyle(.plain)
    }
  }

  private func syncTargets() {
    engine.setTargets(activeTargets)
  }

  private func updateCustomTarget(_ id: TunerStringId, midi: Int) {
    guard customTargets[id] != midi else { return }
    var next = customTargets
    next[id] = midi
    customTargets = next
    CustomTuningStore.store(next)
  }

  private func resetCustom() {
    let next = TunerGeometry.defaultStringTargets()
    customTargets = next
    CustomTuningStore.store(next)
  }
}

// MARK: - Hz label (throttled text; observes live only)

private struct TunerStatusLine: View {
  @EnvironmentObject private var settings: AppSettings
  @ObservedObject var live: TunerLiveMetrics
  @State private var shownHz: Int = 0

  var body: some View {
    Text("\(shownHz) Hz")
      .font(.system(size: 13, weight: .semibold).monospacedDigit())
      .foregroundStyle(settings.theme.inkMuted)
      .frame(maxWidth: .infinity, alignment: .leading)
      .onChange(of: live.snapshot.freq) { _, freq in
        let hz = Int(max(0, freq).rounded())
        // ~10 Hz text updates — avoids layout thrash at 60 fps.
        if abs(hz - shownHz) >= 1 {
          shownHz = hz
        }
      }
      .onAppear { shownHz = Int(max(0, live.freq).rounded()) }
  }
}

// MARK: - Stage: static chrome + live needle (GuitarTuna layering)

private struct TunerStage: View {
  /// Not ObservedObject here — only the needle overlay subscribes, so chrome stays static.
  let live: TunerLiveMetrics
  let mode: TuningMode
  let targets: StringTargets
  let activeStringId: TunerStringId?
  let onTapTarget: (Int) -> Void
  let onDragTarget: (TunerStringId, Int) -> Void

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      let landscape = w > h

      ZStack {
        // Static layer — rebuilds only when mode / targets / active string change.
        TunerNeckChrome(
          mode: mode,
          targets: targets,
          activeStringId: activeStringId,
          landscape: landscape,
          w: w,
          h: h,
          onTapTarget: onTapTarget,
          onDragTarget: onDragTarget
        )

        // Live layer — only this redraws with pitch.
        TunerNeedleOverlay(
          live: live,
          targets: targets,
          landscape: landscape,
          w: w,
          h: h
        )
        .allowsHitTesting(false)
      }
      .clipped()
      .coordinateSpace(name: TunerNeckChrome.spaceName)
    }
  }
}

/// Live detection needle. Canvas + no animation = no ghost trails.
private struct TunerNeedleOverlay: View {
  @EnvironmentObject private var settings: AppSettings
  @ObservedObject var live: TunerLiveMetrics
  let targets: StringTargets
  let landscape: Bool
  let w: CGFloat
  let h: CGFloat

  private let topPad: CGFloat = 36
  private let bottomPad: CGFloat = 12
  private let leadingPad: CGFloat = 52
  private let trailingPad: CGFloat = 16

  var body: some View {
    let percent = TunerGeometry.detectionXPercent(
      freq: live.hasSignal ? live.freq : 0,
      midi: live.midi,
      targets: targets
    )
    let color = live.hasSignal
      ? (live.inTune ? Color(hex: 0x2F9E44) : settings.theme.ink)
      : settings.theme.ink.opacity(0.45)

    Canvas { ctx, size in
      var path = Path()
      if landscape {
        let y = size.height * percent / 100
        path.move(to: CGPoint(x: leadingPad, y: y))
        path.addLine(to: CGPoint(x: size.width - trailingPad, y: y))
      } else {
        let x = size.width * percent / 100
        path.move(to: CGPoint(x: x, y: topPad))
        path.addLine(to: CGPoint(x: x, y: size.height - bottomPad))
      }
      ctx.stroke(
        path,
        with: .color(color),
        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
      )
    }
    .frame(width: w, height: h)
  }
}

/// String baselines + pills. Does NOT observe live pitch.
private struct TunerNeckChrome: View {
  static let spaceName = "tunerNeck"
  private static let topPad: CGFloat = 36
  private static let bottomPad: CGFloat = 12
  private static let leadingPad: CGFloat = 52
  private static let trailingPad: CGFloat = 16

  private struct LiveDrag: Equatable {
    var id: TunerStringId
    var t: CGFloat
    var midi: Int
  }

  @EnvironmentObject private var settings: AppSettings
  let mode: TuningMode
  let targets: StringTargets
  let activeStringId: TunerStringId?
  let landscape: Bool
  let w: CGFloat
  let h: CGFloat
  let onTapTarget: (Int) -> Void
  let onDragTarget: (TunerStringId, Int) -> Void

  @State private var live: LiveDrag?

  var body: some View {
    ZStack {
      ForEach(Array(TunerLayout.tabColumns.enumerated()), id: \.element) { index, id in
        stringLane(index: index, id: id)
      }
    }
    .frame(width: w, height: h)
    .transaction { txn in
      if live != nil { txn.animation = nil }
    }
  }

  private func lanePercent(index: Int) -> CGFloat {
    TunerGeometry.evenColumnX(index: index)
  }

  private func trackT(id: TunerStringId, targetMidi: Int) -> CGFloat {
    let open = TunerGeometry.defaultOpenMidi(id)
    let y = TunerGeometry.pitchYOnString(
      midi: Double(targetMidi),
      targetMidi: Double(open)
    )
    let nut = TunerLayout.nutYPercent
    let body = TunerLayout.fretBodyYPercent
    return (y - nut) / (body - nut)
  }

  private func displayT(id: TunerStringId, targetMidi: Int) -> CGFloat {
    if let live, live.id == id { return live.t }
    return trackT(id: id, targetMidi: targetMidi)
  }

  private func displayMidi(id: TunerStringId, targetMidi: Int) -> Int {
    if let live, live.id == id { return live.midi }
    return targetMidi
  }

  @ViewBuilder
  private func stringLane(index: Int, id: TunerStringId) -> some View {
    let storedMidi = targets[id] ?? TunerGeometry.defaultOpenMidi(id)
    let targetMidi = displayMidi(id: id, targetMidi: storedMidi)
    let active = activeStringId == id
    let lanePct = lanePercent(index: index)
    let t = displayT(id: id, targetMidi: storedMidi)
    let colW = landscape ? max(52, h / 6.5) : max(44, w / 6.5)

    if landscape {
      let trackW = w - Self.leadingPad - Self.trailingPad
      let laneY = h * lanePct / 100
      let handleX = mode == .custom
        ? Self.leadingPad + trackW * t
        : Self.leadingPad * 0.48

      Path { p in
        p.move(to: CGPoint(x: Self.leadingPad, y: laneY))
        p.addLine(to: CGPoint(x: w - Self.trailingPad, y: laneY))
      }
      .stroke(laneStroke(active: active), style: laneStyle(active: active))
      .allowsHitTesting(false)

      handle(id: id, targetMidi: targetMidi, active: active, maxWidth: colW)
        .position(x: handleX, y: laneY)
        .zIndex(live?.id == id ? 3 : (active ? 2 : 1))
        .gesture(mode == .custom ? customDrag(id: id) : nil)
    } else {
      let trackH = h - Self.topPad - Self.bottomPad
      let laneX = w * lanePct / 100
      let handleY = mode == .custom
        ? Self.topPad + trackH * t
        : Self.topPad * 0.42

      Path { p in
        p.move(to: CGPoint(x: laneX, y: Self.topPad))
        p.addLine(to: CGPoint(x: laneX, y: h - Self.bottomPad))
      }
      .stroke(laneStroke(active: active), style: laneStyle(active: active))
      .allowsHitTesting(false)

      handle(id: id, targetMidi: targetMidi, active: active, maxWidth: colW)
        .position(x: laneX, y: handleY)
        .zIndex(live?.id == id ? 3 : (active ? 2 : 1))
        .gesture(mode == .custom ? customDrag(id: id) : nil)
    }
  }

  @ViewBuilder
  private func handle(
    id: TunerStringId,
    targetMidi: Int,
    active: Bool,
    maxWidth: CGFloat
  ) -> some View {
    let pill = markerLabel(id: id, targetMidi: targetMidi, active: active, maxWidth: maxWidth)
    if mode == .custom {
      pill
    } else {
      pill.onTapGesture { onTapTarget(targetMidi) }
    }
  }

  private func customDrag(id: TunerStringId) -> some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.spaceName))
      .onChanged { value in
        let t: CGFloat
        if landscape {
          let trackW = max(w - Self.leadingPad - Self.trailingPad, 1)
          t = (value.location.x - Self.leadingPad) / trackW
        } else {
          let trackH = max(h - Self.topPad - Self.bottomPad, 1)
          t = (value.location.y - Self.topPad) / trackH
        }
        let clampedT = max(-0.05, min(1.05, t))
        let nut = TunerLayout.nutYPercent
        let body = TunerLayout.fretBodyYPercent
        let mapped = nut + max(0, min(1, clampedT)) * (body - nut)
        let midi = TunerGeometry.targetMidiFromTrackY(id: id, yPercentFromTop: mapped)
        let next = LiveDrag(id: id, t: clampedT, midi: midi)
        if live != next { live = next }
      }
      .onEnded { _ in
        if let live {
          onDragTarget(live.id, live.midi)
        }
        live = nil
      }
  }

  private func markerLabel(
    id: TunerStringId,
    targetMidi: Int,
    active: Bool,
    maxWidth: CGFloat
  ) -> some View {
    let factoryOpen = TunerGeometry.defaultOpenMidi(id)
    let openName = TunerGeometry.tabStringName(id)
    let label = mode == .custom
      ? "\(openName)=\(TunerGeometry.tuningTargetName(targetMidi: targetMidi, referenceMidi: factoryOpen))"
      : openName

    return Text(label)
      .font(.system(size: 15, weight: .heavy).monospacedDigit())
      .foregroundStyle(active ? settings.theme.accent : settings.theme.ink)
      .lineLimit(1)
      .minimumScaleFactor(0.55)
      .padding(.horizontal, mode == .custom ? 6 : 8)
      .padding(.vertical, 5)
      .frame(maxWidth: mode == .custom ? maxWidth : nil)
      .background(
        (active ? settings.theme.accent.opacity(0.14) : settings.theme.ink.opacity(0.06)),
        in: Capsule()
      )
      .padding(.vertical, mode == .custom ? 14 : 0)
      .contentShape(Rectangle())
      .accessibilityLabel(TunerGeometry.tuningPairLabel(id: id, targetMidi: targetMidi))
      .accessibilityHint(mode == .custom ? "Drag along string to change target pitch" : "Play reference tone")
  }

  private func laneStroke(active: Bool) -> Color {
    active ? settings.theme.accent.opacity(0.70) : settings.theme.ink.opacity(0.28)
  }

  private func laneStyle(active: Bool) -> StrokeStyle {
    StrokeStyle(lineWidth: active ? 1.8 : 1.25, lineCap: .round, dash: [5, 4])
  }
}

#Preview {
  TunerView()
    .environmentObject(AppSettings())
    .padding()
}
