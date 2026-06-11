#if DEBUG
import SwiftUI
import UserNotifications
import UIKit

extension DevBuildBootstrapper {
    static func seedScanHistory(daysAgo: Int) async {
        AuthService.shared.activateDevUser(id: userId)
        UserDefaults.standard.set(true, forKey: "unbound.scanConsentGranted")

        let now = Date()
        let safeDaysAgo = max(0, daysAgo)
        let latestDate = Calendar.current.date(byAdding: .day, value: -safeDaysAgo, to: now) ?? now
        let baselineDate = Calendar.current.date(byAdding: .day, value: -60, to: latestDate) ?? latestDate.addingTimeInterval(-60 * 86_400)

        let before = devProgressImage(named: "DevProgressBefore", fallbackColor: UIColor(red: 0.06, green: 0.10, blue: 0.13, alpha: 1))
        let after = devProgressImage(named: "DevProgressAfter", fallbackColor: UIColor(red: 0.02, green: 0.23, blue: 0.26, alpha: 1))

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let scanPhotoDir = docs.appendingPathComponent("scan-photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: scanPhotoDir, withIntermediateDirectories: true)

        let baselineFilename = "dev-scan-baseline-front.jpg"
        let latestFilename = "dev-scan-latest-front.jpg"
        let baselineURL = scanPhotoDir.appendingPathComponent(baselineFilename)
        let latestURL = scanPhotoDir.appendingPathComponent(latestFilename)
        try? before.jpegData(compressionQuality: 0.88)?.write(to: baselineURL, options: [.atomic])
        try? after.jpegData(compressionQuality: 0.88)?.write(to: latestURL, options: [.atomic])

        let baselineIdentity = BuildIdentity(primary: .power, secondary: .endurance, shape: .hybrid)
        let latestIdentity = BuildIdentity(primary: .power, secondary: .control, shape: .hybrid)
        let baselineCheckpoint = ScanCheckpoint(
            id: "dev-scan-baseline",
            userId: userId,
            createdAt: baselineDate,
            photoFilename: baselineFilename,
            buildIdentitySnapshot: baselineIdentity,
            narrative: "Baseline debug scan locked. Power leads the profile with endurance close behind.",
            deltaFromPrior: nil
        )
        let latestCheckpoint = ScanCheckpoint(
            id: "dev-scan-latest",
            userId: userId,
            createdAt: latestDate,
            photoFilename: latestFilename,
            buildIdentitySnapshot: latestIdentity,
            narrative: "Debug checkpoint shows the Arc compounding: pressing strength held while control improved.",
            deltaFromPrior: BuildIdentityDelta(perAxis: [
                .power: 3,
                .control: 8,
                .endurance: 2,
                .explosiveness: 2,
                .vitality: 1,
                .mobility: 1
            ])
        )
        try? ScanCheckpointStore.shared.save(baselineCheckpoint)
        try? ScanCheckpointStore.shared.save(latestCheckpoint)

        let baselinePhoto = ProgressPhoto(
            id: "dev-scan-photo-baseline",
            userId: userId,
            storageUrl: baselineURL.path,
            capturedAt: baselineDate,
            note: "Dev baseline scan",
            angle: .front,
            blockNumber: 1,
            source: .scan
        )
        let latestPhoto = ProgressPhoto(
            id: "dev-scan-photo-latest",
            userId: userId,
            storageUrl: latestURL.path,
            capturedAt: latestDate,
            note: safeDaysAgo == 0 ? "Dev locked scan" : "Dev due scan",
            angle: .front,
            blockNumber: 1,
            source: .scan
        )
        try? await DatabaseService.shared.create(baselinePhoto, collection: "progressPhotos", documentId: baselinePhoto.id)
        try? await DatabaseService.shared.create(latestPhoto, collection: "progressPhotos", documentId: latestPhoto.id)

        let report = ScanDeltaReport(
            id: "dev-scan-delta-report",
            userId: userId,
            baselineScanId: baselineCheckpoint.id,
            comparisonScanId: latestCheckpoint.id,
            createdAt: latestDate,
            shoulders: BodyPartDelta(before: 5, after: 7),
            chest: BodyPartDelta(before: 6, after: 7),
            arms: BodyPartDelta(before: 5, after: 6),
            core: BodyPartDelta(before: 4, after: 6),
            legs: BodyPartDelta(before: 6, after: 6),
            overall: BodyPartDelta(before: 5, after: 7),
            narrative: "Power and control proof signals are trending up. Next block should keep pull volume stable while watching logged recovery.",
            improvements: ["power", "control"],
            laggingAreas: [],
            recommendedFocus: "Let completed sessions, RPE, equipment, and recovery drive the next block."
        )
        try? await DatabaseService.shared.create(report, collection: "scanDeltaReports", documentId: report.id)

        UserDefaults.standard.set(latestDate.timeIntervalSince1970, forKey: "unbound.lastScanTimestamp")
        try? await DatabaseService.shared.update(["totalScans": 2], collection: "users", documentId: userId)
    }

    static func regenerateProgramFromDevProfile() async {
        UserDefaults.standard.removeObject(forKey: DevDynamicProgramScenario.activeUserDefaultsKey)
        await activate(services: ServiceContainer(), completeOnboarding: true)
        guard let profile: UserProfile = try? await DatabaseService.shared.read(collection: "users", documentId: userId) else {
            return
        }
        do {
            let program = try await ProgramGenerationService.shared.generateFromOnboarding(
                userId: userId,
                targetFrequency: profile.targetFrequency,
                equipment: Set(profile.equipment ?? [.bodyweight]),
                experience: profile.experience,
                sessionLength: profile.sessionLength,
                exerciseStyles: Set(profile.exerciseStyles ?? []),
                targetAreas: Set(profile.targetAreas ?? []),
                age: profile.age ?? 0,
                gender: profile.gender ?? .unspecified,
                heightCm: profile.heightCm ?? 0,
                weightKg: profile.weightKg ?? 0,
                trainingDays: profile.trainingDays,
                trainingStyleOverride: profile.trainingStyleOverride,
                trainingFeedbackMode: profile.trainingFeedbackMode,
                cutModeActive: profile.cutMode.enabled,
                biologicalSex: profile.biologicalSex
            )
            try? await DatabaseService.shared.create(program, collection: "programs", documentId: program.id)
            await ProgramStore.shared.save(program, userId: userId)
            try? await DatabaseService.shared.update(["currentProgramId": program.id], collection: "users", documentId: userId)
        } catch {
            LoggingService.shared.log(
                "Dev deterministic regeneration failed: \(error)",
                level: .error,
                context: ["userId": userId]
            )
        }
    }

    static func programScanSnapshot() -> DevProgramScanSnapshot {
        let program = ProgramStore.shared.loadLocal(userId: userId) ?? ProgramStore.shared.program
        let checkpoints = (try? ScanCheckpointStore.shared.history(userId: userId)) ?? []
        let lastScan = checkpoints.last?.createdAt
        let scanCadence = ScanCadenceState.compute(lastScanAt: lastScan, now: Date())
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        guard let program else {
            return DevProgramScanSnapshot(
                programName: "No local program",
                arcStatus: "No active Arc",
                workoutDays: 0,
                requiredEquipment: "None",
                scanStatus: scanCadence.isUnlocked ? "Ready" : "Locked \(scanCadence.daysUntilNext)d",
                checkpointCount: checkpoints.count,
                lastScan: lastScan.map { formatter.string(from: $0) } ?? "Never"
            )
        }

        let arcStatus: String = {
            if let context = ArcScheduler.context(for: program) {
                return context.displayText
            }
            if BlockRolloverScheduler.shouldRollover(program: program) {
                return "Checkpoint due"
            }
            return "Day \(BlockRolloverScheduler.currentDayNumber(program: program)) · legacy block"
        }()
        let equipment = program.requiredEquipment.prefix(3).joined(separator: ", ")
        return DevProgramScanSnapshot(
            programName: program.name,
            arcStatus: arcStatus,
            workoutDays: program.days.filter { !$0.isRestDay && $0.workout != nil }.count,
            requiredEquipment: equipment.isEmpty ? "None" : equipment,
            scanStatus: scanCadence.isUnlocked ? "Ready" : "Locked \(scanCadence.daysUntilNext)d",
            checkpointCount: checkpoints.count,
            lastScan: lastScan.map { formatter.string(from: $0) } ?? "Never"
        )
    }

    static func completedTrainingDays(count: Int) -> [Int] {
        guard count > 0 else { return [] }
        return Array((1...Arc.durationDays).filter { day in
            let weekdayIndex = ((day - 1) % 7) + 1
            return weekdayIndex != 4 && weekdayIndex != 7
        }.prefix(count))
    }

    static func devProgressImage(named name: String, fallbackColor: UIColor) -> UIImage {
        if let image = UIImage(named: name) {
            return image
        }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 1200))
        return renderer.image { ctx in
            fallbackColor.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 900, height: 1200))
            UIColor.white.withAlphaComponent(0.12).setStroke()
            let path = UIBezierPath(roundedRect: CGRect(x: 300, y: 180, width: 300, height: 780), cornerRadius: 150)
            path.lineWidth = 10
            path.stroke()
        }
    }

    static func seedProgramProofState(rawValue: String) async {
        guard let state = ProgramProofState.parse(rawValue) else { return }
        AuthService.shared.activateDevUser(id: userId)
        let program = ProgramProofProgramFactory.make(state: state, userId: userId)
        try? await DatabaseService.shared.create(program, collection: "programs", documentId: program.id)
        await ProgramStore.shared.save(program, userId: userId)
        try? await DatabaseService.shared.update(["currentProgramId": program.id], collection: "users", documentId: userId)
    }

    static func seedBindingVowForProof() async {
        AuthService.shared.activateDevUser(id: userId)
        WeeklyVowsStore.shared.save(.empty, userId: userId)
        await TrialsService.shared.ensureCurrentWeek(userId: userId)
        let cards = TrialsService.shared.state(userId: userId).currentWeekCards
        if let card = cards.first(where: { $0.kind == .overdrive }) ?? cards.first {
            TrialsService.shared.pickVowCard(card, userId: userId)
        }
    }

    static func seedWorkoutLogs(
        programStartDate: Date? = nil,
        completedDayNumbers: [Int] = [1, 2, 3, 5, 6]
    ) async {
        let now = Date()
        let lifts: [(String, Double, Int)] = [
            ("bench press", 142.5, 3),
            ("back squat", 190, 2),
            ("deadlift", 225, 1),
            ("overhead press", 92.5, 2)
        ]
        let entries = lifts.enumerated().map { offset, lift in
            ExerciseLogEntry(
                id: "dev-\(lift.0.replacingOccurrences(of: " ", with: "-"))",
                exerciseName: lift.0,
                plannedSets: 3,
                plannedReps: "\(lift.2)",
                sets: [
                    SetLog(
                        id: "dev-\(offset)-top",
                        setNumber: 1,
                        weightKg: lift.1,
                        reps: lift.2,
                        rpe: 9,
                        isWarmup: false
                    )
                ],
                skipped: false,
                notes: nil
            )
        }
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

        let calendar = Calendar.current
        for day in 1...Arc.durationDays {
            try? await DatabaseService.shared.delete(collection: "workoutLogs", documentId: "dev-program-log-day-\(day)")
        }
        for day in completedDayNumbers where day > 0 {
            let startedAt = programStartDate
                .flatMap { calendar.date(byAdding: .day, value: day - 1, to: $0) }
                ?? now.addingTimeInterval(Double(-day) * 86_400)
            let sessionEntries = [
                ExerciseLogEntry(
                    id: "dev-program-\(day)-main",
                    exerciseName: day % 2 == 0 ? "Back Squat" : "Barbell Bench Press",
                    plannedSets: 4,
                    plannedReps: day % 2 == 0 ? "3-5" : "4-6",
                    sets: (1...4).map { set in
                        SetLog(
                            id: "dev-program-\(day)-main-\(set)",
                            setNumber: set,
                            weightKg: Double(day % 2 == 0 ? 150 + day : 105 + day),
                            reps: day % 2 == 0 ? 5 : 6,
                            rpe: min(9, 7 + (day / 14)),
                            isWarmup: false
                        )
                    },
                    skipped: false,
                    notes: "Seeded debug working sets."
                ),
                ExerciseLogEntry(
                    id: "dev-program-\(day)-accessory",
                    exerciseName: day % 3 == 0 ? "Pull-Up" : "Romanian Deadlift",
                    plannedSets: 3,
                    plannedReps: day % 3 == 0 ? "6-10" : "6-8",
                    sets: (1...3).map { set in
                        SetLog(
                            id: "dev-program-\(day)-accessory-\(set)",
                            setNumber: set,
                            weightKg: day % 3 == 0 ? nil : Double(110 + day),
                            reps: day % 3 == 0 ? 8 : 8,
                            rpe: 8,
                            isWarmup: false
                        )
                    },
                    skipped: false,
                    notes: nil
                )
            ]
            let dayLog = WorkoutLog(
                id: "dev-program-log-day-\(day)",
                userId: userId,
                programId: "dev-program",
                dayNumber: day,
                plannedWorkoutName: "Dev Program Day \(day)",
                startedAt: startedAt,
                completedAt: startedAt.addingTimeInterval(3_300),
                exerciseEntries: sessionEntries,
                overallNotes: "Seeded program sandbox session.",
                overallRPE: 8,
                durationMinutes: 55
            )
            try? await DatabaseService.shared.create(dayLog, collection: "workoutLogs", documentId: dayLog.id)
        }
    }

    static func seedProgressPhotos() async {
        guard
            let before = UIImage(named: "DevProgressBefore"),
            let after = UIImage(named: "DevProgressAfter")
        else { return }

        ProfilePhotoStore.shared.set(after, userId: userId)

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let docs else { return }

        let beforePath = docs.appendingPathComponent("dev_progress_before.jpg")
        let afterPath = docs.appendingPathComponent("dev_progress_after.jpg")
        try? before.jpegData(compressionQuality: 0.9)?.write(to: beforePath, options: [.atomic])
        try? after.jpegData(compressionQuality: 0.9)?.write(to: afterPath, options: [.atomic])

        let calendar = Calendar.current
        let beforeDate = calendar.date(byAdding: .month, value: -5, to: Date()) ?? Date().addingTimeInterval(-150 * 86_400)
        let afterDate = Date()

        let beforePhoto = ProgressPhoto(
            id: "dev-progress-before",
            userId: userId,
            storageUrl: beforePath.path,
            capturedAt: beforeDate,
            note: "Before",
            angle: .front,
            blockNumber: 1,
            source: .manual
        )
        let afterPhoto = ProgressPhoto(
            id: "dev-progress-after",
            userId: userId,
            storageUrl: afterPath.path,
            capturedAt: afterDate,
            note: "After",
            angle: .front,
            blockNumber: 4,
            source: .manual
        )

        try? await DatabaseService.shared.create(beforePhoto, collection: "progressPhotos", documentId: beforePhoto.id)
        try? await DatabaseService.shared.create(afterPhoto, collection: "progressPhotos", documentId: afterPhoto.id)
    }

    static func clearDevProgress() {
        UserDefaults.standard.removeObject(forKey: badgeKey)
        UserDefaults.standard.removeObject(forKey: sessionXPKey)
        UserDefaults.standard.removeObject(forKey: didBootstrapKey)
        UserDefaults.standard.removeObject(forKey: devAccountModeKey)
        UserDefaults.standard.removeObject(forKey: "unbound.streakDays")
        DevFlags.shared.unlockAllFeatures = false
    }

    static func resetCompletedWorkouts() async {
        AuthService.shared.activateDevUser(id: userId)
        DevFlags.shared.unlockAllFeatures = true

        let defaults = UserDefaults.standard
        defaults.set(resetCompletedWorkoutsDevAccountMode, forKey: devAccountModeKey)
        defaults.removeObject(forKey: "unbound.sessionxpbonus.\(userId)")
        defaults.removeObject(forKey: "unbound.wallet.vows.grantLedger.\(userId)")

        let completionCollections = [
            "body_map_source_receipts",
            "movement_progress_source_receipts",
            "performanceLogs",
            "sessionLogs",
            "training_completion_overload_receipts",
            "training_completion_progression_receipts",
            "training_completion_records",
            "training_completion_replay_receipts",
            "vitality_reward_records",
            "workoutLogs"
        ]
        for collection in completionCollections {
            _ = try? await DatabaseService.shared.deleteWhere(
                collection: collection,
                field: "userId",
                isEqualTo: userId
            )
        }

        seedFreshSessionXP(at: Date())
        ProgramTrainingContextStore.shared.clear(userId: userId, programId: "dev-program")
        WorkoutDraftStore().clear()
        TrainingSessionDraftStore().clear()
        RoutineHistoryStore.shared.clear()
        OutboxStore.shared.clear()
    }

    static func seedFreshLoginDevAccount(services _: ServiceContainer) async {
        AuthService.shared.activateDevUser(id: userId)
        DevFlags.shared.unlockAllFeatures = true
        UserDefaults.standard.set(freshLoginDevAccountMode, forKey: devAccountModeKey)
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        UserDefaults.standard.set(true, forKey: "unbound.calibration.completed")
        UserDefaults.standard.removeObject(forKey: DevDynamicProgramScenario.activeUserDefaultsKey)
        DevProgramClock.reset()

        await clearFreshLoginDevState()

        let now = Date()
        var profile = freshLoginProfile(at: now)
        try? await DatabaseService.shared.create(profile, collection: "users", documentId: userId)

        seedFreshSessionXP(at: now)
        seedFreshAttributes(at: now)
        await seedFreshOverallLevel(at: now)
        await seedFreshSkillProgress(at: now)
        OverallRankTrialStore.shared.save(.empty, userId: userId)
        UserSkillTierStore.shared.save(.empty, userId: userId)
        WeeklyVowsStore.shared.save(.empty, userId: userId)
        seedFreshLiftTiers()
        SkinService.shared.debugResetToFreshDefaults()
        BadgeService.shared.bind(userId: userId)

        if let generated = await generateScenarioProgram(from: profile) {
            profile.currentProgramId = generated.id
            try? await DatabaseService.shared.create(profile, collection: "users", documentId: userId)
        } else {
            try? await DatabaseService.shared.create(profile, collection: "users", documentId: userId)
        }

        await SkillProgressService.shared.load(userId: userId)
        await TrialsService.shared.ensureCurrentWeek(userId: userId)
    }

    private static func clearFreshLoginDevState() async {
        let defaults = UserDefaults.standard
        let userScopedKeys = [
            badgeKey,
            sessionXPKey,
            "unbound.sessionxpbonus.\(userId)",
            "unbound.attributeProfile.\(userId)",
            "unbound.attributeHistory.\(userId)",
            "unbound.overallRankTrials.\(userId)",
            "unbound.skillTierState.\(userId)",
            "unbound.weeklyVowsState.\(userId)",
            "unbound.trialsState.\(userId)",
            "unbound.profileCosmetics.highest.\(userId)",
            "unbound.profileCosmetics.frame.\(userId)",
            "unbound.profileCosmetics.background.\(userId)",
            "unbound.wallet.vows.\(userId)",
            "unbound.wallet.vows.starterGrant.\(userId)",
            "unbound.wallet.vows.grantLedger.\(userId)",
            "unbound.shop.inventory.\(userId)",
            "unbound.shop.equippedHomeBackground.\(userId)",
            "unbound.shop.equippedBackdrop.home.\(userId)",
            "unbound.shop.equippedProfileBorder.\(userId)",
            "unbound.shop.equippedProfileBackground.\(userId)",
            "unbound.shop.equippedBackdrop.profile.\(userId)"
        ]
        userScopedKeys.forEach { defaults.removeObject(forKey: $0) }
        devLiftNames.forEach { lift in
            defaults.removeObject(forKey: "unbound.liftTier.\(userId).\(lift)")
        }
        defaults.removeObject(forKey: "unbound.streakDays")
        defaults.removeObject(forKey: "unbound.lastScanTimestamp")
        defaults.removeObject(forKey: "unbound.scanConsentGranted")
        defaults.removeObject(forKey: didBootstrapKey)

        let userOwnedCollections = [
            "analyses",
            "custom_exercises",
            "exercisePreferences",
            "movement_ap_gains",
            "movement_progress",
            "movement_progress_prior_states",
            "movement_progress_source_receipts",
            "performanceLogs",
            "program_blocks",
            "programs",
            "progress",
            "progressPhotos",
            "progression_families",
            "progression_states",
            "scanDeltaReports",
            "scans",
            "sessionLogs",
            "training_completion_overload_receipts",
            "training_completion_progression_receipts",
            "training_completion_records",
            "training_completion_replay_receipts",
            "travel_overrides",
            "workingWeights",
            "workoutLogs"
        ]
        for collection in userOwnedCollections {
            _ = try? await DatabaseService.shared.deleteWhere(
                collection: collection,
                field: "userId",
                isEqualTo: userId
            )
        }
        try? await DatabaseService.shared.delete(collection: "overall_level_progress", documentId: userId)
        try? await DatabaseService.shared.delete(collection: "skillProgress", documentId: userId)

        SavedWorkoutStore.shared.clear()
        ProgramTrainingContextStore.shared.clear(userId: userId, programId: "dev-program")
        try? ScanCheckpointStore.shared.clear(userId: userId)

        ProgramStore.shared.clear()
        ProgramScheduleStore.shared.clear(userId: userId)
        WorkoutDraftStore().clear()
        TrainingSessionDraftStore().clear()
        RoutineHistoryStore.shared.clear()
        ProfilePhotoStore.shared.remove(userId: userId)
        OutboxStore.shared.clear()
    }

    private static func freshLoginProfile(at date: Date) -> UserProfile {
        var profile = UserProfile(
            id: userId,
            email: "fresh-dev@unbound.local",
            displayName: "Fresh Dev",
            createdAt: date,
            onboardingCompleted: true,
            totalScans: 0,
            currentProgramId: nil,
            heightCm: 178,
            weightKg: 76,
            age: 26,
            biologicalSex: .male
        )
        profile.displayHandle = "freshdev"
        profile.gender = .male
        profile.motivations = [.discipline, .strength]
        profile.currentBodyType = .skinnyFat
        profile.experience = .tried
        profile.currentFrequency = .oneToTwo
        profile.targetFrequency = .four
        profile.equipment = [.dumbbells, .bench, .pullupBar, .bands, .bodyweight]
        profile.obstacles = [.consistency, .time]
        profile.sessionLength = .fortyFive
        profile.priorAttempts = [.youtube, .otherApps]
        profile.dietQuality = 6
        profile.sleepQuality = 6
        profile.stressLevel = 5
        profile.commitment = 7
        profile.goals = [.buildMuscle, .getStronger, .athletic]
        profile.targetAreas = [.fullBody, .back, .shoulders, .core]
        profile.workoutTime = .evening
        profile.workoutMinuteOfDay = 18 * 60
        profile.exerciseStyles = [.compoundLifts, .calisthenics, .mobility]
        profile.trainingFeedbackMode = .quick
        profile.trainingStyleOverride = .hybrid
        profile.trainingDays = [.monday, .wednesday, .friday, .saturday]
        return profile
    }

    private static func seedFreshSessionXP(at date: Date) {
        let record = SessionXPRecord.empty(userId: userId, weekStart: mondayWeekStart(for: date))
        if let data = try? JSONEncoder.unbound.encode(record) {
            UserDefaults.standard.set(data, forKey: sessionXPKey)
        }
        UserDefaults.standard.set(0, forKey: "unbound.streakDays")
        let delta = SessionXPDelta(previous: record, updated: record, streakExtended: false, streakBroken: false)
        NotificationCenter.default.post(name: .sessionXPUpdated, object: nil, userInfo: ["delta": delta])
    }

    private static func seedFreshAttributes(at date: Date) {
        AttributeProfileStore.shared.save(.empty(userId: userId, at: date))
        NotificationCenter.default.post(name: .attributeRankUp, object: nil)
    }

    private static func seedFreshOverallLevel(at date: Date) async {
        let progress = OverallLevelProgress(
            userId: userId,
            totalXP: OverallLevelCurve.xpRequired(forLevel: 1),
            lastGainedXP: 0,
            processedSourceLogIds: [],
            processedSourceRewards: [:],
            updatedAt: date
        )
        try? await DatabaseService.shared.create(
            progress,
            collection: "overall_level_progress",
            documentId: userId
        )
    }

    private static func seedFreshSkillProgress(at date: Date) async {
        var progress = UserSkillProgress.empty(userId: userId)
        progress.updatedAt = date
        try? await DatabaseService.shared.create(progress, collection: "skillProgress", documentId: userId)
    }

    private static func seedFreshLiftTiers() {
        devLiftNames.forEach { lift in
            LiftTierService.shared.save(tier: .initiate, lift: lift, userId: userId)
        }
    }

    private static func mondayWeekStart(for date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    static func resetSkillForProof(skillId: String) async {
        var payload: UserSkillProgress = (try? await DatabaseService.shared.read(
            collection: "skillProgress",
            documentId: userId
        )) ?? .empty(userId: userId)

        payload.nodeStates[skillId] = .locked
        payload.provenAt.removeValue(forKey: skillId)
        payload.updatedAt = Date()

        try? await DatabaseService.shared.create(payload, collection: "skillProgress", documentId: userId)
        await SkillProgressService.shared.load(userId: userId)
    }

    static func resetActiveGoalsForProof() async {
        var payload: UserSkillProgress = (try? await DatabaseService.shared.read(
            collection: "skillProgress",
            documentId: userId
        )) ?? .empty(userId: userId)

        payload.activeGoalIds = []
        payload.updatedAt = Date()

        try? await DatabaseService.shared.create(payload, collection: "skillProgress", documentId: userId)
        await SkillProgressService.shared.load(userId: userId)
    }

    static func seedScheduledSkillProof(skillId: String) async {
        guard let node = SkillGraph.shared.node(id: skillId) else { return }

        var payload: UserSkillProgress = (try? await DatabaseService.shared.read(
            collection: "skillProgress",
            documentId: userId
        )) ?? .empty(userId: userId)

        var schedule = payload.weeklySchedule.count == 7
            ? payload.weeklySchedule
            : Array(repeating: nil, count: 7)
        schedule[mondayZeroIndex(for: Date())] = category(for: node.cluster)

        payload.activeGoalIds = [skillId]
        payload.bookmarkedNodeIds.insert(skillId)
        payload.weeklySchedule = schedule
        payload.updatedAt = Date()

        try? await DatabaseService.shared.create(payload, collection: "skillProgress", documentId: userId)
        await resetSkillForProof(skillId: skillId)
    }

    static func mondayZeroIndex(for date: Date) -> Int {
        let weekday = Calendar(identifier: .iso8601).component(.weekday, from: date)
        switch weekday {
        case 2: return 0
        case 3: return 1
        case 4: return 2
        case 5: return 3
        case 6: return 4
        case 7: return 5
        case 1: return 6
        default: return 0
        }
    }

    static func category(for cluster: SkillCluster) -> DayCategory {
        switch cluster {
        case .calisthenicControl: return .push
        case .pullingPower: return .pull
        case .legDominance: return .legs
        case .coreLever: return .core
        case .handstand: return .skills
        case .handstandPushup: return .push
        case .oneArmHandstand: return .skills
        case .planche: return .skills
        case .conditioning: return .conditioning
        }
    }

    static func launchArgumentValue(for key: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        for (index, argument) in arguments.enumerated() {
            if argument == key, arguments.indices.contains(index + 1) {
                return arguments[index + 1]
            }
            if argument.hasPrefix("\(key)=") {
                return String(argument.dropFirst(key.count + 1))
            }
        }
        return nil
    }

}

#endif
