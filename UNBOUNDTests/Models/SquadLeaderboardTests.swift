import XCTest
@testable import UNBOUND

@MainActor
final class SquadLeaderboardTests: XCTestCase {
    func testSeasonScoreCountsOneWorkoutPerDayAndSeasonWins() {
        let season = makeSeason()
        let squadId = UUID()
        let alpha = makeMember(name: "Alpha", squadId: squadId)
        let beta = makeMember(name: "Beta", squadId: squadId)

        let rows = SquadLeaderboardBuilder.makeBoardRows(
            roster: [alpha, beta],
            displayNames: [alpha.userId: "Alpha", beta.userId: "Beta"],
            profileUserIds: [alpha.userId: alpha.userId.uuidString, beta.userId: beta.userId.uuidString],
            workoutLogs: [
                alpha.userId: [
                    makeLog(id: "a1", userId: alpha.userId.uuidString, date: date("2026-01-04")),
                    makeLog(id: "a2", userId: alpha.userId.uuidString, date: date("2026-01-04")),
                    makeLog(id: "a3", userId: alpha.userId.uuidString, date: date("2026-01-05"))
                ],
                beta.userId: [
                    makeLog(id: "b1", userId: beta.userId.uuidString, date: date("2026-01-04"))
                ]
            ],
            sessionRecords: [:],
            challengeStats: [
                alpha.userId: FriendChallengeStats(wins: 4, seasonWins: 1, activeCount: 0, pendingCount: 0),
                beta.userId: FriendChallengeStats(wins: 2, seasonWins: 2, activeCount: 0, pendingCount: 0)
            ],
            season: season
        )

        let alphaRow = try! XCTUnwrap(rows.first { $0.member.userId == alpha.userId })
        let betaRow = try! XCTUnwrap(rows.first { $0.member.userId == beta.userId })

        XCTAssertEqual(alphaRow.seasonWorkoutDays, 2)
        XCTAssertEqual(alphaRow.seasonChallengeWins, 1)
        XCTAssertEqual(alphaRow.boardScore, 35)
        XCTAssertEqual(betaRow.boardScore, 40)
        XCTAssertEqual(rows.first?.member.userId, beta.userId)
    }

    func testSeasonPRBonusIsCappedPerWeek() {
        let season = makeSeason()
        let squadId = UUID()
        let member = makeMember(name: "Alpha", squadId: squadId)
        let userId = member.userId.uuidString

        let logs = [
            makeLog(id: "baseline-bench", userId: userId, date: date("2025-12-31"), entries: [entry("Bench", weight: 100, reps: 5)]),
            makeLog(id: "baseline-squat", userId: userId, date: date("2025-12-31"), entries: [entry("Squat", weight: 120, reps: 5)]),
            makeLog(id: "baseline-deadlift", userId: userId, date: date("2025-12-31"), entries: [entry("Deadlift", weight: 150, reps: 5)]),
            makeLog(id: "bench-pr", userId: userId, date: date("2026-01-06"), entries: [entry("Bench", weight: 105, reps: 5)]),
            makeLog(id: "squat-pr", userId: userId, date: date("2026-01-07"), entries: [entry("Squat", weight: 125, reps: 5)]),
            makeLog(id: "deadlift-pr", userId: userId, date: date("2026-01-08"), entries: [entry("Deadlift", weight: 155, reps: 5)])
        ]

        let rows = SquadLeaderboardBuilder.makeBoardRows(
            roster: [member],
            displayNames: [member.userId: "Alpha"],
            profileUserIds: [member.userId: userId],
            workoutLogs: [member.userId: logs],
            sessionRecords: [:],
            challengeStats: [:],
            season: season
        )

        XCTAssertEqual(rows.first?.seasonPRs, 2)
        XCTAssertEqual(rows.first?.boardScore, 50)
    }

