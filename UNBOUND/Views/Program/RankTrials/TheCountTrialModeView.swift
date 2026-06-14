import SwiftUI

struct TheCountTrialReadyPreview: View {
    let blocks: [TrainingBlock]
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scannerIsLive = false

    private var stations: [OperatorReadyStation] {
        blocks.enumerated().map { index, block in
            OperatorReadyStation(index: index, block: block)
        }
    }

    private var totalSets: Int {
        stations.reduce(0) { $0 + max(1, $1.prescription?.sets ?? 1) }
    }

    private var timedStations: Int {
        stations.filter(\.isTimed).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                OperatorReadinessScanner(
                    stations: stations,
                    tint: tint,
                    isLive: scannerIsLive && !reduceMotion
                )
                .frame(width: 128, height: 184)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("THE COUNT")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.7)
                            .foregroundStyle(tint)
                        Text("Field readiness lanes")
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    HStack(spacing: 8) {
                        OperatorMetricPip(value: "\(stations.count)", label: "LANES", tint: tint)
                        OperatorMetricPip(value: "\(totalSets)", label: "SETS", tint: Color.rewardTeal)
                        OperatorMetricPip(value: "\(timedStations)", label: "TIMED", tint: Color.unbound.coachCyan)
                    }
                }
                .layoutPriority(1)
            }

            OperatorGaugeStrip(stations: stations, tint: tint)

            VStack(spacing: 10) {
                ForEach(stations) { station in
                    OperatorReadyLaneRow(station: station, tint: tint)
                }
            }
            .accessibilityIdentifier("theCount.readyLanes")
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                scannerIsLive = true
            }
        }
    }
}
