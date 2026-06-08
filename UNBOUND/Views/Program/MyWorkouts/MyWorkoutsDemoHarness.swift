#if DEBUG
import SwiftUI

/// Verification harness for the My Workouts landing via `-myWorkoutsDemo`.
/// Mirrors production: Quick Log → active workout; Build → SessionEditor → active workout.
struct MyWorkoutsDemoHarness: View {
    @StateObject private var services = ServiceContainer()
    @State private var activeDraft: TrainingSessionDraft?
    @State private var editorDraft: TrainingSessionDraft?

    var body: some View {
        MyWorkoutsView(
            onQuickLog: { activeDraft = QuickLogDraftFactory.empty(userId: "demo") },
            onBuild: { editorDraft = QuickLogDraftFactory.empty(userId: "demo") },
            onUseToday: { _ in activeDraft = QuickLogDraftFactory.empty(userId: "demo") },
            onSchedule: { _ in }
        )
        .environmentObject(services)
        .fullScreenCover(item: $activeDraft) { d in
            ActiveWorkoutContainerView(draft: d, services: services) { activeDraft = nil }
                .environmentObject(services)
        }
        .fullScreenCover(item: $editorDraft) { d in
            SessionEditorView(draft: d) { editedDraft in
                editorDraft = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    activeDraft = editedDraft
                }
            }
            .environmentObject(services)
        }
    }
}
#endif
