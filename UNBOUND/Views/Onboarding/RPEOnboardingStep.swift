import SwiftUI

/// Onboarding product-loop demo: log a real set with the production
/// ExerciseLogCard, rate effort, then show how progress moves.
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
        let w = Workout(name: L10n.onboarding("rpeLoop.demoWorkoutName", defaultValue: "Try it"), targetMuscleGroups: [], warmup: [],
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
                Text(L10n.onboarding("rpeLoop.eyebrow", defaultValue: "TRY THE LOOP"))
                    .font(Font.unbound.captionS)
                    .tracking(2)
                    .foregroundStyle(Color.unbound.accent)
                Text(allLogged
                     ? L10n.onboarding("rpeLoop.body.logged", defaultValue: "Progress moved. In the full protocol, every logged set feeds your rank, stats, next unlock, and next session.")
                     : L10n.onboarding("rpeLoop.body.initial", defaultValue: "Tap the checkmark to log a set. Then tap RPE and rate how hard it felt. This is how UNBOUND adapts without making you guess."))
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
                    isCurrent: true,
                    currentSetIndex: demo.currentSetIndex,
                    onToggleExpand: { isExpanded.toggle() },
                    onIntent: { _ in },
                    onEditWeight: { si in editing = EditCell(si: si, isWeight: true) },
                    onEditReps:   { si in editing = EditCell(si: si, isWeight: false) },
                    onPickRPE:    { si in rpeTarget = RPETarget(si: si) },
                    onConfirmAsPlanned: { si in
                        demo.confirmAsPlanned(exerciseIndex: 0, setIndex: si)
                        hasLogged = true
                    },
                    onToggleQualityFlag: { _, _ in },
                    onAddSet: {}
                )
                .padding(.horizontal, 16)
            }

            if hasLogged {
                demoRewardCard
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()

            Button(action: onContinue) {
                Text(L10n.onboarding("rpeLoop.cta", defaultValue: "GOT IT"))
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
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: hasLogged)
        .sheet(item: $editing) { cell in
            OnboardingSetEditor(
                isWeight: cell.isWeight,
                initial: cell.isWeight
                    ? (demo.exercises[0].sets[cell.si].weightKg.map {
                        WeightPlatePolicy.editingValue(fromKilograms: $0)
                    } ?? 0)
                    : Double(demo.exercises[0].sets[cell.si].reps ?? 0),
                onSave: { v in
                    if cell.isWeight {
                        demo.exercises[0].sets[cell.si].weightKg = v > 0
                            ? WeightPlatePolicy.kilograms(fromDisplayValue: v)
                            : nil
                    }
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

    private var demoRewardCard: some View {
        UnboundCard {
            HStack(spacing: 14) {
                ZStack {
                    HUDHexagon()
                        .fill(Color.unbound.accent.opacity(0.16))
                    HUDHexagon()
                        .stroke(Color.unbound.accent.opacity(0.7), lineWidth: 1.4)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.unbound.accent)
                }
                .frame(width: 48, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.onboarding("rpeLoop.reward.title", defaultValue: "+12 XP · POWER +1"))
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(L10n.onboarding("rpeLoop.reward.subtitle", defaultValue: "First unlock progress: 8%"))
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct OnboardingSetEditor: View {
    let isWeight: Bool
    let initial: Double
    let onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var value: Double
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue
    @AppStorage(WeightPlatePolicy.microloadingDefaultsKey) private var microloadingEnabled = false

    init(isWeight: Bool, initial: Double, onSave: @escaping (Double) -> Void) {
        self.isWeight = isWeight; self.initial = initial; self.onSave = onSave
        _value = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 28) {
            StepperControl(label: isWeight ? L10n.onboarding("rpeLoop.editor.weight", defaultValue: "Weight") : L10n.onboarding("rpeLoop.editor.reps", defaultValue: "Reps"), value: $value,
                           step: isWeight ? weightStep : 1,
                           unit: isWeight ? weightUnit.shortLabel : nil,
                           allowsDecimal: isWeight)
            Button { onSave(value); dismiss() } label: {
                Text(L10n.onboarding("rpeLoop.editor.done", defaultValue: "DONE"))
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

    private var weightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    private var weightStep: Double {
        WeightPlatePolicy.loadIncrement(
            unit: weightUnit,
            microloadingEnabled: microloadingEnabled
        )
    }
}
