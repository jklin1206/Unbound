#if DEBUG
import SwiftUI

/// Verification harness: boots the real SessionEditorView (the workout builder)
/// with a seeded draft, via `-sessionEditorDemo`, so the calm-list conversion of
/// the editor rows can be screenshotted on-sim.
struct SessionEditorDemoHarness: View {
    @StateObject private var services = ServiceContainer()

    var body: some View {
        SessionEditorView(draft: Self.demoDraft, mode: .planAhead, onStart: { _ in })
            .environmentObject(services)
    }

    private static var demoDraft: TrainingSessionDraft {
        func rx(_ name: String, kg: Double) -> TrainingBlockPrescription {
            TrainingBlockPrescription(
                exerciseName: name, sets: 3, target: .reps(8),
                restSeconds: 90, rpe: 8, suggestedWeightKg: kg
            )
        }
        let block = TrainingBlock(
            kind: .strength, title: "Main Work",
            prescriptions: [
                rx("Overhead Press", kg: 45),
                rx("Bench Press", kg: 60),
                rx("Triceps Pushdown", kg: 25)
            ]
        )
        return TrainingSessionDraft(
            userId: "demo", source: .custom, title: "Push Day",
            estimatedMinutes: 35, blocks: [block]
        )
    }
}
#endif
