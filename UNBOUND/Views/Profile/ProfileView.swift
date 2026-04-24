import SwiftUI

// MARK: - ProfileView
//
// The ARCHIVE counterpart to Home. Home is LIVE (what's happening today);
// Profile is identity, lifetime state, collection, and settings. Per the
// `project_unbound_home_vs_profile_boundary` memory:
//
//   Home  — today's mission, live rank, live streak, today's stats
//   Profile — who you've become: avatar, rank journey, badges grid,
//             photo library, stats history, settings
//
// This first-pass profile surfaces what we already compute on home at
// rest (rank, stats, badges, body map) and nests the existing
// SettingsView as a push destination for account/preferences.
//
// Deferred to future passes:
//   - Real scan photo library (grid of ProgressPhoto)
//   - Stats history charts (weekly/monthly trend)
//   - Rank journey timeline (when you crossed D → C → B)
//   - Titles collection (separate from badges, per rank memory)

struct ProfileView: View {
    @EnvironmentObject var services: ServiceContainer

    @State private var profile: UserProfile?
    @State private var aggregateRank: SubRank = .eMinus
    @State private var statScore: StatScore = .empty
    @State private var liftRanks: [LiftRank] = []
    @State private var heatmapRanks: [MuscleHeatGroup: SubRank] = [:]
    @State private var unlockedBadges: [Badge] = []
    @State private var totalBadgeCount: Int = 0
    @State private var sessionXP: SessionXPRecord?
    @State private var isLoading = true

