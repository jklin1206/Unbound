// UNBOUND/Views/Squads/SquadLeaderboardViews.swift
//
// Season surfaces, dialed up: a glowing ember streak hero (with the crew's
// monthly focus), an elevated gold SEASON BOARD with a top-3 podium + medals,
// and the two-item season rewards (First Flame title + Ember Ring border) as
// themed, art-free emblems. Rule/explainer copy lives behind an (i) button so
// the surface stays clean. Self-row highlights full-width (no indent).
import SwiftUI

// MARK: - Info disclosure ((i) button that reveals help copy inline)

/// A small circled-(i) toggle. Callers pair it with `SquadInfoText` gated on the
/// same @State so rule copy stays hidden until asked for.
struct SquadInfoButton: View {
    @Binding var isOn: Bool
    var tint: Color = Color.unbound.textTertiary

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { isOn.toggle() }
        } label: {
            Image(systemName: isOn ? "info.circle.fill" : "info.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isOn ? tint.opacity(0.95) : tint.opacity(0.6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "Hide details" : "Show details")
    }
}

struct SquadInfoText: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Font.unbound.bodyS)
            .foregroundStyle(Color.unbound.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Squad streak (CREW tab)

struct SquadStreakHeroView: View {
    let squad: Squad
    let rows: [SquadBoardRow]
    let season: SquadSeason

    private var weeklySupportCount: Int {
        rows.filter { $0.weeklySessions > 0 }.count
    }

    private var isLive: Bool { squad.squadStreakWeeks > 0 }

    var body: some View {
        SquadSectionCard(
            title: "SQUAD STREAK",
            icon: "flame.fill",
            tint: Color.unbound.ember
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 14) {
                    emberMedallion
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(squad.squadStreakWeeks)")
                                .font(Font.unbound.displayM)
                                .foregroundStyle(isLive ? Color.unbound.ember : Color.unbound.textPrimary)
                                .monospacedDigit()
                                .shadow(color: Color.unbound.ember.opacity(isLive ? 0.5 : 0), radius: 12)
                            Text(squad.squadStreakWeeks == 1 ? "week streak" : "week streak")
                                .font(Font.unbound.bodyS)
                                .foregroundStyle(Color.unbound.textSecondary)
                        }
                        MetaLine([
                            "\(weeklySupportCount)/\(max(rows.count, 1)) trained this week"
                        ])
                    }
                    Spacer(minLength: 0)
                    if let axis = squad.affinityAxis {
                        focusChip(axis)
                    }
                }

                weeklyCoverageBar

                Text(isLive ? "Everyone logs a session this week to extend it."
                            : "Everyone logs a session this week to light it.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Squad streak \(squad.squadStreakWeeks) weeks")
    }

    /// Glowing ember disc with a flame — the streak's hero mark.
    private var emberMedallion: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.unbound.ember.opacity(isLive ? 0.35 : 0.14), Color.unbound.ember.opacity(0.04)],
                        center: .center, startRadius: 2, endRadius: 30
                    )
                )
            Circle()
                .strokeBorder(Color.unbound.ember.opacity(isLive ? 0.55 : 0.25), lineWidth: 1.5)
            Image(systemName: "flame.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.unbound.ember)
                .shadow(color: Color.unbound.ember.opacity(isLive ? 0.6 : 0), radius: 8)
        }
        .frame(width: 54, height: 54)
    }

    /// The crew's monthly affinity focus, surfaced as a small chip.
    private func focusChip(_ axis: AttributeKey) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("FOCUS")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(axis.displayName)
                .font(Font.unbound.bodyS.weight(.semibold))
                .foregroundStyle(Color.unbound.coachCyan)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.coachCyan.opacity(0.12))
        )
    }

    /// One segment per member — filled ember when they trained this week.
    private var weeklyCoverageBar: some View {
        HStack(spacing: 3) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Capsule()
                    .fill(row.weeklySessions > 0 ? Color.unbound.ember : Color.unbound.border)
                    .frame(height: 6)
                    .shadow(color: row.weeklySessions > 0 ? Color.unbound.ember.opacity(0.5) : .clear, radius: 4)
            }
        }
    }
}

// MARK: - Season board (SEASON tab) — elevated gold hero + podium

struct SquadBoardView: View {
    let rows: [SquadBoardRow]
    let season: SquadSeason
    let capacity: Int
    var inviteURL: URL? = nil
    var currentMemberUserId: UUID?

