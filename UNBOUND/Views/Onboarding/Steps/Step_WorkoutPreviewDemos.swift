import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Onboarding "taste the loop" beat: boots the REAL active-workout surface
/// (same container, grid, and bottom-keypad logging as the live app) in
/// rehearsal mode — nothing is persisted, and finishing hands control back to
/// the flow. The mission list at the top of the surface doubles as the
/// "this is what you open each day" reveal.
struct Step_WorkoutLogDemo: View {
    let onContinue: () -> Void

    @EnvironmentObject var services: ServiceContainer

    var body: some View {
        ActiveWorkoutContainerView(
            draft: Self.demoDraft,
            services: services,
            isRehearsal: true,
            onFinished: onContinue
        )
        .toolbar(.hidden, for: .navigationBar)
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
                        // No RPE on the taste-the-loop demo — brand-new users
                        // haven't been taught the scale yet; keep it reps + rest.
                        TrainingBlockPrescription(
                            exerciseName: "Push-Up",
                            sets: 2,
                            target: .repsRange(8, 10),
                            restSeconds: 75,
                            muscleGroups: [.chest, .shoulders, .arms],
                            notes: "Straight line. Full lockout. Stop before form breaks."
                        ),
                        TrainingBlockPrescription(
                            exerciseName: "Goblet Squat",
                            sets: 2,
                            target: .reps(10),
                            restSeconds: 90,
                            muscleGroups: [.legs, .glutes, .core],
                            suggestedWeightKg: 24
                        )
                    ]
                )
            ]
        )
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
        // No rating ask here — it used to fire from this spot and Apple's
        // sheet landed on top of the pact's sealed-gate entrance. The
        // onboarding ask now lives on the verdict reveal (Step_Verdict).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onContinue()
        }
    }

    /// A real-but-tiny payout: the first drip of XP and Arcs through the SAME
    /// reward sequence the app uses — no stats, no streak theater. Numbers ride
    /// the real curve (`OverallLevelCurve`: LVL 1 at 16 XP, LVL 2 at 64), so the
    /// first session's +18 XP genuinely rings the user up to LEVEL 1.
    private static var onboardingRewardSummary: WorkoutRewardSequenceSummary {
        var summary = WorkoutRewardSequenceSummary(
            workoutName: "Workout Logged",
            durationMinutes: 0,
            workSets: 0,
            volumeKg: 0,
            rpe: nil,
            xp: XPReward(
                total: 18,
                previousLevel: 0,
                newLevel: 1,
                previousProgress: 0,
                newProgress: 2.0 / 48.0,
                previousXP: 0,
                currentXP: 18,
                levelFloorXP: 16,
                nextLevelXP: 64,
                breakdown: [
                    XPBreakdownLine(label: "Work sets logged", amount: 14),
                    XPBreakdownLine(label: "First session", amount: 4)
                ]
            ),
            liftProgress: [],
            attributeDeltas: [],
            personalRecords: [],
            badges: [],
            arcProgress: ArcProgressReward(
                arcName: "Onboarding",
                week: 1,
                totalWeeks: 1,
                completedSessions: 1,
                totalSessions: 1,
                didCompleteWeek: false,
                didCompleteArc: false,
                bonusXP: 0
            ),
            cosmeticUnlock: nil
        )
        summary.showsSessionSummary = false
        summary.showsFinalSummary = true
        summary.arcsEarned = 90
        // The first session starts the streak - day one is a freebie the
        // reward sequence hands over, so there's something to protect tomorrow.
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
        AppStoreReviewPrompt.request()
        onContinue()
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
