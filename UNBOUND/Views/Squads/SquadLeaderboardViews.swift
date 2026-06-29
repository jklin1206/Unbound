import SwiftUI

struct SquadStreakHeroView: View {
    let squad: Squad
    let rows: [SquadBoardRow]
    let season: SquadSeason

    private var protectedToday: Bool {
        rows.contains { row in
            guard let latest = row.latestWorkoutAt else { return false }
            return Calendar.current.isDateInToday(latest)
        }
    }

    private var weeklySupportCount: Int {
        rows.filter { $0.weeklySessions > 0 }.count
    }

    private var statusText: String {
        protectedToday ? "PROTECTED TODAY" : "NEEDS A WORKOUT"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.unbound.warnOrange.opacity(0.14))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(Color.unbound.warnOrange)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    Text("SQUAD STREAK")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(squad.squadStreakWeeks == 0 ? "STARTING" : "\(squad.squadStreakWeeks) WEEKS")
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                    Text(statusText)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(protectedToday ? Color.unbound.accent : Color.unbound.warnOrange)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                supportPill(value: "\(weeklySupportCount)/\(max(rows.count, 1))", label: "SUPPORT", tint: Color.unbound.accent)
                supportPill(value: "\(season.daysRemaining())D", label: "SEASON", tint: Color.unbound.warnOrange)
                supportPill(value: "\(rows.filter { $0.activeChallenges > 0 }.count)", label: "LIVE", tint: Color.unbound.accent)
            }

            if !rows.isEmpty {
                VStack(spacing: 8) {
                    ForEach(sortedRows) { row in
                        SquadStreakSupportRow(row: row)
                    }
                }

                accountabilitySummary
            }
        }
        .padding(16)
        .leaderboardPanel(tint: protectedToday ? Color.unbound.accent : Color.unbound.warnOrange)
    }

    // Surface who has trained, sinking the un-covered to the bottom where the
    // warn styling reads as a callout rather than a wall of red.
    private var sortedRows: [SquadBoardRow] {
        rows.sorted { lhs, rhs in
            let pl = supportPriority(lhs)
            let pr = supportPriority(rhs)
            if pl != pr { return pl < pr }
            return lhs.weeklySessions > rhs.weeklySessions
        }
    }

    private func supportPriority(_ row: SquadBoardRow) -> Int {
        if let latest = row.latestWorkoutAt, Calendar.current.isDateInToday(latest) { return 0 }
        if row.weeklySessions > 0 { return 1 }
        return 2
    }

    private var behindCount: Int {
        rows.filter { $0.weeklySessions == 0 }.count
    }

    private var accountabilitySummary: some View {
        let allCovered = behindCount == 0
        let tint = allCovered ? Color.unbound.success : Color.unbound.warnOrange
        return HStack(spacing: 8) {
            Image(systemName: allCovered ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(tint)
            Text(allCovered
                 ? "Whole squad covered this week"
                 : "\(behindCount) behind — protect the streak")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(tint.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(tint.opacity(0.28), lineWidth: 1))
    }

    private func supportPill(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(Capsule().fill(tint.opacity(0.10)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 1))
    }
}

private struct SquadStreakSupportRow: View {
    let row: SquadBoardRow

    private var supportedThisWeek: Bool { row.weeklySessions > 0 }
    private var workedToday: Bool {
        guard let latest = row.latestWorkoutAt else { return false }
        return Calendar.current.isDateInToday(latest)
    }
    private var isBehind: Bool { !supportedThisWeek }

    private var icon: String {
        workedToday ? "checkmark.seal.fill" : (supportedThisWeek ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
    }
    private var iconTint: Color {
        workedToday ? Color.unbound.accent : (supportedThisWeek ? Color.unbound.textSecondary : Color.unbound.warnOrange)
    }
    private var statusText: String {
        workedToday ? "TODAY" : (supportedThisWeek ? "COVERED" : "0 THIS WEEK")
    }
    private var statusTint: Color {
        workedToday ? Color.unbound.accent : (supportedThisWeek ? Color.unbound.textTertiary : Color.unbound.warnOrange)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(iconTint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(row.displayName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                if isBehind {
                    Text("streak at risk")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(Color.unbound.warnOrange.opacity(0.9))
                }
            }

            Spacer(minLength: 0)

            Text(statusText)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(statusTint)
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 40)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(isBehind ? Color.unbound.warnOrange.opacity(0.08) : Color.unbound.bg.opacity(0.38))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(isBehind ? Color.unbound.warnOrange.opacity(0.30) : Color.unbound.borderSubtle, lineWidth: 1)
        )
    }
}

struct SquadBoardView: View {
    let rows: [SquadBoardRow]
    let season: SquadSeason
    var capacity: Int = 10
    var inviteURL: URL?

    private var hasActivity: Bool { rows.contains { $0.boardScore > 0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                boardHeader("SEASON LEADERBOARD", icon: "trophy.fill")
                Spacer()
                crewCapacityPill
                boardMetaPill(season.title.uppercased(), tint: Color.unbound.warnOrange)
            }

            if rows.isEmpty {
                SquadLeaderboardEmptyRow(text: "No one's on the board yet. First session sets the pace.", icon: "trophy")
            } else if hasActivity, let leader = rows.first {
                leaderCard(leader)
            } else {
                boardOpenCard
            }

            if !rows.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        SquadBoardRowView(position: index + 1, row: row)
                    }
                }
            }
        }
        .padding(14)
        .leaderboardPanel(tint: Color.unbound.warnOrange)
    }

    // Just-formed / no-activity board — never crown a 0-pt leader.
    private var boardOpenCard: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.unbound.warnOrange.opacity(0.14))
                Image(systemName: "flag.checkered")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.unbound.warnOrange)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text("BOARD IS OPEN")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("First to log sets the pace — a workout day is 10 pts.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.warnOrange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.warnOrange.opacity(0.24), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var crewCapacityPill: some View {
        if let inviteURL {
            ShareLink(item: inviteURL) {
                boardMetaPill("\(rows.count)/\(capacity) CREW", tint: Color.unbound.accent)
            }
                .buttonStyle(.plain)
        } else {
            boardMetaPill("\(rows.count)/\(capacity) CREW", tint: Color.unbound.accent)
        }
    }

    private func boardMetaPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .tracking(1.0)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(Capsule().fill(tint.opacity(0.11)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.24), lineWidth: 1))
    }

    private func leaderCard(_ row: SquadBoardRow) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.unbound.warnOrange.opacity(0.16))
                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.unbound.warnOrange)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.displayName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                Text("CURRENT LEADER")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(row.boardScore)")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                Text("PTS")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.warnOrange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.warnOrange.opacity(0.28), lineWidth: 1)
        )
    }

    private func boardHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.unbound.warnOrange)
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }
}