    @State private var showRules = false

    private var seasonRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        let start = formatter.string(from: season.start)
        let end = formatter.string(from: season.end.addingTimeInterval(-1))
        return "\(start)–\(end)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if showRules {
                SquadInfoText(text: "10 pts per training day · 15 per duel win · 10 per PR. Whoever tops the board when the season ends earns the season title.")
            }

            if rows.isEmpty {
                Text("No crew on the board yet.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 2) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        SquadBoardRowView(
                            rank: index + 1,
                            row: row,
                            topScore: rows.first?.boardScore ?? 0,
                            isSelf: row.member.userId == currentMemberUserId
                        )
                    }
                }
            }
        }
        .padding(18)
        .background(boardBackground)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.unbound.rankGold.opacity(0.18))
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.rankGold)
                    .shadow(color: Color.unbound.rankGold.opacity(0.5), radius: 6)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text("SEASON BOARD")
                    .font(Font.unbound.bodyS.weight(.semibold).weight(.heavy))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("\(season.title) · \(seasonRangeText) · \(season.daysRemaining())d left")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.rankGold.opacity(0.85))
            }

            Spacer(minLength: 0)
            SquadInfoButton(isOn: $showRules, tint: Color.unbound.rankGold)
        }
    }

    /// Elevated, gold-touched card so the board reads as the marquee section.
    private var boardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.unbound.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.unbound.rankGold.opacity(0.10), .clear],
                            startPoint: .top, endPoint: .center
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.unbound.rankGold.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: Color.unbound.rankGold.opacity(0.12), radius: 18, y: 6)
    }
}

struct SquadBoardRowView: View {
    let rank: Int
    let row: SquadBoardRow
    var topScore: Int = 0
    var isSelf: Bool = false

    private var isPodium: Bool { rank <= 3 }

    private var rankColor: Color {
        switch rank {
        case 1: return Color.unbound.rankGold
        case 2: return Color.unbound.rankSilver
        case 3: return Color.unbound.rankBronze
        default: return Color.unbound.textTertiary
        }
    }

    private var scoreFraction: Double {
        guard topScore > 0 else { return 0 }
        return min(1, Double(row.boardScore) / Double(topScore))
    }

