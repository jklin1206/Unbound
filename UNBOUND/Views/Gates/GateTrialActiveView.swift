import SwiftUI

/// The unified in-trial active view (spec §6.4): the gate's bespoke living world as a
/// header that reacts to logged stations, sitting above the one calm logging surface.
/// This is the live-cutover replacement for the per-format rank-trial mode views — every
/// gate routes through `GateWorldStageView`, driven by the same `ActiveWorkoutSession`
/// station progress, and the real `ExerciseLogCard` stays the single logging spine.
struct GateTrialActiveView<CurrentStationCard: View>: View {
    let definition: OverallRankTrialDefinition
    @ObservedObject var session: ActiveWorkoutSession
    let currentStationCard: (Int, ActiveWorkoutSession.ActiveExercise) -> CurrentStationCard

    init(
        definition: OverallRankTrialDefinition,
        session: ActiveWorkoutSession,
        @ViewBuilder currentStationCard: @escaping (Int, ActiveWorkoutSession.ActiveExercise) -> CurrentStationCard
    ) {
        self.definition = definition
        self.session = session
        self.currentStationCard = currentStationCard
    }

    private var world: GateWorld { GateWorldCatalog.world(for: definition.format) }
    private var stationCount: Int { session.rankTrialStationCount }
    private var stationsCleared: Int {
        session.rankTrialLoggedStationCount { $0.hasLoggedRankTrialWorkingSet }
    }

    var body: some View {
        RankTrialActiveStageLayout(pair: session.rankTrialCurrentExercisePair) {
            EmptyView()
        } activeContent: { pair in
            GateWorldStageView(
                world: world,
                stationIndex: pair.index,
                stationCount: stationCount,
                stationsCleared: stationsCleared,
                currentStationTitle: pair.exercise.name
            )
            currentStationCard(pair.index, pair.exercise)
        } completedContent: {
            GateWorldStageView(
                world: world,
                stationIndex: max(stationCount - 1, 0),
                stationCount: stationCount,
                stationsCleared: stationCount,
                currentStationTitle: world.trialName
            )
        }
    }
}
