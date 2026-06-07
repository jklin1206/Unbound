import SwiftUI
import UserNotifications
import UIKit

extension DevBuildBootstrapper {
    static func activate(services: ServiceContainer, completeOnboarding: Bool = true) async {
        AuthService.shared.activateDevUser(id: userId)
        DevFlags.shared.unlockAllFeatures = true
        UserDefaults.standard.set(completeOnboarding, forKey: "onboardingCompleted")
        UserDefaults.standard.set(completeOnboarding, forKey: "unbound.calibration.completed")

        var profile = UserProfile(
            id: userId,
            email: "dev@unbound.local",
            displayName: "Dev Player",
            createdAt: Date(),
            onboardingCompleted: completeOnboarding,
            totalScans: 12,
            currentProgramId: "dev-program",
            heightCm: 180,
            weightKg: 82,
            age: 28,
            biologicalSex: .male
        )
        profile.displayHandle = "devplayer"
        profile.experience = .current
        profile.currentFrequency = .fivePlus
        profile.targetFrequency = .five
        profile.equipment = [.fullGym, .barbell, .dumbbells, .bench, .pullupBar, .bodyweight]
        profile.goals = [.buildMuscle, .getDefined, .getStronger, .athletic]
        profile.trainingStyleOverride = .freeWeights
        profile.trainingFeedbackMode = .detailed
        profile.trainingDays = [.monday, .tuesday, .wednesday, .thursday, .friday]

        try? await DatabaseService.shared.create(profile, collection: "users", documentId: userId)
        BadgeService.shared.bind(userId: userId)
        await SkillProgressService.shared.load(userId: userId)
        seedAttributes()
        await seedProgressionFamilies()
        seedLiftTiers()
        await seedProgram()
        await seedWorkoutLogs()
        await seedProgressPhotos()
        SkinService.shared.debugUnlockAllSkins()
        await seedSessionStats()
        await applyLevel(25)
        await TrialsService.shared.ensureCurrentWeek(userId: userId)
    }

    static func maxEverything(level: Int, services: ServiceContainer, completeOnboarding: Bool = true) async {
        await activate(services: services, completeOnboarding: completeOnboarding)
        await applyLevel(level)
        await unlockAllBadges()
        await masterSkillTree()
        await seedSessionStats()
        seedAttributes()
        await seedProgressionFamilies()
        seedLiftTiers()
        await seedProgram()
        await seedWorkoutLogs()
        await seedProgressPhotos()
        SkinService.shared.debugUnlockAllSkins()
        await TrialsService.shared.ensureCurrentWeek(userId: userId)
    }

    static func applyLevel(_ level: Int) async {
        let clamped = max(1, min(80, level))
        let progress = OverallLevelProgress(
            userId: userId,
            totalXP: OverallLevelCurve.xpRequired(forLevel: clamped)
        )
        try? await DatabaseService.shared.create(
            progress,
            collection: "overall_level_progress",
            documentId: userId
        )
    }

    static func unlockAllBadges() async {
        AuthService.shared.activateDevUser(id: userId)
        let now = Date()
        let unlocked = BadgeCatalog.all.enumerated().reduce(into: [String: Date]()) { result, pair in
            result[pair.element.id] = Calendar.current.date(byAdding: .minute, value: -pair.offset, to: now) ?? now
        }
        if let data = try? JSONEncoder.unbound.encode(unlocked) {
            UserDefaults.standard.set(data, forKey: badgeKey)
        }
        BadgeService.shared.bind(userId: userId)
    }

    static func seedSessionStats() async {
        await applySessionStats(totalSessions: 96, currentStreak: 21, longestStreak: 45, weeklyCount: 5)
    }

    static func applySessionStats(
        totalSessions: Int,
        currentStreak: Int,
        longestStreak: Int,
        weeklyCount: Int
    ) async {
        AuthService.shared.activateDevUser(id: userId)
        var cal = Calendar.current
        cal.firstWeekday = 2
        let weekComponents = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let weekStart = cal.date(from: weekComponents) ?? cal.startOfDay(for: Date())
        let streak = max(0, currentStreak)
        let record = SessionXPRecord(
            userId: userId,
            totalSessions: max(0, totalSessions),
            currentStreak: streak,
            longestStreak: max(streak, longestStreak),
            lastSessionDate: Date(),
            weeklyCount: max(0, weeklyCount),
            weekStartDate: weekStart
        )
        if let data = try? JSONEncoder.unbound.encode(record) {
            UserDefaults.standard.set(data, forKey: sessionXPKey)
        }
        UserDefaults.standard.set(record.currentStreak, forKey: "unbound.streakDays")
        let delta = SessionXPDelta(previous: record, updated: record, streakExtended: false, streakBroken: false)
        NotificationCenter.default.post(name: .sessionXPUpdated, object: nil, userInfo: ["delta": delta])
    }

