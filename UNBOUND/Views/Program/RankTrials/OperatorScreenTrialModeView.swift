import SwiftUI

struct OperatorScreenTrialReadyPreview: View {
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
                        Text("OPERATOR SCREEN")
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
            .accessibilityIdentifier("operatorScreen.readyLanes")
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                scannerIsLive = true
            }
        }
    }
}

struct OperatorScreenTrialActiveView<CurrentStationCard: View>: View {
    let definition: OverallRankTrialDefinition
    @ObservedObject var session: ActiveWorkoutSession
    let currentStationCard: (Int, ActiveWorkoutSession.ActiveExercise) -> CurrentStationCard

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scannerIsLive = false

    init(
        definition: OverallRankTrialDefinition,
        session: ActiveWorkoutSession,
        @ViewBuilder currentStationCard: @escaping (Int, ActiveWorkoutSession.ActiveExercise) -> CurrentStationCard
    ) {
        self.definition = definition
        self.session = session
        self.currentStationCard = currentStationCard
    }

    var body: some View {
        RankTrialActiveStageLayout(pair: session.rankTrialCurrentExercisePair) {
            activeHeader
        } activeContent: { pair in
            OperatorActiveFocusPanel(
                definition: definition,
                exercise: pair.exercise,
                stationNumber: pair.index + 1,
                totalStations: totalStations,
                progress: progress,
                tint: tint,
                isLive: scannerIsLive && !reduceMotion
            )

            currentStationCard(pair.index, pair.exercise)

            OperatorActiveLaneBoard(
                exercises: session.exercises,
                currentIndex: session.currentExerciseIndex,
                tint: tint
            )
        } completedContent: {
            OperatorScreenCompletePanel(
                definition: definition,
                tint: tint,
                progress: progress
            )
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                scannerIsLive = true
            }
        }
    }

    private var activeHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(definition.format.displayName.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.7)
                    .foregroundStyle(tint)
                Text(currentTitle)
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(loggedStations)/\(totalStations)")
                    .font(Font.unbound.monoM.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                Text("LANES CLEAR")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    private var currentTitle: String {
        guard let pair = session.rankTrialCurrentExercisePair else { return "Screen Complete" }
        return "Lane \(OperatorText.twoDigit(pair.index + 1))"
    }

    private var totalStations: Int {
        session.rankTrialStationCount
    }

    private var loggedStations: Int {
        session.rankTrialLoggedStationCount { $0.hasLoggedRankTrialWorkingSet }
    }

    private var progress: CGFloat {
        session.rankTrialProgress(loggedStations: loggedStations)
    }

    private var tint: Color {
        definition.targetRank.rewardTextTint
    }
}
