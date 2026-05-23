import SwiftUI

struct WorkoutLogGridView: View {
    @ObservedObject var session: ActiveWorkoutSession
    let onIntent: (Int, OverflowIntent) -> Void
    let onEditWeight: (Int, Int) -> Void
    let onEditReps: (Int, Int) -> Void
    let onPickRPE: (Int, Int) -> Void
    let onConfirmAsPlanned: (Int, Int) -> Void
    let onAddSet: (Int) -> Void

    @State private var expanded: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(session.exercises.enumerated()), id: \.element.id) { ei, ex in
                    if !ex.skipped {
                        let isCurrent = ei == session.currentExerciseIndex
                        ExerciseLogCard(
                            name: ex.name,
                            plannedSets: ex.plannedSets,
                            plannedReps: ex.plannedReps,
                            targetRPE: ex.targetRPE,
                            restSeconds: ex.restSeconds,
                            muscleGroups: ex.muscleGroups,
                            formCues: ex.formCues,
                            substitution: ex.substitution,
                            blockKind: ex.blockKind,
                            metricKind: ex.metricKind,
                            tracksHold: ex.tracksHold,
                            isWarmupCurrent: ex.sets.first?.isWarmup ?? false,
                            sets: ex.sets,
                            isExpanded: expanded.contains(ex.id),
                            isCurrent: isCurrent,
                            currentSetIndex: isCurrent ? session.currentSetIndex : nil,
                            onToggleExpand: {
                                if expanded.contains(ex.id) { expanded.remove(ex.id) }
                                else { expanded.insert(ex.id) }
                            },
                            onIntent: { onIntent(ei, $0) },
                            onEditWeight: { onEditWeight(ei, $0) },
                            onEditReps: { onEditReps(ei, $0) },
                            onPickRPE: { onPickRPE(ei, $0) },
                            onConfirmAsPlanned: { onConfirmAsPlanned(ei, $0) },
                            onAddSet: { onAddSet(ei) }
                        )
                    }
                }

                Spacer().frame(height: 190)
            }
            .padding(16)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }
}
