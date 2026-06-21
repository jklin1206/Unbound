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
        if let trial = rankTrialDraft() { return trial }
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

    /// `UNBOUND_ACTIVE_TRIAL=<format>` boots the REAL container into a live rank
    /// trial so the gate header, station-clear beats, and pass/fail verdict can be
    /// driven + screenshotted end to end (format = a `RankTrialFormat` rawValue).
    private static func rankTrialDraft() -> TrainingSessionDraft? {
        guard let raw = ProcessInfo.processInfo.environment["UNBOUND_ACTIVE_TRIAL"],
              !raw.isEmpty else { return nil }
        let norm = raw.lowercased()
        guard let definition = OverallRankTrialDefinitions.all.first(where: {
            $0.format.rawValue.lowercased() == norm
        }) else { return nil }
        let equipment: Set<MovementEquipment> = [.bodyweight, .openSpace, .dumbbell, .kettlebell, .pullupBar, .band]
        let resolution = RankTrialLoadoutResolver.shared.resolve(
            definition: definition, userId: DevBuildBootstrapper.userId, equipment: equipment)
        return definition.makeDraft(
            userId: DevBuildBootstrapper.userId,
            resolvedTrial: resolution.resolvedTrial,
            bodyweightKg: 82)
    }
}
#endif
