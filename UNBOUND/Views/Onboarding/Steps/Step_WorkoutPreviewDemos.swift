import SwiftUI
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

struct Step_AppPainSolution: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    private var rows: [(problem: String, fix: String, icon: String)] {
        [
            (
                L10n.onboarding("appPainSolution.problem.today", defaultValue: "You do not know what to train today."),
                L10n.onboarding("appPainSolution.fix.today", defaultValue: "UNBOUND gives you one daily mission."),
                "target"
            ),
            (
                L10n.onboarding("appPainSolution.problem.progress", defaultValue: "Progress feels invisible."),
                L10n.onboarding("appPainSolution.fix.progress", defaultValue: "Every log moves rank, stats, and gate readiness."),
                "chart.line.uptrend.xyaxis"
            ),
            (
                L10n.onboarding("appPainSolution.problem.life", defaultValue: "Life breaks generic plans."),
                L10n.onboarding("appPainSolution.fix.life", defaultValue: "Your plan adapts to recovery, schedule, and equipment."),
                "arrow.triangle.2.circlepath"
            ),
            (
                L10n.onboarding("appPainSolution.problem.plateau", defaultValue: "There is no clear standard to chase."),
                L10n.onboarding("appPainSolution.fix.plateau", defaultValue: "Rank gates tell you exactly what unlocks the next climb."),
                "flag.checkered"
            )
        ]
    }

    var body: some View {
        OnboardingScaffold(
            title: L10n.onboarding("appPainSolution.title", defaultValue: "Now the app solves the loop."),
            subtitle: L10n.onboarding("appPainSolution.subtitle", defaultValue: "Your scan gives the starting point. The daily loop turns it into action."),
            progress: progress,
            primaryTitle: L10n.onboarding("appPainSolution.primary", defaultValue: "Show today's mission"),
            primaryIcon: "arrow.right",
            hudStep: .appPainSolution,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    problemFixRow(index: index + 1, problem: row.problem, fix: row.fix, icon: row.icon)
                }
            }
        }
    }

    private func problemFixRow(index: Int, problem: String, fix: String, icon: String) -> some View {
        UnboundCard(cornerRadius: 12, padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.unbound.accent.opacity(0.12))
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.unbound.accent)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 7) {
                    Text(problem)
                        .font(Font.unbound.bodyM.weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.unbound.accent)
                            .padding(.top, 1)
                        Text(fix)
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }
}

struct Step_WorkoutPreviewDemo: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    private var missionTitle: String {
        if let firstArea = flow.targetAreas.first {
            return "\(firstArea.displayName) Rank Mission"
        }
        return "Rank Mission"
    }

    var body: some View {
        OnboardingScaffold(
            title: L10n.onboarding("workoutPreviewDemo.title", defaultValue: "This is what you open each day."),
            subtitle: L10n.onboarding("workoutPreviewDemo.subtitle", defaultValue: "No library digging. No guessing. Just the next mission built from your scan."),
            progress: progress,
            primaryTitle: L10n.onboarding("workoutPreviewDemo.primary", defaultValue: "Log the workout"),
            primaryIcon: "arrow.right",
            hudStep: .workoutPreviewDemo,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 14) {
                UnboundCard(cornerRadius: 12, padding: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.onboarding("workoutPreviewDemo.card.eyebrow", defaultValue: "TODAY'S MISSION"))
                                    .font(Font.unbound.captionS)
                                    .tracking(1.4)
                                    .foregroundStyle(Color.unbound.ember)
                                Text(missionTitle)
                                    .font(Font.unbound.titleM)
                                    .foregroundStyle(Color.unbound.textPrimary)
                            }
                            Spacer()
                            Text("28 MIN")
                                .font(Font.unbound.monoS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.unbound.bg.opacity(0.7)))
                        }

                        VStack(spacing: 10) {
                            missionRow(index: 1, title: "Prime", detail: "Mobility + activation", value: "4 min")
                            missionRow(index: 2, title: "Main Work", detail: "Push / squat progression", value: "3 sets")
                            missionRow(index: 3, title: "Skill Gate", detail: "Core control standard", value: "2 sets")
                            missionRow(index: 4, title: "Recovery", detail: "Breathing + readiness check", value: "2 min")
                        }
                    }
                }

                UnboundCard(cornerRadius: 12, padding: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.unbound.accent)
                        Text(L10n.onboarding("workoutPreviewDemo.note", defaultValue: "After you log it, UNBOUND updates your next target."))
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                }
            }
        }
    }

    private func missionRow(index: Int, title: String, detail: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index))
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.accent)
                .frame(width: 28, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.unbound.bodyM.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(detail)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            Spacer()
            Text(value.uppercased())
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.55))
        )
    }
}

