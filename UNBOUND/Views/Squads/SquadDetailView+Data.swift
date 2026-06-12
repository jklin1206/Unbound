// UNBOUND/Views/Squads/SquadDetailView+Data.swift
import SwiftUI

extension SquadDetailView {
    @MainActor
    func loadAll() async {
        guard let userId = services.auth.currentUserId else { return }
        await services.squads.loadCurrentSquad(userId: userId)
        state = services.squads.state(userId: userId)
        if let squadId = state.currentSquad?.id {
            await services.squadPresence.subscribeToSquadPresence(squadId: squadId)
        }
        await refreshMemberProfiles()
        await refreshMemberFrameTiers()
        await refreshChallenges()
        await refreshLeaderboardData()
        await awardEndedSeasonWinnerIfEligible()
        await refreshRoutineDrops()
    }

    @MainActor
    func refreshState() async {
        guard let userId = services.auth.currentUserId else { return }
        state = services.squads.state(userId: userId)
        await refreshMemberProfiles()
        await refreshMemberFrameTiers()
        await refreshLeaderboardData()
        await awardEndedSeasonWinnerIfEligible()
        await refreshRoutineDrops()
    }

    @MainActor
    func refreshRoutineDrops() async {
        guard let squadId = state.currentSquad?.id else {
            routineDrops = []
            return
        }
        routineDrops = await SquadRoutineDropService.shared.fetchRecent(squadId: squadId, limit: 12)
    }

    @MainActor
    func refreshChallenges() async {
        if let me = currentUserId {
            activeChallenges = await services.friendChallenge.activeChallenges(userId: me)
        }
        if let squadId = state.currentSquad?.id {
            challengeStatsByMember = await services.friendChallenge.challengeStats(squadId: squadId)
        }
    }

    @MainActor
    private func refreshMemberProfiles() async {
        let roster = state.roster
        var profiles: [UUID: UserProfile] = [:]
        for member in roster {
            let profileUserId = resolvedProfileUserId(for: member)
            if let profile = try? await services.user.fetchProfile(userId: profileUserId) {
                profiles[member.userId] = profile
            }
        }
        memberProfiles = profiles
    }

    @MainActor
    private func refreshMemberFrameTiers() async {
        var tiers: [UUID: RankTitle] = [:]
        for member in state.roster {
            let profileUserId = resolvedProfileUserId(for: member)
            let aggregateTier = await services.rank.aggregateTier(userId: profileUserId)
            tiers[member.userId] = RankCosmetics.equippedFrameTier(
                userId: profileUserId,
                currentTier: aggregateTier
            )
        }
        memberFrameTiers = tiers
    }

    @MainActor
    private func refreshLeaderboardData() async {
        let roster = state.roster
        var logsByMember: [UUID: [WorkoutLog]] = [:]
        var recordsByMember: [UUID: SessionXPRecord] = [:]

        for member in roster {
            let profileUserId = resolvedProfileUserId(for: member)
            logsByMember[member.userId] = await fetchWorkoutLogs(userId: profileUserId, limit: 120)
            recordsByMember[member.userId] = services.sessionXP.record(userId: profileUserId)
        }

        memberWorkoutLogs = logsByMember
        memberSessionRecords = recordsByMember

        if let squadId = state.currentSquad?.id {
            challengeStatsByMember = await services.friendChallenge.challengeStats(squadId: squadId)
        } else {
            challengeStatsByMember = [:]
        }
    }

    func accountabilityBadge(for userId: UUID) -> AccountabilityBadgeState {
        AccountabilityBadgeState(userId: userId, clearedCount: state.recentActivity.filter { $0.userId == userId && $0.kind == .trialCompleted }.count)
    }

    func weeklySessionCount(for userId: UUID) -> Int {
        if let row = squadBoardRows.first(where: { $0.member.userId == userId }) {
            return row.weeklySessions
        }
        return state.recentActivity.filter { $0.userId == userId && $0.kind == .trialCompleted }.count
    }

    func displayName(for userId: UUID?) -> String {
        guard let userId else { return "UNBOUND" }
        if let member = state.roster.first(where: { $0.userId == userId }) {
            return displayName(for: member)
        }
        return "Crewmate"
    }

    func displayName(for member: SquadMember) -> String {
        if let profile = memberProfiles[member.userId] {
            if let name = profile.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !name.isEmpty {
                return name
            }
            if let handle = profile.displayHandle?.trimmingCharacters(in: .whitespacesAndNewlines),
               !handle.isEmpty {
                return "@\(handle.trimmingCharacters(in: CharacterSet(charactersIn: "@")))"
            }
        }
        if isCurrentMember(member), ["Captain", "You"].contains(member.displayName) {
            return "You"
        }
        return member.displayName
    }

