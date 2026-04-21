import SwiftUI

// MARK: - MuscleDetailSheet
//
// Drawer presented when a region is tapped on BodyMapView or the
// ExpandedBodyMapView muscle list.
// Shows the region's aggregate rank, sub-rank progress hint, the top
// contributing lifts and their ranks, recent PRs pulled from WorkoutLog,
// and flags any contributing lifts the user hasn't logged recently.

struct MuscleDetailSheet: View {
    let region: BodyRegion
    let regionRank: RegionRank
    let allLiftRanks: [LiftRank]

    @EnvironmentObject var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

    @State private var recentPRs: [RecentPR] = []
    @State private var underTrained: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                rankDisplay
                progressHint
                contributingSection
                recentPRsSection
                underTrainedSection
            }
            .padding(24)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .task { await loadDetails() }
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            Text(region.displayName.uppercased())
                .font(Font.unbound.captionS)
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(8)
                    .background(Circle().fill(Color.unbound.surface))
            }
            .buttonStyle(.plain)
        }
    }

    private var rankDisplay: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 14) {
                Text("RANK")
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(regionRank.rank.displayName)
                    .font(Font.unbound.monoXL)
                    .foregroundStyle(regionRank.rank.regionTint)
            }
            subRankCapsule
        }
    }

    private var subRankCapsule: some View {
        let progress = Double(regionRank.rank.ordinal % 3) / 3.0 + 0.2
        let next = regionRank.rank.advanced(by: 1)
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.borderSubtle)
                    Capsule()
                        .fill(regionRank.rank.regionTint)
                        .frame(width: max(8, proxy.size.width * min(max(progress, 0.1), 0.95)))
                }
            }
            .frame(height: 6)
            Text("NEXT · \(next.displayName)")
                .font(Font.unbound.captionS)
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    private var progressHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEXT THRESHOLD")
                .font(Font.unbound.captionS)
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(nextThresholdHint)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var contributingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOP CONTRIBUTING LIFTS")
                .font(Font.unbound.captionS)
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            if regionRank.topContributingLifts.isEmpty {
                Text("No contributing lifts logged yet. Training \(region.displayName.lowercased()) will light this up.")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(regionRank.topContributingLifts, id: \.exerciseKey) { lift in
                    liftRow(displayName: lift.displayName, rank: lift.rank)
                }
            }
        }
    }

    private func liftRow(displayName: String, rank: SubRank) -> some View {
        HStack(spacing: 12) {
            Text(displayName)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
            Spacer()
            Text(rank.displayName)
                .font(Font.unbound.monoS)
                .foregroundStyle(rank.regionTint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(rank.regionTint.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(rank.regionTint.opacity(0.6), lineWidth: 1)
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var recentPRsSection: some View {
        Group {
            if !recentPRs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("RECENT PRs")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    ForEach(recentPRs) { pr in
                        HStack(spacing: 12) {
                            Text(pr.displayName)
                                .font(Font.unbound.bodyM)
                                .foregroundStyle(Color.unbound.textPrimary)
                            Spacer()
                            Text(pr.summary)
                                .font(Font.unbound.monoS)
                                .foregroundStyle(Color.unbound.accent)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.unbound.surface)
                        )
                    }
                }
            }
        }
    }

    private var underTrainedSection: some View {
        Group {
            if !underTrained.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("UNDER-TRAINED")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    ForEach(underTrained, id: \.self) { lift in
                        HStack(spacing: 10) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.unbound.textTertiary)
                            Text(lift.capitalized)
                                .font(Font.unbound.bodyS)
                                .foregroundStyle(Color.unbound.textSecondary)
                            Spacer()
                            Text("stale")
                                .font(Font.unbound.captionS)
                                .tracking(1.0)
                                .foregroundStyle(Color.unbound.textTertiary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.unbound.surface.opacity(0.5))
                        )
                    }
                }
            }
        }
    }

    // MARK: Copy helpers

    private var nextThresholdHint: String {
        let next = regionRank.rank.advanced(by: 1)
        guard !regionRank.topContributingLifts.isEmpty else {
            return "Start logging \(region.displayName.lowercased()) lifts — any entry opens up this region."
        }
        // Pick the strongest contributing barbell lift to pin a multiplier.
        let barbellLifts = regionRank.topContributingLifts.filter {
            StrengthStandards.isBarbellLift(exerciseKey: $0.exerciseKey)
        }
        if let top = barbellLifts.first,
           let multiplier = StrengthStandards.multiplier(
                exerciseKey: top.exerciseKey,
                letter: next.letter
           ) {
            let pretty = String(format: "%.2g", multiplier)
            return "Push \(top.displayName.capitalized) to \(pretty)× bodyweight to tip this region toward \(next.displayName)."
        }
        return "Rack up quality sets on the contributing lifts — this region advances to \(next.displayName) when its average climbs."
    }

    // MARK: Loading

    @MainActor
    private func loadDetails() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 20)) ?? []
        let contributingKeys = Set(region.contributingLifts.map { $0.lowercased() })

        // Recent PRs — top load by displayName across the last 20 logs
        // where the exercise name substring-matches a contributing lift.
        var bestByKey: [String: (displayName: String, weightKg: Double, reps: Int, at: Date)] = [:]
        for log in logs {
            for entry in log.exerciseEntries where !entry.skipped {
                let key = entry.exerciseName.lowercased()
                let matches = contributingKeys.contains { key.contains($0) || $0.contains(key) }
                guard matches else { continue }
                let topSet = entry.sets.filter { !$0.isWarmup }.max(by: {
                    ($0.weightKg ?? 0) < ($1.weightKg ?? 0)
                })
                guard let set = topSet else { continue }
                let weight = set.weightKg ?? 0
                let existing = bestByKey[key]
                if existing == nil || (existing?.weightKg ?? 0) < weight {
                    bestByKey[key] = (entry.exerciseName, weight, set.reps, log.startedAt)
                }
            }
        }

        recentPRs = bestByKey.values
            .sorted { $0.at > $1.at }
            .prefix(3)
            .map {
                RecentPR(
                    id: $0.displayName,
                    displayName: $0.displayName,
                    summary: formatSetSummary(weight: $0.weightKg, reps: $0.reps)
                )
            }

        // Under-trained: contributing lifts the user has logged-of-record
        // (has a LiftRank) but haven't appeared in the last 20 logs.
        let recentKeys = Set(bestByKey.keys)
        let tracked = allLiftRanks.filter { liftRank in
            contributingKeys.contains { liftRank.exerciseKey.contains($0) || $0.contains(liftRank.exerciseKey) }
        }
        underTrained = tracked
            .filter { !recentKeys.contains($0.exerciseKey) }
            .prefix(3)
            .map(\.displayName)
    }

    private func formatSetSummary(weight: Double, reps: Int) -> String {
        if weight <= 0 {
            return "\(reps) reps"
        }
        return String(format: "%.1f kg × %d", weight, reps)
    }
}

// MARK: - RecentPR

private struct RecentPR: Identifiable {
    let id: String
    let displayName: String
    let summary: String
}
