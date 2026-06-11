import SwiftUI

struct ProgressTimelineView: View {
    @EnvironmentObject var services: ServiceContainer
    @StateObject private var viewModel: ProgressViewModel

    init(services: ServiceContainer) {
        _viewModel = StateObject(wrappedValue: ProgressViewModel(services: services))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.theme.background.ignoresSafeArea()

            if viewModel.state.isLoading {
                ProgressView()
                    .tint(.theme.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.entries.isEmpty {
                emptyStateView
            } else {
                timelineList
            }

            // FAB removed — scan is now accessed via ScanDueCard on Home / ProfileScanRow.
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Task { await viewModel.loadProgress() }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.stand")
                .font(.system(size: 72))
                .foregroundColor(.theme.textMuted)

            VStack(spacing: 8) {
                Text("No scans yet")
                    .font(.subheadline(22))
                    .foregroundColor(.theme.textPrimary)

                Text("Start your first scan")
                    .font(.bodyText(16))
                    .foregroundColor(.theme.textSecondary)
            }

            Text("Use the Scan button on Home or Profile to start.")
                .font(.bodyText(14))
                .foregroundColor(.theme.textMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Timeline List

    private var timelineList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                    TimelineEntryCard(
                        entry: entry,
                        delta: viewModel.scoreDelta(for: entry),
                        isFirst: index == 0
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100) // room for FAB
        }
    }
}

// MARK: - Timeline Entry Card

private struct TimelineEntryCard: View {
    let entry: ProgressEntry
    let delta: Int?
    let isFirst: Bool

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: entry.createdAt)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Score Ring
            ScoreRing(
                score: entry.overallScore,
                maxScore: 100,
                size: 60,
                lineWidth: 5,
                color: .theme.secondary
            )

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.bodyMedium(15))
                    .foregroundColor(.theme.textPrimary)

                Text("Overall Score: \(entry.overallScore)")
                    .font(.bodyText(13))
                    .foregroundColor(.theme.textSecondary)
            }

            Spacer()

            // Delta badge
            if let delta = delta {
                DeltaBadge(delta: delta)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.theme.textMuted)
        }
        .padding(16)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isFirst ? Color.theme.primary.opacity(0.4) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Delta Badge

struct DeltaBadge: View {
    let delta: Int

    private var isPositive: Bool { delta >= 0 }
    private var color: Color { isPositive ? .theme.success : .theme.danger }
    private var sign: String { isPositive ? "+" : "" }

    var body: some View {
        Text("\(sign)\(delta)")
            .font(.bodyMedium(13))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationStack {
        ProgressTimelineView(services: .mock)
            .environmentObject(ServiceContainer.mock)
    }
}
