import SwiftUI

struct MetroView: View {
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var session: AppSession

  var body: some View {
    MetroBody(engine: session.metronome)
  }
}

private struct MetroBody: View {
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var session: AppSession
  @Environment(\.activeTab) private var activeTab
  let engine: MetronomeEngine

  var body: some View {
    VStack(spacing: 12) {
      BeatStage(engine: engine)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settings.theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

      MetroControls(engine: engine)
        .background(settings.theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
    .onAppear { updateObserving() }
    .onDisappear { engine.uiObserving = false }
    .onChange(of: activeTab) { _, _ in updateObserving() }
  }

  private func updateObserving() {
    let active = activeTab == .metro
    engine.uiObserving = active
    if active { sync() }
  }

  private func sync() {
    engine.apply(
      bpm: Int(session.bpm),
      beatsPerBar: session.beatsPerBar,
      pattern: session.pattern,
      sound: settings.sound,
      muteUpbeats: settings.muteUpbeats,
      accents: session.beatAccents
    )
  }
}

private struct BeatStage: View {
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var session: AppSession
  @ObservedObject var engine: MetronomeEngine

  var body: some View {
    ZStack {
      beatGrid
      playButton
    }
    // Instant cell flash — any implicit animation makes the click feel early.
    .transaction { $0.animation = nil }
  }

  private var beatGrid: some View {
    let weights = session.pattern.cellWeights
    return HStack(spacing: 0) {
      ForEach(0..<session.beatsPerBar, id: \.self) { b in
        let isAccent = session.beatAccents.indices.contains(b) && session.beatAccents[b]
        Button {
          session.toggleAccent(at: b)
        } label: {
          GeometryReader { geo in
            let total = weights.reduce(0, +)
            VStack(spacing: 0) {
              ForEach(weights.indices, id: \.self) { s in
                let on = engine.tick?.beatIndex == b && engine.tick?.subdivIndex == s
                let litAccent = on && (engine.tick?.accent == true)
                let h = total > 0 ? geo.size.height * weights[s] / total : geo.size.height
                Rectangle()
                  .fill(cellFill(on: on, litAccent: litAccent, beatAccent: isAccent))
                  .frame(width: geo.size.width, height: h)
              }
            }
          }
          .overlay(alignment: .top) {
            Capsule()
              .fill(isAccent ? settings.theme.accent : settings.theme.ink.opacity(0.12))
              .frame(width: 18, height: 4)
              .padding(.top, 10)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Beat \(b + 1)")
        .accessibilityValue(isAccent ? "Accent on" : "Accent off")
        .accessibilityHint("Double tap to toggle accent")
      }
    }
  }

  private var playButton: some View {
    Button {
      sync()
      engine.toggle()
    } label: {
      Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
        .font(.system(size: 36, weight: .semibold))
        .foregroundStyle(settings.theme.ink.opacity(0.38))
        .shadow(color: settings.theme.ink.opacity(0.18), radius: 8, y: 4)
        .padding(.leading, engine.isRunning ? 0 : 3)
        .frame(width: 88, height: 88)
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(engine.isRunning ? "Pause" : "Play")
  }

  private func cellFill(on: Bool, litAccent: Bool, beatAccent: Bool) -> Color {
    if on {
      return litAccent
        ? settings.theme.accent.opacity(0.28)
        : settings.theme.ink.opacity(0.12)
    }
    if beatAccent {
      return settings.theme.accent.opacity(0.08)
    }
    return settings.theme.ink.opacity(0.03)
  }

  private func sync() {
    engine.apply(
      bpm: Int(session.bpm),
      beatsPerBar: session.beatsPerBar,
      pattern: session.pattern,
      sound: settings.sound,
      muteUpbeats: settings.muteUpbeats,
      accents: session.beatAccents
    )
  }
}

private struct MetroControls: View {
  @EnvironmentObject private var settings: AppSettings
  @EnvironmentObject private var session: AppSession
  let engine: MetronomeEngine

  var body: some View {
    VStack(spacing: 0) {
      field {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text("Tempo")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(settings.theme.inkMuted)
            .textCase(.uppercase)
          Text("\(Int(session.bpm)) BPM")
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .foregroundStyle(settings.theme.inkMuted)
        }
        HStack(spacing: 10) {
          stepButton("−") {
            session.bpm = max(40, session.bpm - 1)
            syncEngine(resync: true)
          }
          Slider(value: $session.bpm, in: 40...240, step: 1) { editing in
            if editing {
              // Cheap live tempo update — no timeline rebuild while finger moves.
              engine.apply(
                bpm: Int(session.bpm),
                beatsPerBar: session.beatsPerBar,
                pattern: session.pattern,
                sound: settings.sound,
                muteUpbeats: settings.muteUpbeats,
                accents: session.beatAccents
              )
            } else {
              syncEngine(resync: true)
            }
          }
          .tint(settings.theme.accent)
          stepButton("+") {
            session.bpm = min(240, session.bpm + 1)
            syncEngine(resync: true)
          }
        }
      }
      divider
      field {
        label("Meter")
        SegControl(
          options: [(2, "2/4"), (3, "3/4"), (4, "4/4")],
          selection: $session.beatsPerBar
        )
        .onChange(of: session.beatsPerBar) { _, _ in syncEngine(resync: true) }
      }
      divider
      field {
        label("Rhythm")
        VStack(spacing: 6) {
          SegControl(
            options: [MetroPattern.quarter, .eighth, .sixteenth].map { ($0, $0.label) },
            selection: $session.pattern
          )
          SegControl(
            options: [MetroPattern.eighthThen16ths, .sixteenthsThenEighth].map { ($0, $0.label) },
            selection: $session.pattern
          )
        }
        .onChange(of: session.pattern) { _, _ in syncEngine(resync: true) }
      }
      divider
      field {
        HStack {
          label("Mute upbeats")
          Spacer(minLength: 0)
          Toggle("", isOn: $settings.muteUpbeats)
            .labelsHidden()
            .tint(settings.theme.accent)
        }
        .onChange(of: settings.muteUpbeats) { _, _ in syncEngine(resync: false) }
      }
    }
    .onChange(of: settings.sound) { _, _ in syncEngine(resync: false) }
    .onChange(of: session.beatAccents) { _, _ in syncEngine(resync: false) }
  }

  /// - Parameter resync: restart the host timeline (tempo / meter / rhythm). Accents & mute apply live.
  private func syncEngine(resync: Bool) {
    engine.apply(
      bpm: Int(session.bpm),
      beatsPerBar: session.beatsPerBar,
      pattern: session.pattern,
      sound: settings.sound,
      muteUpbeats: settings.muteUpbeats,
      accents: session.beatAccents
    )
    if resync, engine.isRunning { engine.resyncTimeline() }
  }

  private func field<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) { content() }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
  }

  private func label(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 11, weight: .bold))
      .foregroundStyle(settings.theme.inkMuted)
      .textCase(.uppercase)
  }

  private var divider: some View {
    Rectangle()
      .fill(settings.theme.ink.opacity(0.06))
      .frame(height: 1)
      .padding(.horizontal, 16)
  }

  private func stepButton(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(settings.theme.ink)
        .frame(width: 44, height: 44)
        .background(settings.theme.ink.opacity(0.08), in: Circle())
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  MetroView()
    .environmentObject(AppSettings())
    .environmentObject(AppSession())
    .padding()
}