    func testSeasonRewardsUseSharedSeasonSignals() {
        let season = makeSeason()
        let squadId = UUID()
        let alpha = makeMember(name: "Alpha", squadId: squadId)
        let beta = makeMember(name: "Beta", squadId: squadId)
        let squad = makeSquad(id: squadId, captainId: alpha.userId, streakWeeks: 4)
        let rows = [
            makeRow(member: alpha, wins: 3, prs: 1),
            makeRow(member: beta, wins: 2, prs: 2)
        ]

        let rewards = SquadSeasonRewardsBuilder.makeRewards(
            squad: squad,
            rows: rows,
            season: season
        )

        let titleReward = reward("season-winner-title", in: rewards)
        XCTAssertEqual(titleReward.title, "Season 1 Winner")
        XCTAssertEqual(titleReward.rewardName, "Current leader: Alpha")
        XCTAssertEqual(titleReward.kind, .individualTitle)
        XCTAssertFalse(titleReward.usesProgress)
        XCTAssertEqual(titleReward.assetName, "squad_reward_season_1_winner")
        XCTAssertEqual(titleReward.titleId, .squadSeasonWinner(1))

        XCTAssertTrue(reward("streak-crest", in: rewards).isUnlocked)
        XCTAssertTrue(reward("rival-banner", in: rewards).isUnlocked)
        XCTAssertTrue(reward("pr-relic", in: rewards).isUnlocked)
        XCTAssertEqual(reward("season-aura", in: rewards).target, 12)
        XCTAssertFalse(reward("season-aura", in: rewards).isUnlocked)
    }

    func testSeasonWinnerTitleDisplayUsesSeasonNumber() {
        let first = SquadSeason(
            title: "S1 2026",
            interval: DateInterval(start: date("2026-01-01"), end: date("2026-04-01"))
        )
        let second = SquadSeason(
            title: "Season 2",
            interval: DateInterval(start: date("2026-04-01"), end: date("2026-07-01"))
        )

        XCTAssertEqual(first.winnerTitleID, .squadSeasonWinner(1))
        XCTAssertEqual(first.winnerTitleName, "Season 1 Winner")
        XCTAssertEqual(first.winnerTitleAssetName, "squad_reward_season_1_winner")
        XCTAssertEqual(first.winnerTitleID.rewardAssetName, "squad_reward_season_1_winner")
        XCTAssertEqual(TitleCatalog.displayName(for: second.winnerTitleID), "Season 2 Winner")
        XCTAssertNil(second.winnerTitleAssetName)
    }

    func testCurrentSeasonUsesLaunchAnchor() {
        let season = SquadSeason.current(now: date("2026-06-28"), calendar: utcCalendar)

        XCTAssertEqual(season.title, "Season 1")
        XCTAssertEqual(season.winnerTitleName, "Season 1 Winner")
        XCTAssertEqual(season.start, date("2026-04-01"))
        XCTAssertEqual(season.end, date("2026-07-01"))
    }

    func testPreviousSeasonClampsBeforeSeasonTwo() {
        let previous = SquadSeason.previous(endingBefore: date("2026-06-07"), calendar: utcCalendar)

        XCTAssertEqual(previous.title, "Season 1")
        XCTAssertEqual(previous.winnerTitleName, "Season 1 Winner")
        XCTAssertEqual(previous.start, date("2026-04-01"))
        XCTAssertEqual(previous.end, date("2026-07-01"))
    }

    func testPreviousSeasonUsesLaunchAnchoredSeasonBeforeCurrent() {
        let previous = SquadSeason.previous(endingBefore: date("2026-07-15"), calendar: utcCalendar)

        XCTAssertEqual(previous.title, "Season 1")
        XCTAssertEqual(previous.winnerTitleName, "Season 1 Winner")
        XCTAssertEqual(previous.start, date("2026-04-01"))
        XCTAssertEqual(previous.end, date("2026-07-01"))
    }