    var body: some View {
        HStack(spacing: 12) {
            medal

            VStack(alignment: .leading, spacing: 3) {
                Text(row.displayName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                scoreBar
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(row.boardScore)")
                    .font(isPodium ? Font.unbound.monoL : Font.unbound.monoM)
                    .foregroundStyle(row.boardScore > 0 ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                    .monospacedDigit()
                Text("pts")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .padding(.vertical, 10)
        .squadOwnRowHighlight(isSelf)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(rank), \(row.displayName), \(row.boardScore) points")
    }

    /// Podium ranks get a glowing medal (crown for #1); the rest a lean numeral.
    private var medal: some View {
        ZStack {
            Circle()
                .fill(rankColor.opacity(isPodium ? 0.20 : 0.10))
            if isPodium {
                Circle().strokeBorder(rankColor.opacity(0.55), lineWidth: 1.5)
            }
            if rank == 1 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(rankColor)
                    .shadow(color: rankColor.opacity(0.6), radius: 6)
            } else {
                Text("\(rank)")
                    .font(Font.unbound.monoM)
                    .foregroundStyle(row.boardScore > 0 ? rankColor : Color.unbound.textTertiary)
                    .monospacedDigit()
            }
        }
        .frame(width: isPodium ? 38 : 34, height: isPodium ? 38 : 34)
    }

    /// Thin score bar so relative standing reads at a glance (no pills).
    private var scoreBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.unbound.border.opacity(0.7))
                Capsule()
                    .fill(rankColor.opacity(isPodium ? 0.9 : 0.5))
                    .frame(width: max(proxy.size.width * scoreFraction, row.boardScore > 0 ? 6 : 0))
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Season rewards (SEASON tab) — two themed, art-free emblems

struct SquadSeasonRewardsView: View {
    let rewards: [SquadSeasonReward]
    let season: SquadSeason
    var showsHeader: Bool = true

    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsHeader {
                HStack(spacing: 8) {
                    Text("Two to earn this season")
                        .font(Font.unbound.bodyS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                    Spacer(minLength: 0)
                    SquadInfoButton(isOn: $showInfo, tint: Color.unbound.impact)
                }
            }
            if showInfo {
                SquadInfoText(text: "The board leader takes the season title. Hold the crew streak together to unlock the border.")
            }

            ForEach(rewards) { reward in
                SquadSeasonRewardRow(reward: reward)
            }
        }
    }
}

struct SquadSeasonRewardRow: View {
    let reward: SquadSeasonReward

    private var kindLabel: String {
        switch reward.kind {
        case .individualTitle: return "Title"
        case .squadBadge: return "Squad badge"
        case .squadCosmetic: return "Border"
        }
    }

    private var goalCopy: String {
        switch reward.id {
        case "season-winner-title": return "Top the season board"
        case "season-aura-border": return "Hold a \(reward.target)-week crew streak"
        default: return reward.rewardName
        }
    }

    private var accent: Color {
        reward.kind == .individualTitle ? Color.unbound.rankGold : Color.unbound.ember
    }

    var body: some View {
        HStack(spacing: 14) {
            emblem

            VStack(alignment: .leading, spacing: 2) {
                Text(reward.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                MetaLine([
                    kindLabel,
                    goalCopy,
                    reward.usesProgress ? "\(reward.progress)/\(reward.target)" : nil
                ])
            }

            Spacer(minLength: 12)

            if reward.isUnlocked {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.unbound.success)
            } else if reward.usesProgress {
                miniProgress
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if reward.isUnlocked { return "\(reward.title), unlocked" }
        if reward.usesProgress { return "\(reward.title), \(reward.progress) of \(reward.target)" }
        return reward.title
    }

    /// Rank-badge treatment: the emblem art carries its own frame + glow on
    /// transparency, so we render it straight like `AttributeRankBadge`. Locked
    /// rewards desaturate slightly. Falls back to a themed symbol if art is absent.
    @ViewBuilder
    private var emblem: some View {
        Group {
            if let assetName = reward.assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    Circle().fill(accent.opacity(0.16))
                    Image(systemName: reward.iconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(accent)
                }
            }
        }
        .frame(width: 52, height: 52)
        .saturation(reward.isUnlocked || !reward.usesProgress ? 1 : 0.5)
        .opacity(reward.isUnlocked || !reward.usesProgress ? 1 : 0.82)
    }

    private var miniProgress: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.unbound.border)
                Capsule()
                    .fill(accent)
                    .frame(width: max(proxy.size.width * reward.progressFraction, reward.progress > 0 ? 4 : 0))
            }
        }
        .frame(width: 48, height: 5)
    }
}

#Preview("Season board") {
    let squadId = UUID()
    let me = UUID()
    func member(_ name: String, _ id: UUID = UUID()) -> SquadMember {
        SquadMember(id: UUID(), squadId: squadId, userId: id, joinedAt: .now, displayName: name, equippedTitle: nil, buildIdentity: nil)
    }
    func row(_ name: String, _ id: UUID, days: Int, wins: Int, prs: Int, weekly: Int) -> SquadBoardRow {
        SquadBoardRow(
            member: member(name, id),
            displayName: name,
            profileUserId: id.uuidString,
            seasonWorkoutDays: days,
            seasonChallengeWins: wins,
            seasonPRs: prs,
            weeklySessions: weekly,
            currentStreak: 3,
            bestStreak: 6,
            activeChallenges: 1,
            totalSessions: 40,
            latestWorkoutAt: .now
        )
    }
    let rows = [
        row("Mara", UUID(), days: 18, wins: 3, prs: 4, weekly: 4),
        row("You", me, days: 15, wins: 2, prs: 5, weekly: 3),
        row("Kenji", UUID(), days: 9, wins: 1, prs: 1, weekly: 0)
    ]

    return ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            SquadStreakHeroView(
                squad: Squad(id: squadId, name: "Night Crew", captainId: me, affinityAxis: .power, affinitySetAt: .now, inviteCode: "ABC123", maxSize: 10, squadStreakWeeks: 6, createdAt: .now),
                rows: rows,
                season: .current()
            )
            SquadBoardView(rows: rows, season: .current(), capacity: 10, currentMemberUserId: me)
            SquadSeasonRewardsView(
                rewards: SquadSeasonRewardsBuilder.makeRewards(squad: Squad(id: squadId, name: "Night Crew", captainId: me, affinityAxis: .power, affinitySetAt: .now, inviteCode: "ABC123", maxSize: 10, squadStreakWeeks: 6, createdAt: .now), rows: rows, season: .current()),
                season: .current()
            )
        }
        .padding(20)
    }
    .background(Color.unbound.bg)
}