struct Step_WorkoutLogDemo: View {
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    @StateObject private var session: ActiveWorkoutSession

    init(progress: Double, onBack: @escaping () -> Void, onContinue: @escaping () -> Void) {
        self.progress = progress
        self.onBack = onBack
        self.onContinue = onContinue
        _session = StateObject(wrappedValue: ActiveWorkoutSession(trainingDraft: Self.demoDraft))
    }

    var body: some View {
        OnboardingScaffold(
            title: L10n.onboarding("workoutLogDemo.title", defaultValue: "Workout log"),
            subtitle: nil,
            progress: progress,
            primaryTitle: session.progressSummary.isComplete
                ? L10n.onboarding("workoutLogDemo.primary.ready", defaultValue: "Finish log")
                : L10n.onboarding("workoutLogDemo.primary.waiting", defaultValue: "Log all sets"),
            primaryIcon: "checkmark",
            primaryEnabled: session.progressSummary.isComplete,
            hudStep: .workoutLogDemo,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            OnboardingWorkoutLogExperience(session: session)
        }
    }

    private static var demoDraft: TrainingSessionDraft {
        TrainingSessionDraft(
            id: "onboarding-workout-log-demo",
            userId: "onboarding-demo",
            source: .program,
            title: "Upper Rank Mission",
            estimatedMinutes: 28,
            programId: "onboarding-demo-program",
            dayNumber: 1,
            blocks: [
                TrainingBlock(
                    kind: .bodyweight,
                    title: "Main Work",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Push-Up",
                            sets: 2,
                            target: .repsRange(8, 10),
                            restSeconds: 75,
                            muscleGroups: [.chest, .shoulders, .arms],
                            rpe: 7,
                            notes: "Straight line. Full lockout. Stop before form breaks."
                        ),
                        TrainingBlockPrescription(
                            exerciseName: "Goblet Squat",
                            sets: 2,
                            target: .reps(10),
                            restSeconds: 90,
                            muscleGroups: [.legs, .glutes, .core],
                            rpe: 7,
                            suggestedWeightKg: 24
                        )
                    ]
                )
            ]
        )
    }
}

private struct OnboardingWorkoutLogExperience: View {
    @ObservedObject var session: ActiveWorkoutSession
    @State private var expandedExerciseIds: Set<String> = []
    @State private var editing: EditTarget?
    @State private var rpeTarget: RPETarget?

    private struct EditTarget: Identifiable {
        let id = UUID()
        let exerciseIndex: Int
        let setIndex: Int
        let isWeight: Bool
    }

    private struct RPETarget: Identifiable {
        let id = UUID()
        let exerciseIndex: Int
        let setIndex: Int
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(session.exercises.enumerated()), id: \.element.id) { exerciseIndex, exercise in
                if !exercise.skipped {
                    exerciseCard(exerciseIndex: exerciseIndex, exercise: exercise)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            expandedExerciseIds = Set(session.exercises.map(\.id))
        }
        .sheet(item: $editing) { target in
            EditorSheet(
                session: session,
                ei: target.exerciseIndex,
                si: target.setIndex,
                isWeight: target.isWeight,
                onCommitted: {}
            )
        }
        .sheet(item: $rpeTarget) { target in
            RPEPickerSheet(
                current: currentRPE(for: target),
                onPick: { value in
                    session.setRPE(exerciseIndex: target.exerciseIndex, setIndex: target.setIndex, value)
                }
            )
            .presentationDetents([.height(420)])
        }
    }

