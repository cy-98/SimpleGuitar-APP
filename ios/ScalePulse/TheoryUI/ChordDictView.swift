import SwiftUI

struct ChordDictView: View {
  @EnvironmentObject private var settings: AppSettings
  let key: String
  let onPlay: (DiatonicChord) -> Void

  private var chords: [DiatonicChord] { Chords.diatonicTriads(key: key) }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Diatonic triads")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(settings.theme.ink.opacity(0.55))
          .textCase(.uppercase)
        Spacer()
        Text("\(key) Major")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(settings.theme.ink.opacity(0.55))
      }
      .padding(.horizontal, 2)
      .padding(.bottom, 4)

      ScrollView(showsIndicators: false) {
        VStack(spacing: 3) {
          ForEach(chords) { chord in
            Button {
              onPlay(chord)
            } label: {
              HStack(spacing: 8) {
                Text(chord.roman)
                  .font(.system(size: 16, weight: .bold).monospacedDigit())
                  .foregroundStyle(settings.theme.ink)
                  .frame(width: 28, alignment: .leading)

                if let diagram = ChordShapes.diagram(for: chord) {
                  ChordDiagramView(diagram: diagram)
                }

                VStack(alignment: .leading, spacing: 1) {
                  HStack(spacing: 5) {
                    Text(chord.symbol)
                      .font(.system(size: 15, weight: .bold))
                      .foregroundStyle(settings.theme.ink)
                    Text(chord.quality.shortLabel)
                      .font(.system(size: 10, weight: .semibold))
                      .foregroundStyle(settings.theme.ink.opacity(0.55))
                      .textCase(.uppercase)
                  }
                  Text(chord.notesLabel)
                    .font(.system(size: 11, weight: .medium).monospaced())
                    .foregroundStyle(settings.theme.ink.opacity(0.55))
                }

                Spacer(minLength: 0)
              }
              .padding(.horizontal, 10)
              .padding(.vertical, 4)
              .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .fill(settings.theme.surface)
                  .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                      .strokeBorder(settings.theme.ink.opacity(0.1), lineWidth: 1)
                  }
              }
              .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(chord.roman) \(chord.symbol)")
            .accessibilityHint("Play chord")
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}
