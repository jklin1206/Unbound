import Foundation

struct SquadSeason: Equatable, Sendable {
    let title: String
    let interval: DateInterval

    var start: Date { interval.start }
    var end: Date { interval.end }
    var seasonNumber: Int {
        let tokens = title.split(separator: " ")
        guard let firstToken = tokens.first else { return 1 }
        let token = String(firstToken).trimmingCharacters(in: .whitespacesAndNewlines)
        if token.lowercased() == "season" {
            return tokens.dropFirst().compactMap { Int($0) }.first ?? 1
        }
        if token.lowercased().hasPrefix("season") {
            let suffix = token.dropFirst("season".count)
            return Int(suffix) ?? 1
        }
        if token.lowercased().hasPrefix("s") {
            return Int(token.dropFirst()) ?? 1
        }
        return 1
    }
    var winnerTitleID: TitleID { .squadSeasonWinner(seasonNumber) }
    var winnerTitleName: String { "Season \(seasonNumber) Winner" }
    var winnerTitleAssetName: String? {
        winnerTitleID.rewardAssetName
    }

    static func current(now: Date = Date(), calendar input: Calendar = .current) -> SquadSeason {
        var calendar = input
        calendar.timeZone = input.timeZone
        let components = calendar.dateComponents([.year, .month], from: now)
        let month = components.month ?? 1
        let quarter = ((month - 1) / 3) + 1
        let quarterStartMonth = ((month - 1) / 3) * 3 + 1

        var startComponents = DateComponents()
        startComponents.calendar = calendar
        startComponents.year = components.year
        startComponents.month = quarterStartMonth
        startComponents.day = 1

        let start = calendar.date(from: startComponents) ?? calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .month, value: 3, to: start)
            ?? calendar.date(byAdding: .day, value: 90, to: start)
            ?? now
        return SquadSeason(title: "S\(quarter) \(components.year ?? 0)", interval: DateInterval(start: start, end: end))
    }

    static func previous(endingBefore now: Date = Date(), calendar input: Calendar = .current) -> SquadSeason {
        var calendar = input
        calendar.timeZone = input.timeZone
        let current = SquadSeason.current(now: now, calendar: calendar)
        let previousStart = calendar.date(byAdding: .month, value: -3, to: current.start)
            ?? calendar.date(byAdding: .day, value: -90, to: current.start)
            ?? current.start
        let components = calendar.dateComponents([.year, .month], from: previousStart)
        let month = components.month ?? 1
        let quarter = ((month - 1) / 3) + 1
        return SquadSeason(
            title: "S\(quarter) \(components.year ?? 0)",
            interval: DateInterval(start: previousStart, end: current.start)
        )
    }

    func daysRemaining(from now: Date = Date(), calendar: Calendar = .current) -> Int {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfEnd = calendar.startOfDay(for: end)
        return max(0, calendar.dateComponents([.day], from: startOfToday, to: startOfEnd).day ?? 0)
    }

    func weekTarget(calendar: Calendar = .current) -> Int {
        let days = max(1, calendar.dateComponents([.day], from: start, to: end).day ?? 90)
        return max(1, Int(ceil(Double(days) / 7.0)))
    }
}

struct SquadStreakSummary: Equatable, Sendable {
    var current: Int
    var best: Int
    var weeklyCount: Int
    var totalSessions: Int
    var latestWorkoutAt: Date?

    static let empty = SquadStreakSummary(
        current: 0,
        best: 0,
        weeklyCount: 0,
        totalSessions: 0,
        latestWorkoutAt: nil
    )
}

struct SquadBoardRow: Identifiable, Equatable, Sendable {
    var id: UUID { member.userId }
    let member: SquadMember
    let displayName: String
    let profileUserId: String
    let seasonWorkoutDays: Int
    let seasonChallengeWins: Int
    let seasonPRs: Int
    let weeklySessions: Int
    let currentStreak: Int
    let bestStreak: Int
    let activeChallenges: Int
    let totalSessions: Int
    let latestWorkoutAt: Date?

    var boardScore: Int {
        seasonWorkoutDays * 10
            + seasonChallengeWins * 15
            + seasonPRs * 10
    }
}

