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
        UserDefaults.standard.removeObject(forKey: "unbound.streakDays")
        DevFlags.shared.unlockAllFeatures = false
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
