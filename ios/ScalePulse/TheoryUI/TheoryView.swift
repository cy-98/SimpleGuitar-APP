import SwiftUI

struct TheoryView: View {
  @EnvironmentObject private var settings: AppSettings
  @State private var key = "C"
  @State private var showSolfege = false
  @State private var viewMode = "chart"
  @State private var positionId = "all"

  private var position: FretPosition { Fretboard.getPosition(positionId) }
  private var dots: [FretDot] { Fretboard.scaleDots(key: key) }

  var body: some View {
    VStack(spacing: 8) {
      HStack {
        Text("\(key) 大调")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(settings.theme.ink)
        Spacer()
        HStack(spacing: 8) {
          Text("唱名")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(settings.theme.inkMuted)
            .textCase(.uppercase)
          Toggle("", isOn: $showSolfege)
            .labelsHidden()
            .tint(settings.theme.accent)
        }
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(Scales.majorKeys, id: \.self) { k in
            Button {
              key = k
              TonePlayer.shared.playSung(note: k)
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

      Group {
        if viewMode == "chart" {
          NoteChartView(key: key, showSolfege: showSolfege) { note in
            TonePlayer.shared.playSung(note: note)
          }
        } else {
          fretboard
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(settings.theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

      if viewMode == "fretboard" {
        SegControl(
          options: Fretboard.positions.map { ($0.id, $0.label) },
          selection: $positionId
        )
      }

      SegControl(
        options: [("chart", "环图"), ("fretboard", "指板")],
        selection: $viewMode
      )
    }
  }

  private var fretboard: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(0..<6, id: \.self) { s in
          HStack(spacing: 0) {
            Text(Fretboard.stringLabels[s])
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(settings.theme.inkMuted)
              .frame(width: 22)
            ForEach(Fretboard.fretMin...Fretboard.fretMax, id: \.self) { fret in
              let dot = dots.first { $0.string == s && $0.fret == fret }
              ZStack {
                if fret == 0 {
                  Rectangle()
                    .fill(settings.theme.ink.opacity(0.25))
                    .frame(width: 2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                if let dot {
                  let dim = !Fretboard.inPosition(fret: fret, pos: position)
                  Button {
                    TonePlayer.shared.playSung(midi: dot.midi)
                    if dot.isTonic && Scales.isMajorKey(dot.degree.note) {
                      key = dot.degree.note
                    }
                  } label: {
                    Text(showSolfege ? dot.degree.solfege : dot.degree.note)
                      .font(.system(size: 8, weight: .bold))
                      .foregroundStyle(dot.isTonic ? Color.white : settings.theme.ink)
                      .frame(width: 22, height: 22)
                      .background(
                        dot.isTonic ? settings.theme.accent : settings.theme.ink.opacity(0.1),
                        in: Circle()
                      )
                      .opacity(dim ? 0.22 : 1)
                  }
                  .buttonStyle(.plain)
                }
              }
              .frame(width: 28, height: 36)
            }
          }
        }
      }
    }
  }
}