    @AppStorage("unbound.gains") private var gains: Int = 0
    private let xpPerLevel: Int = 250

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(Color.unbound.accent)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard
                        rankJourneyCard
                        lifetimeStats
                        bodyMapCard
                        badgesCard
                        PhotoCalendarView().environmentObject(services)
                        settingsLink
                        Spacer().frame(height: 28)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
        }
        .navigationBarHidden(true)
        .task { await load() }
    }

    // MARK: - Load

    @MainActor
    private func load() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        services.badges.bind(userId: userId)

        do {
            profile = try await services.user.fetchProfile(userId: userId)
        } catch {
            profile = nil
        }

        let archetype = profile?.preferredArchetype ?? .vTaper
        aggregateRank = await services.rank.archetypeRank(userId: userId, archetype: archetype)
        statScore = await services.statScore.compute(userId: userId, archetype: archetype)

        liftRanks = await services.rank.fetchAll(userId: userId)
        var computed = MuscleRankCalculator.heatmapRanks(liftRanks: liftRanks)
        for g in MuscleHeatGroup.allCases where computed[g] == nil {
            computed[g] = .eMinus
        }
        heatmapRanks = computed

        unlockedBadges = services.badges.unlockedBadges(userId: userId)
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
        totalBadgeCount = BadgeCatalog.all.count
        sessionXP = services.sessionXP.record(userId: userId)

        isLoading = false
    }

    // MARK: - Header card

    private var headerCard: some View {
        let level = (gains / xpPerLevel) + 1
        let archetype = profile?.preferredArchetype
        let initial = avatarInitial

        return HStack(alignment: .center, spacing: 16) {
            // Avatar + LV badge (placeholder — real photo wires in later).
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle().fill(Color.unbound.surface)
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.unbound.accent.opacity(0.75),
                                    Color.unbound.accent.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                    Text(initial)
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                .frame(width: 72, height: 72)

                Text("\(level)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.unbound.accent))
                    .offset(x: 6, y: 6)
            }
            .shadow(color: Color.unbound.accent.opacity(0.35), radius: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName.uppercased())
                    .font(Font.unbound.titleM)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                if let archetype {
                    Text(archetype.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.accent)
                }
                Text("LV \(level) · \(longestStreakLabel)")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            Spacer()
        }
    }

    private var displayName: String {
        profile?.displayName ?? "WARRIOR"
    }

    private var avatarInitial: String {
        if let name = profile?.displayName, let first = name.first {
            return String(first).uppercased()
        }
        if let archetype = profile?.preferredArchetype {
            return String(archetype.shortName.prefix(1)).uppercased()
        }
        return "U"
    }

    private var longestStreakLabel: String {
        let longest = sessionXP?.longestStreak ?? 0
        if longest == 0 { return "NO STREAK YET" }
        return "BEST \(longest)-DAY STREAK"
    }

    // MARK: - Rank journey card

    private var rankJourneyCard: some View {
        let tier = tierName(for: aggregateRank)
        let nextRank = aggregateRank.advanced(by: 1)
        let ordinal = aggregateRank.ordinal
        let journeyFraction = max(0.05, min(1.0, Double(ordinal) / 17.0))
        let rankColor = aggregateRank.regionTint

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("RANK JOURNEY")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("\(ordinal + 1) / 18")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .monospacedDigit()
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(aggregateRank.letter)
                    .font(Font.unbound.displayL)
                    .foregroundStyle(rankColor)
                    .shadow(color: rankColor.opacity(0.6), radius: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.uppercased())
                        .font(Font.unbound.monoM)
                        .tracking(1.6)
                        .foregroundStyle(rankColor)
                    Text(aggregateRank.displayName)
                        .font(Font.unbound.captionS)
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("NEXT")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(nextRank.displayName)
                        .font(Font.unbound.monoM.weight(.bold))
                        .foregroundStyle(nextRank.regionTint)
                }
            }

            // E──D──C──B──A──S progress bar. Thin, ranked-tick marks.
            rankJourneyBar(fraction: journeyFraction, color: rankColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [rankColor.opacity(0.12), .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 260
                        )
                    )
            }
        )
    }

    private func rankJourneyBar(fraction: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.borderSubtle)
                    Capsule()
                        .fill(color)
                        .frame(width: max(4, proxy.size.width * fraction))
                        .shadow(color: color.opacity(0.5), radius: 3)
                }
            }
            .frame(height: 4)

            HStack(spacing: 0) {
                ForEach(["E", "D", "C", "B", "A", "S"], id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(rankTickColor(for: letter))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func rankTickColor(for letter: String) -> Color {
        // Letters the user has reached or passed tint with their rank color;
        // future letters stay muted.
        let ord = SubRank.ordinalForLetter(letter)
        return ord <= aggregateRank.ordinal
            ? Color.unbound.textSecondary
            : Color.unbound.textTertiary.opacity(0.5)
    }

    // MARK: - Lifetime stats

    private var lifetimeStats: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LIFETIME STATS")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)

            VStack(spacing: 6) {
                statRow(label: "STR", rank: statScore.strengthRank)
                statRow(label: "STA", rank: statScore.staminaRank)
                statRow(label: "TEC", rank: statScore.techniqueRank)
                statRow(label: "VIT", rank: statScore.vitalityRank)
            }

            Rectangle()
                .fill(Color.unbound.borderSubtle)
                .frame(height: 0.5)
                .padding(.vertical, 2)

            let bodyColumns = [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ]
            LazyVGrid(columns: bodyColumns, spacing: 6) {
                bodyStatCell(label: "CHEST", rank: aggregate(of: [.chest]))
                bodyStatCell(label: "BACK",  rank: aggregate(of: [.back]))
                bodyStatCell(label: "SHLDR", rank: aggregate(of: [.shoulders, .traps]))
                bodyStatCell(label: "ARMS",  rank: aggregate(of: [.biceps, .triceps, .forearms]))
                bodyStatCell(label: "CORE",  rank: aggregate(of: [.core]))
                bodyStatCell(label: "LEGS",  rank: aggregate(of: [.legs, .hamstrings, .glutes, .calves]))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    private func statRow(label: String, rank: SubRank) -> some View {
        let color = rank.regionTint
        return HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 34, alignment: .leading)
            Text(rank.displayName)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.5), radius: 3)
                .monospacedDigit()
            Spacer(minLength: 0)
        }
        .frame(height: 16)
    }

    private func bodyStatCell(label: String, rank: SubRank) -> some View {
        let color = rank.regionTint
        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 44, alignment: .leading)
            Text(rank.displayName)
                .font(Font.unbound.monoS.weight(.semibold))
                .foregroundStyle(color)
                .monospacedDigit()
            Spacer(minLength: 0)
        }
    }

    private func aggregate(of groups: [MuscleHeatGroup]) -> SubRank {
        guard !groups.isEmpty else { return .eMinus }
        let ordinals = groups.map { Double(heatmapRanks[$0]?.ordinal ?? 0) }
        let mean = ordinals.reduce(0, +) / Double(ordinals.count)
        return SubRank.nearest(for: mean)
    }

    // MARK: - Body map card

    private var bodyMapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BODY MAP")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)

            MuscleHeatmapView(groupRanks: heatmapRanks, onGroupTapped: { _ in })
                .frame(maxWidth: 220)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    // MARK: - Badges card

    private var badgesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BADGES")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("\(unlockedBadges.count) / \(totalBadgeCount)")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .monospacedDigit()
            }

            if unlockedBadges.isEmpty {
                Text("Earn your first badge by logging a session.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            } else {
                let cols = [GridItem(.adaptive(minimum: 60, maximum: 72), spacing: 10)]
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(unlockedBadges.prefix(12)) { b in
                        badgeTile(b)
                    }
                }
            }

            NavigationLink(destination: BadgeGalleryView().environmentObject(services)) {
                HStack {
                    Text("VIEW ALL")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.4)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color.unbound.accent)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    private func badgeTile(_ badge: Badge) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(badge.rarity.tint.opacity(0.12))
                Circle()
                    .strokeBorder(badge.rarity.tint.opacity(0.55), lineWidth: 1)
                Image(systemName: badge.iconSystemName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(badge.rarity.tint)
                    .shadow(color: badge.rarity.tint.opacity(0.5), radius: 4)
            }
            .frame(width: 52, height: 52)
            Text(badge.displayName.uppercased())
                .font(.system(size: 8, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    // MARK: - Photo library placeholder

    private var photoLibraryPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PHOTO LIBRARY")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("COMING SOON")
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.unbound.bg)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.unbound.textTertiary.opacity(0.4))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                        )
                        .aspectRatio(0.72, contentMode: .fit)
                }
            }
            Text("Your front + back scan progression will live here.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    // MARK: - Settings link

    private var settingsLink: some View {
        NavigationLink(destination: SettingsView(services: services)) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                Text("SETTINGS")
                    .font(Font.unbound.bodyMStrong)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func tierName(for rank: SubRank) -> String {
        switch rank.letter {
        case "E": return "Dormant"
        case "D": return "Awakened"
        case "C": return "Forged"
        case "B": return "Sharpened"
        case "A": return "Unbound"
        case "S": return "Ascended"
        default:  return "Dormant"
        }
    }
}
