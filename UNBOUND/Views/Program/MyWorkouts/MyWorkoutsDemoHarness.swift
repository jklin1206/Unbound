#if DEBUG
import SwiftUI

/// Verification harness for the My Workouts landing via `-myWorkoutsDemo`.
struct MyWorkoutsDemoHarness: View {
    @StateObject private var services = ServiceContainer()
    @State private var draft: TrainingSessionDraft?

    var body: some View {
        MyWorkoutsView(
            onQuickLog: { draft = QuickLogDraftFactory.empty(userId: "demo") },
            onBuild: { draft = QuickLogDraftFactory.empty(userId: "demo") },
            onOpenSaved: {}
        )
        .environmentObject(services)
        .fullScreenCover(item: $draft) { d in
            ActiveWorkoutContainerView(draft: d, services: services) { draft = nil }
                .environmentObject(services)
        }
    }
}
#endif
