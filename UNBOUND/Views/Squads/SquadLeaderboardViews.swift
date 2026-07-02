// UNBOUND/Views/Squads/SquadLeaderboardViews.swift
//
// Season-board surfaces in the calm-list language: the squad streak as a
// flat stat block, the leaderboard as plain rows (the viewer's row is the
// one raised surface), and season rewards as quiet progress rows.
import SwiftUI

// MARK: - Squad streak (CREW tab)

struct SquadStreakHeroView: View {
    let squad: Squad
    let rows: [SquadBoardRow]
    let season: SquadSeason

    private var weeklySupportCount: Int {
        rows.filter { $0.weeklySessions > 0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CalmSectionHeader(title: "SQUAD STREAK")
                .padding(.bottom, 6)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(squad.squadStreakWeeks)")
                    .font(Font.unbound.monoL)
                    .foregroundStyle(squad.squadStreakWeeks > 0 ? Color.unbound.accent : Color.unbound.textPrimary)
                    .monospacedDigit()
                Text(squad.squadStreakWeeks == 1 ? "week" : "weeks")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            MetaLine([
                "\(weeklySupportCount)/\(max(rows.count, 1)) trained this week",
                "everyone logs a session to extend it"
            ])
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Squad streak \(squad.squadStreakWeeks) weeks")
    }
}

// MARK: - Season board (SEASON tab)

struct SquadBoardView: View {
    let rows: [SquadBoardRow]
    let season: SquadSeason
    let capacity: Int
    var inviteURL: URL?
    var currentMemberUserId: UUID?

    private var hasActivity: Bool { rows.contains { $0.boardScore > 0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CalmSectionHeader(
                title: "SEASON BOARD",
                trailing: "\(season.title) · \(season.daysRemaining())d left"
            )
            .padding(.bottom, 6)

            if rows.isEmpty {
                Text("No crew on the board yet.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.vertical, 6)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    SquadBoardRowView(
                        rank: index + 1,
                        row: row,
                        isSelf: row.member.userId == currentMemberUserId
                    )
                }

                if !hasActivity {
                    Text("Points come from workout days, challenge wins, and PRs this season.")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
            }
        }
    }
}

struct SquadBoardRowView: View {
    let rank: Int
    let row: SquadBoardRow
    var isSelf: Bool = false

    private var rankColor: Color {
        rank == 1 && row.boardScore > 0 ? Color.unbound.rankGold : Color.unbound.textTertiary
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(Font.unbound.monoM)
                .foregroundStyle(rankColor)
                .monospacedDigit()
                .frame(width: 26, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.displayName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                MetaLine([
                    row.seasonWorkoutDays == 1 ? "1 day" : "\(row.seasonWorkoutDays) days",
                    row.seasonChallengeWins == 1 ? "1 win" : "\(row.seasonChallengeWins) wins",
                    row.seasonPRs == 1 ? "1 PR" : "\(row.seasonPRs) PRs"
                ])
            }

            Spacer(minLength: 12)

            Text("\(row.boardScore)")
                .font(Font.unbound.monoM)
                .foregroundStyle(row.boardScore > 0 ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, isSelf ? 12 : 0)
        .padding(.vertical, 10)
        .activeSurface(isSelf, cornerRadius: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(rank), \(row.displayName), \(row.boardScore) points")
    }
}

// MARK: - Season rewards (SEASON tab)

struct SquadSeasonRewardsView: View {
    let rewards: [SquadSeasonReward]
    let season: SquadSeason
    var showsHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsHeader {
                CalmSectionHeader(title: "SEASON REWARDS")
                    .padding(.bottom, 6)
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
        case .individualTitle: return "title"
        case .squadBadge: return "squad badge"
        case .squadCosmetic: return "cosmetic"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            artwork

            VStack(alignment: .leading, spacing: 2) {
                Text(reward.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                MetaLine([
                    kindLabel,
                    reward.usesProgress ? "\(reward.progress)/\(reward.target)" : reward.rewardName
                ])
            }

            Spacer(minLength: 12)

            if reward.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.unbound.success)
            } else if reward.usesProgress {
                miniProgress
            }
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if reward.isUnlocked { return "\(reward.title), unlocked" }
        if reward.usesProgress { return "\(reward.title), \(reward.progress) of \(reward.target)" }
        return reward.title
    }

    @ViewBuilder
    private var artwork: some View {
        if let assetName = reward.assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .saturation(reward.isUnlocked || !reward.usesProgress ? 1 : 0.35)
                .opacity(reward.isUnlocked || !reward.usesProgress ? 1 : 0.72)
        } else {
            ZStack {
                Circle().fill(Color.unbound.surfaceElevated)
                Image(systemName: reward.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            .frame(width: 34, height: 34)
        }
    }

    private var miniProgress: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.unbound.border)
                Capsule()
                    .fill(Color.unbound.accent)
                    .frame(width: max(proxy.size.width * reward.progressFraction, reward.progress > 0 ? 4 : 0))
            }
        }
        .frame(width: 44, height: 3)
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
        row("Kenji", UUID(), days: 9, wins: 1, prs: 1, weekly: 1)
    ]

    return ScrollView {
        VStack(alignment: .leading, spacing: 28) {
            SquadStreakHeroView(
                squad: Squad(id: squadId, name: "Night Crew", captainId: me, affinityAxis: nil, affinitySetAt: nil, inviteCode: "ABC123", maxSize: 10, squadStreakWeeks: 6, createdAt: .now),
                rows: rows,
                season: .current()
            )
            SquadBoardView(rows: rows, season: .current(), capacity: 10, currentMemberUserId: me)
        }
        .padding(20)
    }
    .background(Color.unbound.bg)
}
