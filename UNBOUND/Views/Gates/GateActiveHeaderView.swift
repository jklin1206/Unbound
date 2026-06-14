import SwiftUI

/// World-stage header (spec §6.4): banner top ~28% bleeding into true black,
/// holding trial name, station N/M, and the living-world visualizer. Sits above
/// the calm logging surface.
struct GateActiveHeaderView: View {
    let world: GateWorld
    let stationIndex: Int       // 0-based current
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(world.stageAssetName).resizable().scaledToFill()
                .frame(height: 240).clipped()
                .overlay(LinearGradient(colors: [.clear, .clear, Color.unbound.bg],
                    startPoint: .top, endPoint: .bottom))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(world.trialName.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy)).tracking(2)
                        .foregroundStyle(world.tint)
                    Spacer(minLength: 0)
                    Text("STATION \(stationIndex + 1)/\(stationCount)")
                        .font(Font.unbound.monoS.weight(.bold)).foregroundStyle(Color.unbound.textSecondary)
                }
                Text(currentStationTitle).font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                DefaultGateVisualizer(world: world, stationsCleared: stationsCleared, stationCount: stationCount)
            }
            .padding(16)
        }
        .frame(height: 240)
        .accessibilityIdentifier("gate-active-header")
    }
}
