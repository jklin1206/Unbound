#if DEBUG
import SwiftUI

/// Verification harness for the My Workouts landing via `-myWorkoutsDemo`.
/// Mirrors production: Quick Log → active workout; Build → SessionEditor → active workout.
struct MyWorkoutsDemoHarness: View {
    @StateObject private var services: ServiceContainer
    @State private var activeDraft: TrainingSessionDraft?
    @State private var editorDraft: TrainingSessionDraft?
    @State private var savedWorkoutRevision = 0

    init() {
        _services = StateObject(wrappedValue: ServiceContainer())
        // Seed sample saved workouts BEFORE the body builds, so the inline list's
        // init-time snapshot of SavedWorkoutStore picks them up. Demoable on a
        // freshly-installed simulator (the QA-Lab seed is wiped on reinstall).
        if SavedWorkoutStore.shared.all().isEmpty {
            for workout in DevBuildBootstrapper.programQALabSavedWorkouts(now: Date()) {
                SavedWorkoutStore.shared.save(workout)
            }
        }
    }

    var body: some View {
        MyWorkoutsView(
            refreshTrigger: savedWorkoutRevision,
            onQuickLog: { activeDraft = QuickLogDraftFactory.empty(userId: "demo") },
            onBuild: { editorDraft = SavedWorkoutDraftFactory.empty(userId: "demo") },
            onStartWorkout: { workout in activeDraft = workout.asDraft(userId: "demo") },
            onEdit: { workout in editorDraft = workout.asEditingDraft(userId: "demo") }
        )
        .environmentObject(services)
        .fullScreenCover(item: $activeDraft) { d in
            ActiveWorkoutContainerView(draft: d, services: services, onFinished: { activeDraft = nil })
                .environmentObject(services)
        }
        .fullScreenCover(item: $editorDraft) { d in
            let isExistingLoadout = UUID(uuidString: d.id)
                .map { SavedWorkoutStore.shared.get(id: $0) != nil } ?? false
            SessionEditorView(draft: d, mode: isExistingLoadout ? .editWorkout : .saveWorkout) { editedDraft in
                // Mirror production: the library entry is keyed off the draft id,
                // so editing an existing loadout updates it instead of duplicating.
                var saved = SavedWorkout.from(editedDraft)
                if let stableId = UUID(uuidString: editedDraft.id) {
                    saved.id = stableId
                }
                SavedWorkoutStore.shared.save(saved)
                editorDraft = nil
                savedWorkoutRevision += 1
            }
            .environmentObject(services)
        }
    }
}
#endif