    static func masterSkillTree(tier: SkillTier = .ascendant) async {
        AuthService.shared.activateDevUser(id: userId)
        let now = Date()
        let graph = SkillGraph.shared
        let states = graph.nodes.reduce(into: [String: NodeState]()) { result, node in
            result[node.id] = .proven
        }
        let dates = graph.nodes.reduce(into: [String: Date]()) { result, node in
            result[node.id] = now
        }
        let activeGoals = Set(graph.nodes.filter { !$0.isMythic }.prefix(6).map(\.id))
        let schedule: [DayCategory?] = [.push, .pull, .legs, .core, .skills, .conditioning, .rest]

        let payload = UserSkillProgress(
            userId: userId,
            nodeStates: states,
            provenAt: dates,
            updatedAt: now,
            bookmarkedNodeIds: activeGoals,
            activeGoalIds: activeGoals,
            weeklySchedule: schedule,
            currentWeekPhase: .heavy
        )
        try? await DatabaseService.shared.create(payload, collection: "skillProgress", documentId: userId)
        await SkillProgressService.shared.load(userId: userId)

        let tierState = UserSkillTierState(
            perSkill: graph.nodes.reduce(into: [String: SkillTier]()) { result, node in
                result[node.id] = tier
            },
            rankUpsEarned: graph.nodes.count * max(tier.rawValue, 1),
            ascendantSkills: tier == .ascendant ? graph.nodes.map(\.id) : []
        )
        UserSkillTierStore.shared.save(tierState, userId: userId)
    }

    static func applyRank(_ tier: SkillTier) async {
        AuthService.shared.activateDevUser(id: userId)
        await masterSkillTree(tier: tier)
        seedLiftTiers(tier: tier)
        await seedProgressionFamilies(tier: tier)
        SkinService.shared.debugUnlockAllSkins(select: tier.rawValue >= SkillTier.unbound.rawValue ? .holographic : .violet)
        NotificationCenter.default.post(name: .skillTierAdvanced, object: SkillTierAdvance(
            skillId: "dev-profile-rank",
            from: .initiate,
            to: tier
        ))
    }

    static func seedSquadRosterForProof() async {
        AuthService.shared.activateDevUser(id: userId)

        let joinerUserId = "dev-player-two"
        try? await SquadService.shared.leaveSquad(userId: joinerUserId)
        await SquadService.shared.loadCurrentSquad(userId: userId)

        let squad: Squad
        if let existing = SquadService.shared.state(userId: userId).currentSquad {
            squad = existing
        } else if let created = try? await SquadService.shared.createSquad(name: "Codex Crew", userId: userId) {
            squad = created
        } else {
            return
        }

        _ = try? await SquadService.shared.joinSquad(inviteCode: squad.inviteCode, userId: joinerUserId)
        await SquadService.shared.loadCurrentSquad(userId: userId)
    }