    private func exerciseCard(
        exerciseIndex: Int,
        exercise: ActiveWorkoutSession.ActiveExercise
    ) -> some View {
        let isCurrent = exerciseIndex == session.currentExerciseIndex
        return ExerciseLogCard(
            name: exercise.name,
            plannedSets: exercise.plannedSets,
            plannedReps: exercise.plannedReps,
            targetRPE: exercise.targetRPE,
            restSeconds: exercise.restSeconds,
            muscleGroups: exercise.muscleGroups,
            formCues: exercise.formCues,
            substitution: exercise.substitution,
            movementId: exercise.movementId,
            blockKind: exercise.blockKind,
            metricKind: exercise.metricKind,
            tracksHold: exercise.tracksHold,
            isWarmupCurrent: exercise.sets.first?.isWarmup ?? false,
            sets: exercise.sets,
            isExpanded: expandedExerciseIds.contains(exercise.id),
            isCurrent: isCurrent,
            currentSetIndex: isCurrent ? session.currentSetIndex : nil,
            onToggleExpand: {
                if expandedExerciseIds.contains(exercise.id) {
                    expandedExerciseIds.remove(exercise.id)
                } else {
                    expandedExerciseIds.insert(exercise.id)
                }
            },
            onIntent: { _ in },
            onEditWeight: { setIndex in
                editing = EditTarget(exerciseIndex: exerciseIndex, setIndex: setIndex, isWeight: true)
            },
            onEditReps: { setIndex in
                editing = EditTarget(exerciseIndex: exerciseIndex, setIndex: setIndex, isWeight: false)
            },
            onPickRPE: { setIndex in
                rpeTarget = RPETarget(exerciseIndex: exerciseIndex, setIndex: setIndex)
            },
            onConfirmAsPlanned: { setIndex in
                UnboundHaptics.medium()
                session.confirmAsPlanned(exerciseIndex: exerciseIndex, setIndex: setIndex)
            },
            onToggleQualityFlag: { setIndex, flag in
                session.toggleQualityFlag(flag, exerciseIndex: exerciseIndex, setIndex: setIndex)
            },
            onAddSet: {},
            allowsProtocolEditing: false
        )
    }

    private func currentRPE(for target: RPETarget) -> Int? {
        guard session.exercises.indices.contains(target.exerciseIndex),
              session.exercises[target.exerciseIndex].sets.indices.contains(target.setIndex)
        else { return nil }

        let set = session.exercises[target.exerciseIndex].sets[target.setIndex]
        return set.rpe ?? set.suggestedRPE
    }
}

struct Step_WorkoutRewardDemo: View {
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var didFinishReward = false

    var body: some View {
        WorkoutRewardSequenceView(summary: Self.onboardingRewardSummary) {
            finishReward()
        }
        .ignoresSafeArea()
    }

    private func finishReward() {
        guard !didFinishReward else { return }
        didFinishReward = true
        OnboardingAppStoreReviewPrompt.request()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onContinue()
        }
    }

    private static var onboardingRewardSummary: WorkoutRewardSequenceSummary {
        var summary = WorkoutRewardSequenceSummary(
            workoutName: "Workout Logged",
            durationMinutes: 0,
            workSets: 0,
            volumeKg: 0,
            rpe: nil,
            xp: XPReward(
                total: 0,
                previousLevel: 1,
                newLevel: 1,
                previousProgress: 0,
                newProgress: 0,
                breakdown: []
            ),
            liftProgress: [],
            attributeDeltas: [],
            personalRecords: [],
            badges: [],
            arcProgress: ArcProgressReward(
                arcName: "Onboarding",
                week: 1,
                totalWeeks: 1,
                completedSessions: 0,
                totalSessions: 1,
                didCompleteWeek: false,
                didCompleteArc: false,
                bonusXP: 0
            ),
            cosmeticUnlock: nil
        )
        summary.showsSessionSummary = false
        summary.showsFinalSummary = false
        summary.streak = StreakReward(dayCount: 1, didExtend: true)
        return summary
    }
}

struct Step_NativeAppRatingPrompt: View {
    let onContinue: () -> Void

    @State private var didRequest = false

    var body: some View {
        Color.unbound.bg
            .ignoresSafeArea()
            .onAppear(perform: requestAndContinue)
    }

    private func requestAndContinue() {
        guard !didRequest else { return }
        didRequest = true
        OnboardingAppStoreReviewPrompt.request()
        onContinue()
    }
}

private enum OnboardingAppStoreReviewPrompt {
    static func request() {
        #if DEBUG
        guard !ProcessInfo.processInfo.arguments.contains("-SuppressOnboardingReviewPrompt") else {
            return
        }
        #endif

        #if canImport(UIKit)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        SKStoreReviewController.requestReview(in: scene)
        #endif
    }
}

#Preview("Problem") {
    Step_ProblemFrame(onContinue: {})
}

#Preview("Arc Status") {
    Step_RestartLoop(onContinue: {})
}

#Preview("Fix") {
    Step_UnboundFix(onContinue: {})
}