    func testWinnerTitleAwardUsesTopLeaderboardRow() throws {
        let season = makeSeason()
        let squadId = UUID()
        let alpha = makeMember(name: "Alpha", squadId: squadId)
        let beta = makeMember(name: "Beta", squadId: squadId)
        let rows = [
            makeRow(member: beta, wins: 4, prs: 2),
            makeRow(member: alpha, wins: 2, prs: 1)
        ]

        let award = try XCTUnwrap(SquadLeaderboardBuilder.winnerTitleAward(rows: rows, season: season))

        XCTAssertEqual(award.titleId, .squadSeasonWinner(1))
        XCTAssertEqual(award.titleName, "Season 1 Winner")
        XCTAssertEqual(award.memberUserId, beta.userId)
        XCTAssertEqual(award.profileUserId, beta.userId.uuidString)
        XCTAssertEqual(award.displayName, "Beta")
        XCTAssertEqual(award.boardScore, rows[0].boardScore)
        XCTAssertEqual(award.assetName, "squad_reward_season_1_winner")
    }

    func testClaimableWinnerAwardRequiresEndedSeasonAndCurrentWinner() throws {
        let season = makeSeason()
        let squadId = UUID()
        let alpha = makeMember(name: "Alpha", squadId: squadId)
        let beta = makeMember(name: "Beta", squadId: squadId)
        let rows = [
            makeRow(member: beta, wins: 4, prs: 2),
            makeRow(member: alpha, wins: 2, prs: 1)
        ]

        XCTAssertNil(SquadLeaderboardBuilder.claimableWinnerTitleAward(
            rows: rows,
            season: season,
            currentUserId: beta.userId.uuidString,
            currentMemberUserId: beta.userId,
            now: date("2026-03-31")
        ))
        XCTAssertNil(SquadLeaderboardBuilder.claimableWinnerTitleAward(
            rows: rows,
            season: season,
            currentUserId: alpha.userId.uuidString,
            currentMemberUserId: alpha.userId,
            now: date("2026-04-01")
        ))

        let claim = try XCTUnwrap(SquadLeaderboardBuilder.claimableWinnerTitleAward(
            rows: rows,
            season: season,
            currentUserId: beta.userId.uuidString,
            currentMemberUserId: beta.userId,
            now: date("2026-04-01")
        ))
        XCTAssertEqual(claim.titleId, .squadSeasonWinner(1))
        XCTAssertEqual(claim.assetName, "squad_reward_season_1_winner")
    }

    func testSquadMissionsRewardRowLockedBelow4() {
        let season = makeSeason()
        let squadId = UUID()
        let alpha = makeMember(name: "Alpha", squadId: squadId)
        let squad = makeSquad(id: squadId, captainId: alpha.userId, streakWeeks: 0)

        let rewards3 = SquadSeasonRewardsBuilder.makeRewards(
            squad: squad, rows: [], season: season, missionsCompleted: 3
        )
        let row3 = rewards3.first { $0.id == "squad-missions" }!
        XCTAssertEqual(row3.progress, 3)
        XCTAssertEqual(row3.target, 4)
        XCTAssertFalse(row3.isUnlocked)
    }

    func testSquadMissionsRewardRowUnlockedAt4() {
        let season = makeSeason()
        let squadId = UUID()
        let alpha = makeMember(name: "Alpha", squadId: squadId)
        let squad = makeSquad(id: squadId, captainId: alpha.userId, streakWeeks: 0)

        let rewards4 = SquadSeasonRewardsBuilder.makeRewards(
            squad: squad, rows: [], season: season, missionsCompleted: 4
        )
        let row4 = rewards4.first { $0.id == "squad-missions" }!
        XCTAssertTrue(row4.isUnlocked)
        XCTAssertEqual(row4.progress, 4)
    }