    static func seedSquadActivityProof() async {
        AuthService.shared.activateDevUser(id: userId)
        await seedSquadRosterForProof()

        let partnerUserId = "dev-player-two"
        guard let userUUID = SquadUserIdentity.uuid(from: userId),
              let partnerUUID = SquadUserIdentity.uuid(from: partnerUserId)
        else { return }

        await SquadService.shared.loadCurrentSquad(userId: userId)
        guard let loadedSquad = SquadService.shared.state(userId: userId).currentSquad else { return }
        LocalSquadDirectory.shared.updateStreakWeeks(squadId: loadedSquad.id, weeks: 6)
        await SquadService.shared.loadCurrentSquad(userId: userId)

        guard let squad = SquadService.shared.state(userId: userId).currentSquad else { return }
        let existingChallenge = await FriendChallengeService.shared
            .activeChallenges(userId: userUUID)
            .first { $0.squadId == squad.id && $0.kind == .mostSessions }

        let challenge: FriendChallenge
        if let existingChallenge {
            challenge = existingChallenge
        } else if let created = try? await FriendChallengeService.shared.createChallenge(
            challengedId: partnerUUID,
            kind: .mostSessions,
            squadId: squad.id
        ) {
            challenge = created
        } else {
            return
        }

        try? await FriendChallengeService.shared.accept(challenge.id)
        for offset in 0..<3 {
            let proofLog = proofWorkoutLog(userId: userId, dayOffset: offset)
            await FriendChallengeService.shared.recordProgress(
                log: proofLog,
                userId: userId,
                sourceLogId: proofLog.id
            )
        }
        for offset in 0..<2 {
            let proofLog = proofWorkoutLog(userId: partnerUserId, dayOffset: offset + 3)
            await FriendChallengeService.shared.recordProgress(
                log: proofLog,
                userId: partnerUserId,
                sourceLogId: proofLog.id
            )
        }

        let now = Date()
        var state = SquadService.shared.state(userId: userId)
        state.currentSquad = squad
        state.recentActivity = [
            SquadActivityEntry(
                id: UUID(),
                squadId: squad.id,
                userId: nil,
                kind: .squadStreakExtended,
                payload: .squadStreakExtended(weeks: 6),
                createdAt: now.addingTimeInterval(-60)
            ),
            SquadActivityEntry(
                id: UUID(),
                squadId: squad.id,
                userId: userUUID,
                kind: .linkedSession,
                payload: .linkedSession(participantUserIds: [userUUID, partnerUUID], durationMinutes: 44),
                createdAt: now.addingTimeInterval(-150)
            ),
            SquadActivityEntry(
                id: UUID(),
                squadId: squad.id,
                userId: userUUID,
                kind: .trialCompleted,
                payload: .trialCompleted(trialName: "Upper Body Power", theme: .axis(.power)),
                createdAt: now.addingTimeInterval(-260)
            ),
            SquadActivityEntry(
                id: UUID(),
                squadId: squad.id,
                userId: partnerUUID,
                kind: .trialCompleted,
                payload: .trialCompleted(trialName: "Mobility Reset", theme: .axis(.mobility)),
                createdAt: now.addingTimeInterval(-420)
            ),
            SquadActivityEntry(
                id: UUID(),
                squadId: squad.id,
                userId: partnerUUID,
                kind: .memberJoined,
                payload: .memberJoined(memberDisplayName: "Crewmate 2"),
                createdAt: now.addingTimeInterval(-620)
            )
        ]
        SquadStore.shared.save(state, userId: userId)
        NotificationCenter.default.post(name: .squadStateChanged, object: nil)
    }

    static func proofWorkoutLog(userId: String, dayOffset: Int) -> WorkoutLog {
        let completedAt = Calendar.current.date(
            byAdding: .day,
            value: -dayOffset,
            to: Date()
        ) ?? Date()
        let startedAt = completedAt.addingTimeInterval(-44 * 60)
        return WorkoutLog(
            id: "squad-proof-\(userId)-\(dayOffset)",
            userId: userId,
            programId: "squad-proof-program",
            dayNumber: max(1, dayOffset + 1),
            plannedWorkoutName: "Squad Proof Session",
            startedAt: startedAt,
            completedAt: completedAt,
            exerciseEntries: [],
            overallNotes: "Simulator proof session",
            overallRPE: 7,
            durationMinutes: 44
        )
    }

    static func seedAttributes() {
        applyAttributes([
            .power: 88,
            .explosiveness: 78,
            .control: 82,
            .vitality: 66,
            .mobility: 60,
            .endurance: 74
        ])
    }

    static func applyAttributes(_ values: [AttributeKey: Double]) {
        let now = Date()
        var profile = AttributeProfile.empty(userId: userId, at: now)
        for key in AttributeKey.allCases {
            // Dev slider value == target LEVEL; back into the xp that lands there.
            let level = Int(min(100, max(0, values[key] ?? 0)).rounded())
            profile.set(
                key,
                AttributeValue(xp: AttributeLevelCurve.xpRequired(forLevel: level), lastContributionAt: now)
            )
        }
        profile.computedAt = now
        AttributeProfileStore.shared.save(profile)
        NotificationCenter.default.post(name: .attributeRankUp, object: nil)
    }

    static func seedLiftTiers(tier: SkillTier = .ascendant) {
        for lift in devLiftNames {
            LiftTierService.shared.save(tier: tier, lift: lift, userId: userId)
        }
    }

    static func applyBestLift(lift: String, weightKg: Double, reps: Int) async {
        AuthService.shared.activateDevUser(id: userId)
        let normalized = devLiftNames.contains(lift) ? lift : "deadlift"
        let safeWeight = max(1, weightKg)
        let safeReps = max(1, reps)
        let tier = liftTier(for: normalized, weightKg: safeWeight)

        for name in devLiftNames {
            LiftTierService.shared.save(tier: name == normalized ? tier : .initiate, lift: name, userId: userId)
        }

        let entries = devLiftNames.enumerated().map { offset, name in
            let isSelected = name == normalized
            return ExerciseLogEntry(
                id: "dev-\(name.replacingOccurrences(of: " ", with: "-"))",
                exerciseName: name,
                plannedSets: 1,
                plannedReps: "\(isSelected ? safeReps : 1)",
                sets: [
                    SetLog(
                        id: "dev-\(offset)-top",
                        setNumber: 1,
                        weightKg: isSelected ? safeWeight : 1,
                        reps: isSelected ? safeReps : 1,
                        rpe: isSelected ? 9 : 6,
                        isWarmup: false
                    )
                ],
                skipped: false,
                notes: nil
            )
        }
        let now = Date()
        let log = WorkoutLog(
            id: "dev-profile-prs",
            userId: userId,
            programId: "dev-profile",
            dayNumber: 0,
            plannedWorkoutName: "Dev Showcase",
            startedAt: now.addingTimeInterval(-86_400),
            completedAt: now.addingTimeInterval(-86_400 + 3_600),
            exerciseEntries: entries,
            overallNotes: "Seeded debug profile lift proofs.",
            overallRPE: 9,
            durationMinutes: 60
        )
        try? await DatabaseService.shared.create(log, collection: "workoutLogs", documentId: log.id)
    }

