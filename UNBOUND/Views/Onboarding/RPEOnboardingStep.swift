import SwiftUI

/// Onboarding "try the app" RPE sandbox: a real 3-set Bench Press logged with
/// the production ExerciseLogCard, teaching the real 6–10 RPE scale via the
/// production RPEPickerSheet.
struct RPEOnboardingStep: View {
    let onContinue: () -> Void

    @StateObject private var demo = RPEOnboardingStep.makeDemo()
    @State private var editing: EditCell?
    @State private var rpeTarget: RPETarget?
    @State private var hasLogged = false
    @State private var isExpanded = false

    private struct EditCell: Identifiable { let id = UUID(); let si: Int; let isWeight: Bool }
    private struct RPETarget: Identifiable { let id = UUID(); let si: Int }

    private static func makeDemo() -> ActiveWorkoutSession {
        let ex = Exercise(id: "demo-bench", name: "Bench Press",
                          muscleGroups: [], sets: 3, reps: "8",
                          restSeconds: 90, rpe: nil, notes: nil, substitution: nil)
        let w = Workout(name: "Try it", targetMuscleGroups: [], warmup: [],
                        mainExercises: [ex], cooldown: [],
                        estimatedMinutes: 0, notes: nil, blockType: nil)
        let s = ActiveWorkoutSession(workout: w, programId: "onboarding-demo", dayNumber: 0)
        for i in s.exercises[0].sets.indices {
            s.exercises[0].sets[i].weightKg = 60
            s.exercises[0].sets[i].reps = 8
        }
        return s
    }

    private var allLogged: Bool { demo.exercises.first?.sets.allSatisfy(\.logged) ?? false }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Text("TRY IT — RPE")
                    .font(Font.unbound.captionS).tracking(2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(allLogged
                     ? "That's RPE — how many reps you had left. 10 = none, 8 = ~2, 6 = 4+. We use it to adjust your weights."
                     : "Log these 3 sets (tap the ✓). Then tap RPE and pick how hard it felt — it's how many reps you had left in the tank.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .animation(.easeInOut(duration: 0.25), value: allLogged)
            }
            .padding(.top, 24)

            if let ex = demo.exercises.first {
                ExerciseLogCard(
                    name: ex.name,
                    plannedSets: ex.sets.count,
                    plannedReps: "8",
                    targetRPE: nil,
                    restSeconds: 90,
                    muscleGroups: [],
                    formCues: nil,
                    substitution: nil,
                    isWarmupCurrent: false,
                    sets: ex.sets,
                    isExpanded: isExpanded,
                    onToggleExpand: { isExpanded.toggle() },
                    onIntent: { _ in },
                    onEditWeight: { si in editing = EditCell(si: si, isWeight: true) },
                    onEditReps:   { si in editing = EditCell(si: si, isWeight: false) },
                    onPickRPE:    { si in rpeTarget = RPETarget(si: si) },
                    onConfirmAsPlanned: { si in
                        demo.confirmAsPlanned(exerciseIndex: 0, setIndex: si)
                        hasLogged = true
                    },
                    onAddSet: {}
                )
                .padding(.horizontal, 16)
            }

            Spacer()

            Button(action: onContinue) {
                Text("GOT IT")
                    .font(Font.unbound.bodyLStrong).tracking(2)
                    .foregroundStyle(Color.unbound.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.unbound.accent))
            }
            .buttonStyle(.plain)
            .opacity(hasLogged ? 1.0 : 0.85)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .sheet(item: $editing) { cell in
            OnboardingSetEditor(
                isWeight: cell.isWeight,
                initial: cell.isWeight
                    ? (demo.exercises[0].sets[cell.si].weightKg ?? 0)
                    : Double(demo.exercises[0].sets[cell.si].reps ?? 0),
                onSave: { v in
                    if cell.isWeight { demo.exercises[0].sets[cell.si].weightKg = v > 0 ? v : nil }
                    else { demo.exercises[0].sets[cell.si].reps = v > 0 ? Int(v) : nil }
                }
            )
            .presentationDetents([.height(260)])
        }
        .sheet(item: $rpeTarget) { t in
            RPEPickerSheet(
                current: demo.exercises[0].sets[t.si].rpe,
                onPick: { v in demo.setRPE(exerciseIndex: 0, setIndex: t.si, v) }
            )
            .presentationDetents([.height(420)])
        }
    }
}

private struct OnboardingSetEditor: View {
    let isWeight: Bool
    let initial: Double
    let onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var value: Double

    init(isWeight: Bool, initial: Double, onSave: @escaping (Double) -> Void) {
        self.isWeight = isWeight; self.initial = initial; self.onSave = onSave
        _value = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 28) {
            StepperControl(label: isWeight ? "Weight" : "Reps", value: $value,
                           step: isWeight ? 2.5 : 1, unit: isWeight ? "kg" : nil,
                           allowsDecimal: isWeight)
            Button { onSave(value); dismiss() } label: {
                Text("DONE")
                    .font(Font.unbound.bodyLStrong).tracking(2)
                    .foregroundStyle(Color.unbound.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.unbound.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(Color.unbound.bg.ignoresSafeArea())
    }
}
