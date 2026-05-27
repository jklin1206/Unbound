import SwiftUI

/// Wraps the scan flow for returning users.
/// Shows a comparison after analysis completes.
struct RescanView: View {
    @EnvironmentObject var services: ServiceContainer
    let previousEntry: ProgressEntry

    var body: some View {
        // ScanIntroView removed — scan is now accessed via ScanDueCard on Home / ProfileScanRow.
        PhotoCaptureFlow(mode: .scan) { _ in }
            .environmentObject(services)
    }
}

#Preview {
    NavigationStack {
        RescanView(
            previousEntry: ProgressEntry(
                id: "1", userId: "u1", scanId: "s1", analysisId: "a1",
                createdAt: Date(), overallScore: 72,
                muscleScores: ["chest": 70, "back": 68, "arms": 75]
            )
        )
        .environmentObject(ServiceContainer.mock)
    }
}
