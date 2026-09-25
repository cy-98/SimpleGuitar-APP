import SwiftUI

struct ChordDictView: View {
  @EnvironmentObject private var settings: AppSettings
  let key: String
  let onPlay: (DiatonicChord) -> Void

  private var chords: [DiatonicChord] { Chords.diatonicTriads(key: key) }

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 0) {
        ForEach(Array(chords.enumerated()), id: \.element.id) { index, chord in
          Button {
            onPlay(chord)
          } label: {
            HStack(spacing: 12) {
              Text(chord.roman)
                .font(.system(size: 16, weight: .bold).monospacedDigit())
                .foregroundStyle(settings.theme.ink)
                .frame(width: 28, alignment: .leading)

              if let diagram = ChordShapes.diagram(for: chord) {
                ChordDiagramView(diagram: diagram)
              }

              Text(chord.symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(settings.theme.ink)

              Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(chord.roman) \(chord.symbol)")
          .accessibilityHint("Play chord")

          if index < chords.count - 1 {
            Rectangle()
              .fill(settings.theme.ink.opacity(0.08))
              .frame(height: 1)
              .padding(.leading, 40)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}