    func resolvedProfileUserId(for member: SquadMember) -> String {
        if let current = services.auth.currentUserId,
           SquadUserIdentity.uuid(from: current) == member.userId {
            return current
        }
        return member.userId.uuidString
    }

    func frameTier(for member: SquadMember) -> RankTitle {
        memberFrameTiers[member.userId] ?? .initiate
    }

    private func isCurrentMember(_ member: SquadMember) -> Bool {
        guard let current = services.auth.currentUserId else { return false }
        return SquadUserIdentity.uuid(from: current) == member.userId
    }

    func canEditSquad(_ squad: Squad) -> Bool {
        guard let currentUserId else { return false }
        return squad.captainId == currentUserId
    }

    var squadBoardRows: [SquadBoardRow] {
        SquadLeaderboardBuilder.makeBoardRows(
            roster: state.roster,
            displayNames: Dictionary(uniqueKeysWithValues: state.roster.map { ($0.userId, displayName(for: $0)) }),
            profileUserIds: Dictionary(uniqueKeysWithValues: state.roster.map { ($0.userId, resolvedProfileUserId(for: $0)) }),
            workoutLogs: memberWorkoutLogs,
            sessionRecords: memberSessionRecords,
            challengeStats: challengeStatsByMember,
            season: currentSeason
        )
    }

    @MainActor
    private func awardEndedSeasonWinnerIfEligible(now: Date = Date()) async {
        guard let userId = services.auth.currentUserId,
              let memberUserId = currentUserId,
              let squad = state.currentSquad
        else { return }

        let endedSeason = SquadSeason.previous(endingBefore: now)
        let challengeStats = await services.friendChallenge.challengeStats(squadId: squad.id, season: endedSeason)
        let rows = SquadLeaderboardBuilder.makeBoardRows(
            roster: state.roster,
            displayNames: Dictionary(uniqueKeysWithValues: state.roster.map { ($0.userId, displayName(for: $0)) }),
            profileUserIds: Dictionary(uniqueKeysWithValues: state.roster.map { ($0.userId, resolvedProfileUserId(for: $0)) }),
            workoutLogs: memberWorkoutLogs,
            sessionRecords: memberSessionRecords,
            challengeStats: challengeStats,
            season: endedSeason
        )
        guard let award = SquadLeaderboardBuilder.claimableWinnerTitleAward(
            rows: rows,
            season: endedSeason,
            currentUserId: userId,
            currentMemberUserId: memberUserId,
            now: now
        ) else { return }

        services.trials.unlockTitle(award.titleId, userId: userId)
        earnedSeasonWinnerAward = award
    }

    @MainActor
    private func fetchWorkoutLogs(userId: String, limit: Int) async -> [WorkoutLog] {
        (try? await services.database.query(
            collection: "workoutLogs",
            field: "userId",
            isEqualTo: userId,
            orderBy: "startedAt",
            descending: true,
            limit: limit
        )) ?? []
    }

    @MainActor
    func leaveSquad() async {
        guard let userId = services.auth.currentUserId else { return }
        do {
            try await services.squads.leaveSquad(userId: userId)
            state = services.squads.state(userId: userId)
        } catch {
            leaveError = "Couldn't leave squad. Try again."
        }
    }

    @MainActor
    func setSquadLogo(_ logoId: String) async {
        guard let userId = services.auth.currentUserId else { return }
        do {
            try await services.squads.setLogo(logoId, userId: userId)
            state = services.squads.state(userId: userId)
        } catch {
            services.logging.log("SquadDetailView.setSquadLogo failed: \(error)", level: .warning)
        }
    }

    @MainActor
    func saveRoutineDrop(_ drop: SquadRoutineDrop) {
        let saved = drop.savedWorkoutCopy()
        SavedWorkoutStore.shared.save(saved)
        routineDropStatus = "Saved \(drop.title) to your workouts."
    }

    @MainActor
    func useRoutineDropToday(_ drop: SquadRoutineDrop) {
        let saved = drop.savedWorkoutCopy()
        SavedWorkoutStore.shared.save(saved)
        routineDropStatus = "Saved \(drop.title) and sent it to today's Program."
        NotificationCenter.default.post(name: .requestNavigateToProgramTab, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            NotificationCenter.default.post(name: .savedWorkoutScheduleTodayRequested, object: saved)
        }
    }
}
