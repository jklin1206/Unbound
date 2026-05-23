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

// MARK: - Comparison View

/// Shown after a rescan completes. Compares previous vs current scores.
struct RescanComparisonView: View {
    let previousEntry: ProgressEntry
    let currentEntry: ProgressEntry

    private var overallDelta: Int {
        currentEntry.overallScore - previousEntry.overallScore
    }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    Text("Your Progress")
                        .font(.headline(28))
                        .foregroundColor(.theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Side-by-side overall scores
                    HStack(spacing: 16) {
                        scoreColumn(
                            title: "Before",
                            score: previousEntry.overallScore,
                            date: previousEntry.createdAt
                        )

                        // Delta indicator
                        VStack(spacing: 4) {
                            Image(systemName: overallDelta >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(overallDelta >= 0 ? .theme.success : .theme.danger)
                            DeltaBadge(delta: overallDelta)
                        }

                        scoreColumn(
                            title: "After",
                            score: currentEntry.overallScore,
                            date: currentEntry.createdAt
                        )
                    }
                    .padding(20)
                    .background(Color.theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Status badge
                    overallStatusBadge

                    // Per-muscle breakdown
                    muscleBreakdownSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Scan Comparison")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func scoreColumn(title: String, score: Int, date: Date) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.bodyMedium(13))
                .foregroundColor(.theme.textSecondary)

            ScoreRing(
                score: score,
                maxScore: 100,
                size: 90,
                lineWidth: 7,
                color: .theme.secondary
            )

            Text(shortDate(date))
                .font(.caption(12))
                .foregroundColor(.theme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var overallStatusBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: overallDelta >= 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(overallDelta >= 0 ? .theme.success : .theme.danger)
            Text(overallDelta >= 0 ? "Improved" : "Declined")
                .font(.bodyMedium(16))
                .foregroundColor(overallDelta >= 0 ? .theme.success : .theme.danger)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background((overallDelta >= 0 ? Color.theme.success : Color.theme.danger).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var muscleBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscle Groups")
                .font(.bodyMedium(17))
                .foregroundColor(.theme.textPrimary)

            let allKeys = Set(previousEntry.muscleScores.keys).union(currentEntry.muscleScores.keys).sorted()

            ForEach(allKeys, id: \.self) { key in
                let prev = previousEntry.muscleScores[key] ?? 0
                let curr = currentEntry.muscleScores[key] ?? 0
                let d = curr - prev

                HStack {
                    Text(key.capitalized)
                        .font(.bodyText(14))
                        .foregroundColor(.theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(prev) → \(curr)")
                        .font(.bodyMedium(14))
                        .foregroundColor(.theme.textPrimary)

                    DeltaBadge(delta: d)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f.string(from: date)
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