struct SquadSeasonWinnerTitleAward: Equatable, Sendable {
    let titleId: TitleID
    let titleName: String
    let memberUserId: UUID
    let profileUserId: String
    let displayName: String
    let boardScore: Int
    let assetName: String?
}

struct SquadSeasonReward: Identifiable, Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case individualTitle
        case squadBadge
        case squadCosmetic
    }

    let id: String
    let title: String
    let rewardName: String
    let kind: Kind
    let iconName: String
    let assetName: String?
    let progress: Int
    let target: Int
    let titleId: TitleID?

    init(
        id: String,
        title: String,
        rewardName: String,
        kind: Kind,
        iconName: String,
        assetName: String? = nil,
        progress: Int,
        target: Int,
        titleId: TitleID? = nil
    ) {
        self.id = id
        self.title = title
        self.rewardName = rewardName
        self.kind = kind
        self.iconName = iconName
        self.assetName = assetName
        self.progress = progress
        self.target = target
        self.titleId = titleId
    }

    var usesProgress: Bool {
        target > 0
    }

    var isUnlocked: Bool {
        usesProgress && progress >= target
    }

    var remaining: Int {
        max(0, target - progress)
    }

    var progressFraction: Double {
        guard usesProgress else { return 0 }
        return min(1, Double(progress) / Double(target))
    }
}

@MainActor
enum SquadSeasonRewardsBuilder {
    static func makeRewards(
        squad: Squad,
        rows: [SquadBoardRow],
        season: SquadSeason = .current(),
        missionsCompleted: Int = 0
    ) -> [SquadSeasonReward] {
        let challengeWins = rows.reduce(0) { $0 + $1.seasonChallengeWins }
        let seasonPRs = rows.reduce(0) { $0 + $1.seasonPRs }
        let rosterTarget = max(3, rows.count)
        let fullSeasonStreakTarget = min(12, max(1, season.weekTarget()))
        let winnerAward = SquadLeaderboardBuilder.winnerTitleAward(rows: rows, season: season)

        return [
            SquadSeasonReward(
                id: "season-winner-title",
                title: season.winnerTitleName,
                rewardName: winnerAward.map { "Current leader: \($0.displayName)" } ?? "Awarded at season end",
                kind: .individualTitle,
                iconName: "rosette",
                assetName: season.winnerTitleAssetName,
                progress: 0,
                target: 0,
                titleId: winnerAward?.titleId ?? season.winnerTitleID
            ),
            SquadSeasonReward(
                id: "streak-crest",
                title: "Streak Crest",
                rewardName: "Squad badge",
                kind: .squadBadge,
                iconName: "shield.lefthalf.filled",
                assetName: "squad_reward_streak_crest",
                progress: min(squad.squadStreakWeeks, 4),
                target: 4
            ),
            SquadSeasonReward(
                id: "rival-banner",
                title: "Rival Banner",
                rewardName: "Squad cosmetic",
                kind: .squadCosmetic,
                iconName: "flag.checkered",
                assetName: "squad_reward_rival_banner",
                progress: min(challengeWins, 5),
                target: 5
            ),
            SquadSeasonReward(
                id: "pr-relic",
                title: "PR Relic",
                rewardName: "Squad badge",
                kind: .squadBadge,
                iconName: "bolt.badge.checkmark.fill",
                assetName: "squad_reward_pr_relic",
                progress: min(seasonPRs, rosterTarget),
                target: rosterTarget
            ),
            SquadSeasonReward(
                id: "season-aura",
                title: "Season Aura",
                rewardName: "Squad cosmetic",
                kind: .squadCosmetic,
                iconName: "sparkles",
                assetName: "squad_reward_season_aura",
                progress: min(squad.squadStreakWeeks, fullSeasonStreakTarget),
                target: fullSeasonStreakTarget
            ),
            SquadSeasonReward(
                id: "squad-missions",
                title: "Squad Missions",
                rewardName: "Season milestone",
                kind: .squadBadge,
                iconName: "flag.2.crossed.fill",
                assetName: nil,
                progress: min(missionsCompleted, 4),
                target: 4
            )
        ]
    }
}

@MainActor
enum SquadLeaderboardBuilder {
    private static let maxPRBonusesPerWeek = 2