struct SquadSeasonRewardsView: View {
    let rewards: [SquadSeasonReward]
    let season: SquadSeason
    var showsHeader = true

    private var progressRewards: [SquadSeasonReward] {
        rewards.filter(\.usesProgress)
    }

    private var unlockedCount: Int {
        progressRewards.filter(\.isUnlocked).count
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsHeader {
                HStack(alignment: .firstTextBaseline) {
                    boardHeader("SEASON REWARDS", icon: "rosette")
                    Spacer()
                    Text("\(unlockedCount)/\(progressRewards.count) UNLOCKED")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.accent)
                }
            }

            HStack(spacing: 8) {
                seasonPill(value: season.title.uppercased(), label: "SEASON")
                seasonPill(value: "\(season.daysRemaining())D", label: "LEFT")
                seasonPill(value: "3MO", label: "RESET")
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(rewards) { reward in
                    SquadSeasonRewardTile(reward: reward)
                }
            }
        }
    }

    private func boardHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    private func seasonPill(value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(Capsule().fill(Color.unbound.surface.opacity(0.74)))
        .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
    }
}

private struct SquadSeasonRewardTile: View {
    let reward: SquadSeasonReward

    private var tint: Color {
        switch reward.kind {
        case .individualTitle:
            return Color.unbound.warnOrange
        case .squadBadge:
            return Color.unbound.accent
        case .squadCosmetic:
            return Color.unbound.warnOrange
        }
    }

