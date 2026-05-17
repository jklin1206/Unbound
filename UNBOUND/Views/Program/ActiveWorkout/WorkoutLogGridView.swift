import SwiftUI

struct WorkoutLogGridView: View {
    @ObservedObject var session: ActiveWorkoutSession
    let onIntent: (Int, OverflowIntent) -> Void
    let onEditWeight: (Int, Int) -> Void
    let onEditReps: (Int, Int) -> Void
    let onLog: (Int, Int) -> Void
    let onPickRPE: (Int, Int) -> Void
    let onAddSet: (Int) -> Void
    let onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(session.exercises.enumerated()), id: \.element.id) { ei, ex in
                    if !ex.skipped {
                        ExerciseLogCard(
                            name: ex.name,
                            isWarmupCurrent: ex.sets.first?.isWarmup ?? false,
                            sets: ex.sets,
                            onIntent: { onIntent(ei, $0) },
                            onEditWeight: { onEditWeight(ei, $0) },
                            onEditReps: { onEditReps(ei, $0) },
                            onLog: { onLog(ei, $0) },
                            onPickRPE: { onPickRPE(ei, $0) },
                            onAddSet: { onAddSet(ei) }
                        )
                    }
                }

                Button(action: onComplete) {
                    Text("COMPLETE SESSION")
                        .font(Font.unbound.bodyLStrong)
                        .tracking(2)
                        .foregroundStyle(Color.unbound.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.unbound.accent))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .padding(16)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }
}