    func testSquadMissionsRewardRowClampsAbove4() {
        let season = makeSeason()
        let squadId = UUID()
        let alpha = makeMember(name: "Alpha", squadId: squadId)
        let squad = makeSquad(id: squadId, captainId: alpha.userId, streakWeeks: 0)

        let rewardsOver = SquadSeasonRewardsBuilder.makeRewards(
            squad: squad, rows: [], season: season, missionsCompleted: 10
        )
        let rowOver = rewardsOver.first { $0.id == "squad-missions" }!
        XCTAssertEqual(rowOver.progress, 4)
        XCTAssertTrue(rowOver.isUnlocked)
    }

    func testExistingCallSiteCompilesWith0Default() {
        // makeRewards without missionsCompleted must compile and return the row with 0
        let season = makeSeason()
        let squadId = UUID()
        let alpha = makeMember(name: "Alpha", squadId: squadId)
        let squad = makeSquad(id: squadId, captainId: alpha.userId, streakWeeks: 0)

        let rewards = SquadSeasonRewardsBuilder.makeRewards(squad: squad, rows: [], season: season)
        let row = rewards.first { $0.id == "squad-missions" }!
        XCTAssertEqual(row.progress, 0)
        XCTAssertFalse(row.isUnlocked)
    }

    private func makeSeason() -> SquadSeason {
        SquadSeason(
            title: "S1 2026",
            interval: DateInterval(start: date("2026-01-01"), end: date("2026-04-01"))
        )
    }

    private func makeMember(name: String, squadId: UUID) -> SquadMember {
        SquadMember(
            id: UUID(),
            squadId: squadId,
            userId: UUID(),
            joinedAt: date("2026-01-01"),
            displayName: name,
            equippedTitle: nil,
            buildIdentity: nil
        )
    }

    private func makeSquad(id: UUID, captainId: UUID, streakWeeks: Int) -> Squad {
        Squad(
            id: id,
            name: "Test Squad",
            captainId: captainId,
            affinityAxis: nil,
            affinitySetAt: nil,
            inviteCode: "TEST",
            maxSize: 6,
            squadStreakWeeks: streakWeeks,
            createdAt: date("2026-01-01")
        )
    }

    private func makeRow(member: SquadMember, wins: Int, prs: Int) -> SquadBoardRow {
        SquadBoardRow(
            member: member,
            displayName: member.displayName,
            profileUserId: member.userId.uuidString,
            seasonWorkoutDays: 2,
            seasonChallengeWins: wins,
            seasonPRs: prs,
            weeklySessions: 1,
            currentStreak: 1,
            bestStreak: 1,
            activeChallenges: 0,
            totalSessions: 2,
            latestWorkoutAt: date("2026-01-05")
        )
    }

    private func reward(_ id: String, in rewards: [SquadSeasonReward]) -> SquadSeasonReward {
        rewards.first { $0.id == id }!
    }

    private func makeLog(
        id: String,
        userId: String,
        date: Date,
        entries: [ExerciseLogEntry] = []
    ) -> WorkoutLog {
        WorkoutLog(
            id: id,
            userId: userId,
            programId: "program",
            dayNumber: 1,
            plannedWorkoutName: "Workout",
            startedAt: date,
            completedAt: date.addingTimeInterval(45 * 60),
            exerciseEntries: entries,
            overallNotes: nil,
            overallRPE: 7,
            durationMinutes: 45
        )
    }

    private func entry(_ name: String, weight: Double, reps: Int) -> ExerciseLogEntry {
        ExerciseLogEntry(
            id: UUID().uuidString,
            exerciseName: name,
            plannedSets: 1,
            plannedReps: "\(reps)",
            sets: [
                SetLog(
                    id: UUID().uuidString,
                    setNumber: 1,
                    weightKg: weight,
                    reps: reps,
                    rpe: 8,
                    isWarmup: false
                )
            ],
            skipped: false,
            notes: nil
        )
    }

    private func date(_ raw: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = utcCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)!
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
