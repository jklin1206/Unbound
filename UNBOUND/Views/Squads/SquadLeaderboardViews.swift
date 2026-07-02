// UNBOUND/Views/Squads/SquadLeaderboardViews.swift
//
// Season-board surfaces as tinted section cards: the squad streak (ember),
// the leaderboard with gold/silver/bronze ranks, and the season rewards with
// plain-language goals. The viewer's own board row highlights full-width
// without shifting text.
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
        SquadSectionCard(
            title: "SQUAD STREAK",
            icon: "flame.fill",
            tint: Color.unbound.ember
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(squad.squadStreakWeeks)")
                        .font(Font.unbound.monoL)
                        .foregroundStyle(squad.squadStreakWeeks > 0 ? Color.unbound.ember : Color.unbound.textPrimary)
                        .monospacedDigit()
                    Text(squad.squadStreakWeeks == 1 ? "week" : "weeks")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }

                weeklyCoverageBar

                MetaLine([
                    "\(weeklySupportCount)/\(max(rows.count, 1)) trained this week",
                    "everyone logs a session to extend it"
                ])
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Squad streak \(squad.squadStreakWeeks) weeks")
    }

    /// One segment per member — filled ember when they trained this week.
    private var weeklyCoverageBar: some View {
        HStack(spacing: 3) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Capsule()
                    .fill(row.weeklySessions > 0 ? Color.unbound.ember : Color.unbound.border)
                    .frame(height: 5)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Season board (SEASON tab)

struct SquadBoardView: View {
    let rows: [SquadBoardRow]
    let season: SquadSeason
    let capacity: Int
    var inviteURL: URL? = nil
    var currentMemberUserId: UUID?

    private var seasonRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        let start = formatter.string(from: season.start)
        let end = formatter.string(from: season.end.addingTimeInterval(-1))
        return "\(start)–\(end)"
    }

    var body: some View {
        SquadSectionCard(
            title: "SEASON BOARD",
            icon: "trophy.fill",
            tint: Color.unbound.rankGold,
            trailing: "\(season.title) · \(seasonRangeText) · \(season.daysRemaining())d left"
        ) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Points all season: 10 per training day, 15 per duel win, 10 per PR. Top of the board when it ends wins the season title.")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 8)

                if rows.isEmpty {
                    Text("No crew on the board yet.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        SquadBoardRowView(
                            rank: index + 1,
                            row: row,
                            isSelf: row.member.userId == currentMemberUserId
                        )
                    }
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
        switch rank {
        case 1: return Color.unbound.rankGold
        case 2: return Color.unbound.rankSilver
        case 3: return Color.unbound.rankBronze
        default: return Color.unbound.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(rankColor.opacity(row.boardScore > 0 ? 0.16 : 0.08))
                Text("\(rank)")
                    .font(Font.unbound.monoM)
                    .foregroundStyle(row.boardScore > 0 ? rankColor : Color.unbound.textTertiary)
                    .monospacedDigit()
            }
            .frame(width: 34, height: 34)

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

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(row.boardScore)")
                    .font(Font.unbound.monoM)
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
}

// MARK: - Season rewards (SEASON tab)

struct SquadSeasonRewardsView: View {
    let rewards: [SquadSeasonReward]
    let season: SquadSeason
    var showsHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Crew goals for \(season.title). Clear them together to unlock squad badges and cosmetics; the board leader takes the season title.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)

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

    private var goalCopy: String {
        switch reward.id {
        case "streak-crest": return "Hold a \(reward.target)-week squad streak"
        case "rival-banner": return "Win \(reward.target) duels as a crew"
        case "pr-relic": return "\(reward.target) PRs across the crew"
        case "season-aura": return "Streak for \(reward.target) straight weeks"
        case "squad-missions": return "Clear \(reward.target) weekly missions"
        default: return reward.rewardName
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
                    goalCopy,
                    reward.usesProgress ? "\(reward.progress)/\(reward.target)" : nil
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
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .saturation(reward.isUnlocked || !reward.usesProgress ? 1 : 0.5)
                .opacity(reward.isUnlocked || !reward.usesProgress ? 1 : 0.8)
        } else {
            ZStack {
                Circle().fill(Color.unbound.impact.opacity(0.16))
                Image(systemName: reward.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.impact)
            }
            .frame(width: 40, height: 40)
        }
    }

    private var miniProgress: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.unbound.border)
                Capsule()
                    .fill(Color.unbound.impact)
                    .frame(width: max(proxy.size.width * reward.progressFraction, reward.progress > 0 ? 4 : 0))
            }
        }
        .frame(width: 44, height: 4)
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
