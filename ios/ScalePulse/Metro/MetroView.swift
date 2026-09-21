import SwiftUI

struct MetroView: View {
  @EnvironmentObject private var settings: AppSettings
  @StateObject private var engine = MetronomeEngine()
  @State private var bpm: Double = 100
  @State private var beatsPerBar = 4
  @State private var subdivision = 1

  var body: some View {
    VStack(spacing: 12) {
      Button {
        syncEngine()
        engine.toggle()
      } label: {
        ZStack {
          beatGrid
          Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
            .font(.system(size: 36, weight: .semibold))
            .foregroundStyle(settings.theme.ink.opacity(0.38))
            .shadow(color: settings.theme.ink.opacity(0.18), radius: 8, y: 4)
            .padding(.leading, engine.isRunning ? 0 : 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settings.theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
      }
      .buttonStyle(.plain)

      VStack(spacing: 0) {
        field {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("速度")
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(settings.theme.inkMuted)
              .textCase(.uppercase)
            Text("\(Int(bpm)) BPM")
              .font(.system(size: 13, weight: .semibold).monospacedDigit())
              .foregroundStyle(settings.theme.inkMuted)
          }
          HStack(spacing: 10) {
            stepButton("−") { bpm = max(40, bpm - 1) }
            Slider(value: $bpm, in: 40...240, step: 1)
              .tint(settings.theme.accent)
              .onChange(of: bpm) { _, _ in syncEngine() }
            stepButton("+") { bpm = min(240, bpm + 1) }
          }
        }
        divider
        field {
          label("拍号")
          SegControl(
            options: [(2, "2/4"), (3, "3/4"), (4, "4/4")],
            selection: $beatsPerBar
          )
          .onChange(of: beatsPerBar) { _, _ in syncEngine() }
        }
        divider
        field {
          label("细分")
          SegControl(
            options: [(1, "四分"), (2, "八分"), (4, "十六分")],
            selection: $subdivision
          )
          .onChange(of: subdivision) { _, _ in syncEngine() }
        }
      }
      .background(settings.theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
    .onAppear(perform: syncEngine)
    .onChange(of: settings.sound) { _, _ in syncEngine() }
    .onChange(of: settings.muteUpbeats) { _, _ in syncEngine() }
    .onDisappear { engine.stop() }
  }

  private var beatGrid: some View {
    HStack(spacing: 0) {
      ForEach(0..<beatsPerBar, id: \.self) { b in
        VStack(spacing: 0) {
          ForEach(0..<subdivision, id: \.self) { s in
            let on = engine.tick?.beatIndex == b && engine.tick?.subdivIndex == s
            let accent = on && (engine.tick?.accent == true)
            Rectangle()
              .fill(
                on
                  ? (accent ? settings.theme.accent.opacity(0.2) : settings.theme.ink.opacity(0.1))
                  : settings.theme.ink.opacity(0.03)
              )
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
  }

  private func syncEngine() {
    engine.bpm = Int(bpm)
    engine.beatsPerBar = beatsPerBar
    engine.subdivision = subdivision
    engine.sound = settings.sound
    engine.muteUpbeats = settings.muteUpbeats
  }

  private func field<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      content()
    }
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
        .background(settings.theme.canvas, in: Circle())
    }
    .buttonStyle(.plain)
  }
}

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
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(selection == value ? Color.white : settings.theme.inkMuted)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(
              selection == value ? settings.theme.ink : settings.theme.canvas,
              in: Capsule()
            )
        }
        .buttonStyle(.plain)
      }
    }
  }
}
