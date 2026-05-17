import SwiftUI

struct ExerciseLogCard: View {
    let name: String
    let isWarmupCurrent: Bool
    let sets: [ActiveWorkoutSession.ActiveSet]
    let onIntent: (OverflowIntent) -> Void
    let onEditWeight: (Int) -> Void
    let onEditReps: (Int) -> Void
    let onLog: (Int) -> Void
    let onPickRPE: (Int) -> Void
    let onAddSet: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer()
                ExerciseOverflowMenu(isWarmup: isWarmupCurrent, onIntent: onIntent)
            }
            .padding(.bottom, 4)

            HStack(spacing: 8) {
                Text("SET").frame(width: 20, alignment: .leading)
                Text("WEIGHT").frame(maxWidth: .infinity)
                Text("REPS").frame(maxWidth: .infinity)
                Text("RPE").frame(width: 44)
                Spacer().frame(width: 40)        // ✓ column, unlabeled
            }
            .font(Font.unbound.captionS)
            .tracking(1.2)
            .foregroundStyle(Color.unbound.textTertiary)

            ForEach(Array(sets.enumerated()), id: \.element.id) { idx, set in
                SetLogGridRow(
                    setNumber: idx + 1,
                    weightKg: set.weightKg,
                    reps: set.reps,
                    rpe: set.rpe,
                    logged: set.logged,
                    onEditWeight: { onEditWeight(idx) },
                    onEditReps: { onEditReps(idx) },
                    onPickRPE: { onPickRPE(idx) },
                    onLog: { onLog(idx) }
                )
                if idx < sets.count - 1 {
                    Divider().overlay(Color.unbound.borderSubtle)
                }
            }

            Button(action: onAddSet) {
                Label("Add set", systemImage: "plus")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .padding(.top, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.unbound.surface))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.unbound.border, lineWidth: 1))
    }
}
