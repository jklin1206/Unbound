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
        await refreshMissionState()
        await refreshHonors()
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
        await refreshMissionState()
        await refreshHonors()
    }

    @MainActor
    func refreshHonors() async {
        guard let squadId = state.currentSquad?.id else {
            weeklyHonors = []
            return
        }
        weeklyHonors = await services.squadHonors.currentHonors(squadId: squadId)
    }

    @MainActor
    func refreshMissionState() async {
        guard let squadId = state.currentSquad?.id else {
            currentMissionState = nil
            missionContributions = []
            return
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--unbound-demo-squad-mission") {
            selectedTab = .mission
            let demoId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID()
            currentMissionState = SquadMission(
                id: demoId,
                squadId: squadId,
                weekIso: SquadMissionService.currentWeekIso(),
                kind: .totalWeight,
                target: 32000,
                currentProgress: 18750,
                completedAt: nil,
                createdAt: .now
            )
            missionContributions = [
                MissionContribution(userId: nil, total: 8200),
                MissionContribution(userId: nil, total: 6100),
                MissionContribution(userId: nil, total: 4450),
            ]
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--unbound-demo-mission-celebration") {
            selectedTab = .mission
            let demoId = UUID(uuidString: "CCCCCCCC-DDDD-EEEE-FFFF-AAAAAAAAAAAA") ?? UUID()
            let completedMission = SquadMission(
                id: demoId,
                squadId: squadId,
                weekIso: SquadMissionService.currentWeekIso(),
                kind: .totalWeight,
                target: 32000,
                currentProgress: 33400,
                completedAt: Date(),
                createdAt: .now
            )
            currentMissionState = completedMission
            missionContributions = [
                MissionContribution(userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111"), total: 14200),
                MissionContribution(userId: UUID(uuidString: "22222222-2222-2222-2222-222222222222"), total: 11800),
                MissionContribution(userId: UUID(uuidString: "33333333-3333-3333-3333-333333333333"), total: 7400),
            ]
            celebratedMission = completedMission
            return
        }
        #endif
        currentMissionState = await services.squadMission.latestMission(squadId: squadId)
        if let mission = currentMissionState {
            if let contributions = try? await services.squadMission.fetchMissionContributions(missionId: mission.id) {
                missionContributions = contributions
            } else {
                missionContributions = []
            }
        } else {
            missionContributions = []
        }
        // Trigger celebration for completed missions not yet claimed
        if let mission = currentMissionState, mission.isCompleted {
            if let userId = services.auth.currentUserId {
                CurrencyWalletStore.shared.bind(userId: userId)
            }
            let sourceId = SquadRewardPolicy.missionSourceId(mission.id)
            if !CurrencyWalletStore.shared.hasGranted(sourceId: sourceId) {
                celebratedMission = mission
            }
        }
        // Season-track: count completed missions within current season interval
        let season = currentSeason
        seasonMissionsCompleted = (try? await SquadBackend.shared.fetchCompletedMissionCount(
            squadId: squadId,
            since: season.interval.start,
            until: season.interval.end
        )) ?? 0
    }

    @MainActor
    func refreshRoutineDrops() async {
        guard let squadId = state.currentSquad?.id else {
            routineDrops = []
            return
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--unbound-demo-routine-drops") {
            routineDrops = demoRoutineDrops(squadId: squadId)
            return
        }
        #endif
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

        let authUserId = services.auth.currentUserId ?? ""
        if let squadId = state.currentSquad?.id,
           !SquadUserIdentity.usesLocalOnlySquad(for: authUserId) {
            // Real squads: squadmates' logs never exist in the local store
            // (workout_logs is owner-only under RLS), so one gated RPC returns
            // every member's completed logs. The window reaches back past the
            // season start so PR detection has pre-season baselines.
            let since = currentSeason.start.addingTimeInterval(-90 * 24 * 3600)
            logsByMember = (try? await SquadBackend.shared.fetchMemberWorkoutLogs(
                squadId: squadId,
                since: since,
                perMemberLimit: 200
            )) ?? [:]
            // The viewer's own row prefers the local store — it includes logs
            // that haven't synced yet.
            if let me = currentUserId {
                let mine = await fetchWorkoutLogs(userId: authUserId, limit: 200)
                if !mine.isEmpty { logsByMember[me] = mine }
            }
        } else {
            // DEBUG local-only squads share this device's store.
            for member in roster {
                let profileUserId = resolvedProfileUserId(for: member)
                logsByMember[member.userId] = await fetchWorkoutLogs(userId: profileUserId, limit: 120)
            }
        }

        for member in roster {
            let profileUserId = resolvedProfileUserId(for: member)
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
    func setSquadAffinity(_ axis: AttributeKey?) async {
        guard let userId = services.auth.currentUserId else { return }
        do {
            try await services.squads.setAffinity(axis, userId: userId)
            state = services.squads.state(userId: userId)
        } catch {
            services.logging.log("SquadDetailView.setSquadAffinity failed: \(error)", level: .warning)
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
    func renameSquad(_ name: String) async {
        guard let userId = services.auth.currentUserId else { return }
        do {
            try await services.squads.renameSquad(name: name, userId: userId)
            state = services.squads.state(userId: userId)
        } catch {
            services.logging.log("SquadDetailView.renameSquad failed: \(error)", level: .warning)
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

    @MainActor
    func claimMissionReward(_ mission: SquadMission) {
        if let userId = services.auth.currentUserId {
            CurrencyWalletStore.shared.bind(userId: userId)
        }
        CurrencyWalletStore.shared.grant(
            SquadRewardPolicy.missionArcs,
            sourceId: SquadRewardPolicy.missionSourceId(mission.id)
        )
    }

    #if DEBUG
    func demoRoutineDrops(squadId: UUID) -> [SquadRoutineDrop] {
        let me = currentUserId ?? UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
        let crew: [(UUID, String)] = [
            (me, "You"),
            (UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(), "Mara"),
            (UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(), "Kenji"),
            (UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID(), "Sol")
        ]
        let titles = [
            "Pull Density 30",
            "Hotel Upper",
            "Legs Without Machines",
            "Core Lock",
            "Push Speed",
            "Posterior Chain",
            "Mobility Reset",
            "Grip Finisher",
            "Quiet Full Body",
            "Back Day Short",
            "Zone 2 Add-On",
            "Shoulder Armor"
        ]
        let notes = [
            "Strict rest. Stop one rep before form breaks.",
            "Fits a small hotel gym.",
            "Single-leg work first, hinge second.",
            "Slow holds, no rushed transitions."
        ]

        return titles.enumerated().map { index, title in
            let author = crew[index % crew.count]
            let workout = SavedWorkout(title: title, blocks: [])
            return SquadRoutineDrop(
                squadId: squadId,
                authorUserId: author.0,
                authorDisplayName: author.1,
                title: title,
                note: notes[index % notes.count],
                workout: workout,
                createdAt: Date().addingTimeInterval(TimeInterval(-index * 54 * 60))
            )
        }
    }
    #endif
}