    private var kindLabel: String {
        switch reward.kind {
        case .individualTitle:
            return "TITLE"
        case .squadBadge:
            return "BADGE"
        case .squadCosmetic:
            return "COSMETIC"
        }
    }

    private var statusText: String {
        guard reward.usesProgress else { return "SEASON END" }
        return reward.isUnlocked ? "UNLOCKED" : "\(reward.remaining) TO GO"
    }

    private var awardCopy: String? {
        reward.kind == .individualTitle ? "Awarded to #1 at season end" : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.14))
                    if let assetName = reward.assetName {
                        Image(assetName)
                            .resizable()
                            .scaledToFit()
                            .padding(3)
                            .shadow(color: tint.opacity(0.28), radius: 8)
                    } else {
                        Image(systemName: reward.iconName)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(reward.title.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(0.9)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                    Text(reward.rewardName)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)
            }

            if reward.usesProgress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.unbound.bg.opacity(0.58))
                        Capsule()
                            .fill(tint)
                            .frame(width: geo.size.width * CGFloat(reward.progressFraction))
                    }
                }
                .frame(height: 6)
            } else if let awardCopy {
                Text(awardCopy)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            HStack(spacing: 6) {
                if reward.usesProgress {
                    Text("\(reward.progress)/\(reward.target)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                } else {
                    Text("TOP 1")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer(minLength: 0)
                Text(statusText)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(reward.isUnlocked ? Color.unbound.accent : tint)
            }

            Text(kindLabel)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(Capsule().fill(tint.opacity(0.11)))
                .overlay(Capsule().strokeBorder(tint.opacity(0.24), lineWidth: 1))
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(reward.isUnlocked ? tint.opacity(0.42) : Color.unbound.borderSubtle, lineWidth: 1)
        )
    }
}

private struct SquadBoardRowView: View {
    let position: Int
    let row: SquadBoardRow

    private var hasScore: Bool { row.boardScore > 0 }

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            Text("\(position)")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(position <= 3 && hasScore ? Color.unbound.warnOrange : Color.unbound.textTertiary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.unbound.bg.opacity(0.54)))
                .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(row.displayName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(hasScore ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if hasScore {
                    HStack(spacing: 8) {
                        scoreChip(value: "\(row.seasonWorkoutDays)", label: "DAYS")
                        scoreChip(value: "\(row.seasonChallengeWins)", label: "WINS")
                        scoreChip(value: "\(row.seasonPRs)", label: "PRS")
                    }
                } else {
                    Text("Hasn't logged this season")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(row.boardScore)")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(hasScore ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                    .monospacedDigit()
                Text("PTS")
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .frame(width: 52, alignment: .trailing)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface.opacity(hasScore ? 0.78 : 0.40))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(position == 1 && hasScore ? Color.unbound.warnOrange.opacity(0.35) : Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func scoreChip(value: String, label: String) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
            Text(label)
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .lineLimit(1)
    }
}

private struct SquadLeaderboardEmptyRow: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.unbound.surface.opacity(0.72)))
            Text(text)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.unbound.surface.opacity(0.52)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
    }
}

private struct SquadLeaderboardPanelStyle: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.10),
                                Color.unbound.surface.opacity(0.90),
                                Color.unbound.bg.opacity(0.66)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                tint.opacity(0.26),
                                Color.unbound.borderSubtle
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

private extension View {
    func leaderboardPanel(tint: Color) -> some View {
        modifier(SquadLeaderboardPanelStyle(tint: tint))
    }
}