    /// Dev seeder bodyweight (matches the seeded Dev Player profile).
    static let devBodyweightKg: Double = 82

    static func liftTier(for lift: String, weightKg: Double) -> SkillTier {
        StrengthStandards.rank(
            liftKg: weightKg,
            bodyweightKg: devBodyweightKg,
            exerciseKey: lift,
            sex: .male
        ) ?? .initiate
    }

    static func seedProgressionFamilies(tier: SkillTier = .ascendant) async {
        let now = Date()
        let requestedTier = progressionFamilyTier(for: tier)
        let grouped = Dictionary(grouping: MovementCatalog.legacyExercises.compactMap { exercise -> (String, Int)? in
            guard let family = exercise.progressionFamily, let tier = exercise.progressionTier else { return nil }
            return (family, tier)
        }, by: { $0.0 })

        for (family, entries) in grouped {
            let maxTier = entries.map(\.1).max() ?? 0
            let unlockedTier = min(maxTier, requestedTier)
            let state = ProgressionFamilyState(
                userId: userId,
                family: family,
                unlockedTier: unlockedTier,
                currentTier: unlockedTier,
                updatedAt: now
            )
            await ProgressionStateStore.shared.saveFamilyState(state)
        }
    }

    static func seedOverallRankTrialReadyProof(targetRankRawValue: String = RankTitle.novice.token) async {
        AuthService.shared.activateDevUser(id: userId)
        let now = Date()
        let targetRank = RankTier.fromToken(targetRankRawValue)
        let definition = OverallRankTrialDefinitions.all.first { $0.targetRank == targetRank }
            ?? OverallRankTrialDefinitions.foundationProof
        OverallRankTrialStore.shared.save(
            OverallRankTrialProgress(highestPassedRank: sourceRank(before: definition.targetRank), attempts: []),
            userId: userId
        )

        let overall = OverallLevelProgress(
            userId: userId,
            totalXP: OverallLevelCurve.xpRequired(forLevel: definition.minOverallLevel),
            lastGainedXP: 0,
            processedSourceLogIds: [],
            updatedAt: now
        )
        try? await DatabaseService.shared.create(
            overall,
            collection: "overall_level_progress",
            documentId: userId
        )
        let proofEquipment = [
            Equipment.fullGym.rawValue,
            Equipment.barbell.rawValue,
            Equipment.dumbbells.rawValue,
            Equipment.bench.rawValue,
            Equipment.pullupBar.rawValue,
            Equipment.bodyweight.rawValue
        ]
        try? await SupabaseUserService.shared.updateProfile(
            userId: userId,
            fields: ["equipment": proofEquipment]
        )
        try? await DatabaseService.shared.update(
            ["equipment": proofEquipment],
            collection: "users",
            documentId: userId
        )

        // Phase 7: eligibility = aggregateRank >= targetRank. Seed all four
        // tracked lifts at the target tier (clears the ≥4-movement coverage
        // floor and lands the weighted mean on the target), with fresh,
        // mid-level attributes so freshness stays at 1.0.
        seedLiftTiers(tier: definition.targetRank)
        applyAttributes(
            Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { key in (key, 50.0) })
        )
    }

    static func sourceRank(before targetRank: RankTitle) -> RankTitle {
        switch targetRank {
        case .novice: return .initiate
        case .apprentice: return .novice
        case .forged: return .apprentice
        case .veteran: return .forged
        case .master: return .veteran
        case .vessel: return .master
        case .unbound: return .vessel
        case .ascendant: return .unbound
        case .initiate: return .initiate
        }
    }

    static func progressionFamilyTier(for tier: SkillTier) -> Int {
        switch tier {
        case .initiate: return 0
        case .novice: return 1
        case .apprentice: return 1
        case .forged: return 2
        case .veteran: return 3
        case .master: return 4
        case .vessel: return 5
        case .unbound: return 6
        case .ascendant: return 7
        }
    }
}