    static func winnerTitleAward(
        rows: [SquadBoardRow],
        season: SquadSeason = .current()
    ) -> SquadSeasonWinnerTitleAward? {
        guard let winner = rows.first else { return nil }
        return SquadSeasonWinnerTitleAward(
            titleId: season.winnerTitleID,
            titleName: season.winnerTitleName,
            memberUserId: winner.member.userId,
            profileUserId: winner.profileUserId,
            displayName: winner.displayName,
            boardScore: winner.boardScore,
            assetName: season.winnerTitleAssetName
        )
    }

    static func claimableWinnerTitleAward(
        rows: [SquadBoardRow],
        season: SquadSeason,
        currentUserId: String,
        currentMemberUserId: UUID?,
        now: Date = Date()
    ) -> SquadSeasonWinnerTitleAward? {
        guard now >= season.end else { return nil }
        guard let award = winnerTitleAward(rows: rows, season: season) else { return nil }
        if currentMemberUserId == award.memberUserId { return award }
        if award.profileUserId.caseInsensitiveCompare(currentUserId) == .orderedSame { return award }
        return nil
    }

    static func makeBoardRows(
        roster: [SquadMember],
        displayNames: [UUID: String],
        profileUserIds: [UUID: String],
        workoutLogs: [UUID: [WorkoutLog]],
        sessionRecords: [UUID: SessionXPRecord],
        challengeStats: [UUID: FriendChallengeStats],
        season: SquadSeason = .current()
    ) -> [SquadBoardRow] {
        roster
            .map { member in
                let logs = workoutLogs[member.userId] ?? []
                let xp = sessionRecords[member.userId]
                let streak = streakSummary(logs: logs, xpRecord: xp)
                let stats = challengeStats[member.userId] ?? .empty
                return SquadBoardRow(
                    member: member,
                    displayName: displayNames[member.userId] ?? member.displayName,
                    profileUserId: profileUserIds[member.userId] ?? member.userId.uuidString,
                    seasonWorkoutDays: workoutDays(in: logs, season: season),
                    seasonChallengeWins: stats.seasonWins,
                    seasonPRs: seasonPRCount(in: logs, season: season),
                    weeklySessions: streak.weeklyCount,
                    currentStreak: streak.current,
                    bestStreak: streak.best,
                    activeChallenges: stats.activeCount,
                    totalSessions: streak.totalSessions,
                    latestWorkoutAt: streak.latestWorkoutAt
                )
            }
            .sorted { lhs, rhs in
                if lhs.boardScore != rhs.boardScore { return lhs.boardScore > rhs.boardScore }
                if lhs.seasonChallengeWins != rhs.seasonChallengeWins { return lhs.seasonChallengeWins > rhs.seasonChallengeWins }
                if lhs.seasonPRs != rhs.seasonPRs { return lhs.seasonPRs > rhs.seasonPRs }
                if lhs.seasonWorkoutDays != rhs.seasonWorkoutDays { return lhs.seasonWorkoutDays > rhs.seasonWorkoutDays }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    static func streakSummary(
        logs: [WorkoutLog],
        xpRecord: SessionXPRecord? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SquadStreakSummary {
        let sortedLogs = logs.sorted { ($0.completedAt ?? $0.startedAt) > ($1.completedAt ?? $1.startedAt) }
        let dates = sortedLogs.map { $0.completedAt ?? $0.startedAt }
        let latest = dates.first
        let weekInterval = currentWeekInterval(containing: now, calendar: calendar)
        let weeklyFromLogs = dates
            .map { calendar.startOfDay(for: $0) }
            .filter { weekInterval.contains($0) }
        let derived = deriveStreaks(from: dates, now: now, calendar: calendar)

        return SquadStreakSummary(
            current: max(xpRecord?.currentStreak ?? 0, derived.current),
            best: max(xpRecord?.longestStreak ?? 0, derived.best),
            weeklyCount: max(xpRecord?.weeklyCount ?? 0, Set(weeklyFromLogs).count),
            totalSessions: max(xpRecord?.totalSessions ?? 0, logs.count),
            latestWorkoutAt: latest
        )
    }

    private static func workoutDays(
        in logs: [WorkoutLog],
        season: SquadSeason,
        calendar: Calendar = .current
    ) -> Int {
        Set(
            logs
                .map { $0.completedAt ?? $0.startedAt }
                .filter { season.interval.contains($0) }
                .map { calendar.startOfDay(for: $0) }
        ).count
    }

    private static func seasonPRCount(
        in logs: [WorkoutLog],
        season: SquadSeason,
        calendar: Calendar = .current
    ) -> Int {
        let candidates = logs
            .flatMap(prCandidates)
            .sorted { $0.date < $1.date }
        var bestByKey: [PRMetricKey: Double] = [:]
        var countedKeysByDay = Set<String>()
        var weeklyCounts: [Date: Int] = [:]
        var count = 0

        for candidate in candidates {
            let previous = bestByKey[candidate.key]
            if season.interval.contains(candidate.date),
               let previous,
               candidate.score > previous,
               weeklyCounts[currentWeekInterval(containing: candidate.date, calendar: calendar).start, default: 0] < maxPRBonusesPerWeek {
                let day = calendar.startOfDay(for: candidate.date)
                let dailyKey = "\(day.timeIntervalSince1970)-\(candidate.key.rawValue)"
                if !countedKeysByDay.contains(dailyKey) {
                    countedKeysByDay.insert(dailyKey)
                    let weekStart = currentWeekInterval(containing: candidate.date, calendar: calendar).start
                    weeklyCounts[weekStart, default: 0] += 1
                    count += 1
                }
            }
            bestByKey[candidate.key] = max(previous ?? candidate.score, candidate.score)
        }

        return count
    }

    private struct PRCandidate {
        let key: PRMetricKey
        let score: Double
        let date: Date
    }

    private enum PRMetricKey: Hashable {
        case weighted(String)
        case duration(String)
        case reps(String)

        var rawValue: String {
            switch self {
            case .weighted(let id): return "weighted:\(id)"
            case .duration(let id): return "duration:\(id)"
            case .reps(let id): return "reps:\(id)"
            }
        }
    }

    private static func prCandidates(from log: WorkoutLog) -> [PRCandidate] {
        let date = log.completedAt ?? log.startedAt
        return log.exerciseEntries.flatMap { entry -> [PRCandidate] in
            let movementKey = normalizedMovementKey(for: entry)
            return entry.sets
                .filter { !$0.isWarmup && $0.isProofEligible && !$0.effectiveQualityFlags.contains(.assisted) }
                .compactMap { set -> PRCandidate? in
                    if let weight = set.weightKg, weight > 0, set.reps > 0 {
                        let estimated = weight * (1 + Double(set.reps) / 30.0)
                        return PRCandidate(key: .weighted(movementKey), score: estimated, date: date)
                    }
                    if let seconds = set.durationSeconds, seconds > 0 {
                        return PRCandidate(key: .duration(movementKey), score: Double(seconds), date: date)
                    }
                    if set.reps > 0 {
                        return PRCandidate(key: .reps(movementKey), score: Double(set.reps), date: date)
                    }
                    return nil
                }
        }
    }

    private static func normalizedMovementKey(for entry: ExerciseLogEntry) -> String {
        if let standard = entry.rankStandardMovementId, !standard.isEmpty {
            return standard
        }
        if let movement = entry.movementId, !movement.isEmpty {
            return movement
        }
        return MovementCatalog.normalized(entry.exerciseName)
    }

    private static func deriveStreaks(
        from dates: [Date],
        now: Date,
        calendar: Calendar
    ) -> (current: Int, best: Int) {
        let days = Array(Set(dates.map { calendar.startOfDay(for: $0) })).sorted()
        guard let first = days.first else { return (0, 0) }

        var best = 1
        var run = 1
        var previous = first

        for day in days.dropFirst() {
            let decision = ProgramAwareStreakPolicy.shouldExtendStreak(
                from: previous,
                to: day,
                currentStreak: run,
                calendar: calendar
            )
            run = decision.broken ? 1 : decision.streak
            best = max(best, run)
            previous = day
        }

        let latest = days.last ?? first
        let gapToNow = calendar.dateComponents(
            [.day],
            from: latest,
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        let current = gapToNow <= ProgramAwareStreakPolicy.maxGapDays ? run : 0
        return (current, best)
    }

    private static func currentWeekInterval(
        containing date: Date,
        calendar input: Calendar
    ) -> DateInterval {
        var calendar = input
        calendar.firstWeekday = 2
        return calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 7 * 24 * 60 * 60)
    }
}
