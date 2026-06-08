#if DEBUG
import SwiftUI

/// TEMPORARY proof harness: boots the REAL ActiveWorkoutContainerView with a
/// seeded draft + real services, so the live integrated logging screen can be
/// screenshotted. Launched via `-activeWorkoutDemo`. Remove after verification.
struct ActiveWorkoutDemoHarness: View {
    @StateObject private var services = ServiceContainer()

    var body: some View {
        ActiveWorkoutContainerView(draft: Self.demoDraft, services: services)
            .environmentObject(services)
    }

    private static var demoDraft: TrainingSessionDraft {
        func rx(_ name: String, kg: Double) -> TrainingBlockPrescription {
            TrainingBlockPrescription(
                exerciseName: name,
                sets: 3,
                target: .reps(8),
                restSeconds: 90,
                rpe: 8,
                suggestedWeightKg: kg
            )
        }
        let block = TrainingBlock(
            kind: .strength,
            title: "Main Work",
            prescriptions: [
                rx("Overhead Press", kg: 45),
                rx("Bench Press", kg: 60),
                rx("Triceps Pushdown", kg: 25)
            ]
        )
        return TrainingSessionDraft(
            userId: "demo",
            source: .custom,
            title: "Push Day",
            estimatedMinutes: 35,
            blocks: [block]
        )
    }
}
#endif
