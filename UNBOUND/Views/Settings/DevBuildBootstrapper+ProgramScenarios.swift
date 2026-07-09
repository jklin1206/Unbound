#if DEBUG
import SwiftUI
import UserNotifications
import UIKit

extension DevBuildBootstrapper {
    static func seedProgram(
        startDate: Date = Date(),
        arcState: ArcState = .active
    ) async {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: startDate)
        let workouts: [Workout] = [
            Workout(
                name: "Push Strength",
                targetMuscleGroups: [.chest, .shoulders, .arms],
                warmup: [],
                mainExercises: [
                    Exercise(id: "dev-bench", name: "Barbell Bench Press", muscleGroups: [.chest, .shoulders, .arms], sets: 4, reps: "4-6", restSeconds: 180, rpe: 8, notes: "Pause the first rep. Stop one rep before grind.", substitution: "Dumbbell Bench Press"),
                    Exercise(id: "dev-incline-db", name: "Incline Dumbbell Press", muscleGroups: [.chest, .shoulders, .arms], sets: 3, reps: "8-10", restSeconds: 120, rpe: 8, notes: nil, substitution: "Push-Up"),
                    Exercise(id: "dev-ohp", name: "Overhead Press", muscleGroups: [.shoulders, .arms], sets: 3, reps: "5-7", restSeconds: 150, rpe: 8, notes: nil, substitution: "Dumbbell OHP")
                ],
                cooldown: [],
                estimatedMinutes: 55,
                notes: "Debug seeded push session.",
                blockType: .intensification
            ),
            Workout(
                name: "Lower Output",
                targetMuscleGroups: [.legs, .glutes, .core],
                warmup: [],
                mainExercises: [
                    Exercise(id: "dev-squat", name: "Back Squat", muscleGroups: [.legs, .glutes, .core], sets: 4, reps: "3-5", restSeconds: 180, rpe: 8, notes: nil, substitution: nil),
                    Exercise(id: "dev-rdl", name: "Romanian Deadlift", muscleGroups: [.legs, .glutes, .back], sets: 3, reps: "6-8", restSeconds: 150, rpe: 8, notes: nil, substitution: nil),
                    Exercise(id: "dev-split-squat", name: "Bulgarian Split Squat", muscleGroups: [.legs, .glutes], sets: 3, reps: "8-10", restSeconds: 90, rpe: 8, notes: nil, substitution: "Reverse Lunge")
                ],
                cooldown: [],
                estimatedMinutes: 60,
                notes: "Debug seeded lower session.",
                blockType: .intensification
            ),
            Workout(
                name: "Pull Volume",
                targetMuscleGroups: [.back, .lats, .arms],
                warmup: [],
                mainExercises: [
                    Exercise(id: "dev-pullup", name: "Pull-Up", muscleGroups: [.back, .lats, .arms], sets: 4, reps: "6-10", restSeconds: 120, rpe: 8, notes: nil, substitution: "Lat Pulldown"),
                    Exercise(id: "dev-row", name: "Chest-Supported Row", muscleGroups: [.back, .lats, .arms], sets: 4, reps: "8-12", restSeconds: 120, rpe: 8, notes: nil, substitution: "One-Arm Dumbbell Row"),
                    Exercise(id: "dev-face-pull", name: "Face Pull", muscleGroups: [.shoulders, .traps], sets: 3, reps: "12-15", restSeconds: 75, rpe: 7, notes: nil, substitution: "Band Pull-Apart")
                ],
                cooldown: [],
                estimatedMinutes: 50,
                notes: "Debug seeded pull session.",
                blockType: .accumulation
            ),
            Workout(
                name: "Skill Control",
                targetMuscleGroups: [.core, .shoulders],
                warmup: [],
                mainExercises: [
                    Exercise(id: "dev-handstand", name: "Wall Handstand", muscleGroups: [.shoulders, .core], sets: 5, reps: "30s", restSeconds: 90, rpe: 7, notes: nil, substitution: nil),
                    Exercise(id: "dev-lsit", name: "L-Sit", muscleGroups: [.core], sets: 5, reps: "15s", restSeconds: 90, rpe: 7, notes: nil, substitution: nil),
                    Exercise(id: "dev-mobility", name: "Deep Squat Hold", muscleGroups: [.legs, .core], sets: 3, reps: "60s", restSeconds: 60, rpe: 6, notes: nil, substitution: nil)
                ],
                cooldown: [],
                estimatedMinutes: 45,
                notes: "Debug seeded skill-control session.",
                blockType: .accumulation
            ),
            Workout(
                name: "Full Body Engine",
                targetMuscleGroups: [.legs, .glutes, .back, .shoulders, .forearms],
                warmup: [],
                mainExercises: [
                    Exercise(id: "dev-deadlift", name: "Deadlift", muscleGroups: [.legs, .glutes, .back, .traps], sets: 3, reps: "3-5", restSeconds: 180, rpe: 8, notes: "Leave one clean rep in reserve.", substitution: "Trap Bar Deadlift"),
                    Exercise(id: "dev-push-press", name: "Dumbbell Push Press", muscleGroups: [.shoulders, .arms, .legs], sets: 3, reps: "6-8", restSeconds: 120, rpe: 8, notes: nil, substitution: "Landmine Press"),
                    Exercise(id: "dev-farmer", name: "Farmer Carry", muscleGroups: [.forearms, .traps, .core], sets: 4, reps: "40m", restSeconds: 90, rpe: 8, notes: nil, substitution: "Suitcase Carry")
                ],
                cooldown: [],
                estimatedMinutes: 55,
                notes: "Debug seeded full-body session.",
                blockType: .intensification
            )
        ]

        let weeklyPlan: [(label: String, role: SessionRole, workoutIndex: Int?)] = [
            ("Push Strength", .pushHorizontal, 0),
            ("Lower Output", .squatFocus, 1),
            ("Pull Volume", .pull, 2),
            ("Recovery", .rest, nil),
            ("Skill Control", .skillOnly, 3),
            ("Full Body Engine", .fullBody, 4),
            ("Recovery", .rest, nil)
        ]

        let days = (1...Arc.durationDays).map { day in
            let plan = weeklyPlan[(day - 1) % weeklyPlan.count]
            let isRest = plan.workoutIndex == nil
            let workout = plan.workoutIndex.map { workouts[$0] }
            return ProgramDay(
                id: "dev-day-\(day)",
                dayNumber: day,
                label: isRest ? "Recovery" : plan.label,
                isRestDay: isRest,
                workout: workout,
                sessionRole: plan.role,
                nutritionOverride: nil,
                recoveryActivities: isRest ? [
                    RecoveryActivity(id: "dev-recovery-\(day)", name: "Walk + Mobility", description: "Zone 2 walk with hip and shoulder range work.", durationMinutes: 30, frequency: "Today")
                ] : []
            )
        }

        let arc = Arc(
            id: "dev-arc-1",
            programId: "dev-program",
            startDate: startDate,
            state: arcState
        )
        let program = TrainingProgram(
            id: "dev-program",
            scanId: "dev-scan",
            analysisId: "dev-analysis",
            userId: userId,
            createdAt: startDate,
            name: "Dev Ascension Block",
            description: "Seeded \(Arc.durationDays)-day debug Arc with strength, skill, recovery, scan, and nutrition surfaces populated.",
            durationDays: Arc.durationDays,
            days: days,
            nutritionPlan: NutritionPlan(
                dailyCalories: 2850,
                proteinGrams: 180,
                carbsGrams: 330,
                fatGrams: 80,
                mealCount: 4,
                meals: [],
                hydrationLiters: 3.2,
                supplements: ["Creatine", "Electrolytes"],
                notes: "Debug nutrition target.",
                restDayCalories: 2550,
                restDayProteinGrams: 180,
                restDayCarbsGrams: 260,
                restDayFatGrams: 85
            ),
            recoveryPlan: RecoveryPlan(
                sleepHoursTarget: 8,
                restDaysPerWeek: 2,
                activities: [
                    RecoveryActivity(id: "dev-sleep", name: "Sleep Window", description: "Eight hour target with a consistent shutdown ritual.", durationMinutes: 480, frequency: "Daily")
                ],
                notes: "Debug recovery target."
            ),
            difficultyLevel: .advanced,
            requiredEquipment: ["Barbell", "Dumbbells", "Bench", "Pullup Bar", "Cable or Band"],
            estimatedDailyMinutes: 55,
            rationale: nil,
            arcs: [arc],
            currentArcId: arc.id
        )

        let block = ProgramBlock(
            id: "dev-program-block-1",
            userId: userId,
            programId: program.id,
            blockNumber: 1,
            startedAt: startDate,
            endedAt: arcState == .checkpointDue ? arc.endDate : nil,
            scanId: "dev-scan-latest",
            accessoryBias: [.shoulders: 2, .lats: 2, .glutes: 1],
            cutModeActive: false,
            biasRefreshedFromPrevious: false,
            exerciseRotationsThisBlock: ["Barbell Bench Press", "Back Squat", "Pull-Up"]
        )

        try? await DatabaseService.shared.create(program, collection: "programs", documentId: program.id)
        await ProgramStore.shared.save(program, userId: userId)
        try? await DatabaseService.shared.update(["currentProgramId": program.id], collection: "users", documentId: userId)
        await ProgramBlockStore.shared.save(block)
    }

    static func seedProgramScanSandbox(
        services: ServiceContainer,
        state: DevProgramSandboxState
    ) async {
        UserDefaults.standard.removeObject(forKey: DevDynamicProgramScenario.activeUserDefaultsKey)
        await activate(services: services, completeOnboarding: true)
        let calendar = Calendar.current
        let start = calendar.date(
            byAdding: .day,
            value: state.startOffsetDays,
            to: calendar.startOfDay(for: Date())
        ) ?? Date()
        await seedProgram(startDate: start, arcState: state.arcState)
        await seedWorkoutLogs(
            programStartDate: start,
            completedDayNumbers: completedTrainingDays(count: state.completedDayCount)
        )
        await seedScanHistory(daysAgo: state.scanDaysAgo)
    }

    static func seedDynamicProgramScenario(
        services: ServiceContainer,
        scenario: DevDynamicProgramScenario
    ) async {
        UserDefaults.standard.set(scenario.rawValue, forKey: DevDynamicProgramScenario.activeUserDefaultsKey)
        await activate(services: services, completeOnboarding: true)
        guard var profile: UserProfile = try? await DatabaseService.shared.read(
            collection: "users",
            documentId: userId
        ) else {
            return
        }

        let config = dynamicScenarioConfig(scenario)
        profile.experience = config.experience
        profile.targetFrequency = config.targetFrequency
        profile.currentFrequency = .fivePlus
        profile.equipment = config.equipment
        profile.exerciseStyles = config.exerciseStyles
        profile.trainingStyleOverride = config.trainingStyle
        profile.trainingFeedbackMode = .detailed
        profile.sessionLength = .fortyFive
        profile.trainingDays = [.monday, .tuesday, .wednesday, .thursday, .friday]
        try? await DatabaseService.shared.create(profile, collection: "users", documentId: userId)

        await seedDynamicProgressionStates(for: scenario)
        let generated = await generateScenarioProgram(from: profile)
        guard var program = generated ?? ProgramStore.shared.program ?? ProgramStore.shared.loadLocal(userId: userId) else {
            return
        }
        if generated != nil {
            program = alignScenarioProgramToVisibleTrainingDay(program)
            await ProgramStore.shared.save(program, userId: userId)
            try? await DatabaseService.shared.create(program, collection: "programs", documentId: program.id)
        }

        ProgramTrainingContextStore.shared.clear(userId: userId, programId: "dev-program")
        ProgramTrainingContextStore.shared.clear(userId: userId, programId: program.id)
        await seedDynamicProgramFocuses(config.skillIds, weekPhase: config.weekPhase)
        setPreferredDynamicScenarioDate(for: scenario)

        switch scenario {
        case .calisthenicsWeekBands:
            ProgramTrainingContextStore.shared.saveDailyContext(
                selection: ProgramTrainingContextSelection(
                    scope: .thisWeek,
                    mode: .calisthenics,
                    equipment: [.bodyweight, .bands],
                    experience: .tried
                ),
                userId: userId,
                programId: program.id,
                anchorDate: DevProgramClock.now
            )

        case .nextBlockLifting:
            ProgramTrainingContextStore.shared.savePendingNextBlockContext(
                selection: ProgramTrainingContextSelection(
                    scope: .nextBlock,
                    mode: .lifting,
                    equipment: [.barbell, .dumbbells, .bench],
                    experience: .current
                ),
                userId: userId,
                programId: program.id
            )

        case .programQALab:
            program = await seedProgramQALabFixtures(in: program)
            await ProgramStore.shared.save(program, userId: userId)
            try? await DatabaseService.shared.create(program, collection: "programs", documentId: program.id)

        case .freeformProtected:
            if let scheduled = seedProtectedFreeformWorkout(in: program) {
                program = scheduled
                await ProgramStore.shared.save(program, userId: userId)
                try? await DatabaseService.shared.create(program, collection: "programs", documentId: program.id)
            }
            ProgramTrainingContextStore.shared.saveDailyContext(
                selection: ProgramTrainingContextSelection(
                    scope: .thisWeek,
                    mode: .calisthenics,
                    equipment: [.bodyweight, .pullupBar, .bands],
                    experience: .tried
                ),
                userId: userId,
                programId: program.id,
                anchorDate: DevProgramClock.now
            )

        case .oneSkillLifting, .sixSkillHybrid:
            break
        }

        await MainActor.run {
            NotificationCenter.default.post(name: .requestNavigateToProgramTab, object: nil)
        }
    }

    static func dynamicScenarioConfig(_ scenario: DevDynamicProgramScenario) -> (
        trainingStyle: TrainingStyle,
        equipment: [Equipment],
        exerciseStyles: [ExerciseStyle],
        experience: Experience,
        targetFrequency: TargetFrequency,
        skillIds: [String],
        weekPhase: WeekPhase
    ) {
        switch scenario {
        case .programQALab:
            return (
                .hybrid,
                [.barbell, .dumbbells, .bench, .pullupBar, .dipStation, .rings, .bands, .bodyweight],
                [.compoundLifts, .calisthenics, .mobility, .steadyCardio],
                .current,
                .five,
                ["pp.muscle-up", "cal.ring-dip", "ld.pistol-squat", "cl.tuck-front-lever", "hs.wall-handstand-30", "pl.tuck-planche"],
                .moderate
            )
        case .oneSkillLifting:
            return (
                .freeWeights,
                [.barbell, .dumbbells, .bench],
                [.compoundLifts, .isolation, .mobility],
                .current,
                .four,
                ["pp.pullup"],
                .moderate
            )
        case .sixSkillHybrid:
            return (
                .hybrid,
                [.barbell, .dumbbells, .bench, .pullupBar, .dipStation, .rings, .bands, .bodyweight],
                [.compoundLifts, .calisthenics, .mobility, .steadyCardio],
                .current,
                .six,
                ["pp.pullup", "cal.pushup", "ld.pistol-squat", "cl.tuck-front-lever", "hs.wall-handstand-30", "pl.tuck-planche"],
                .heavy
            )
        case .calisthenicsWeekBands:
            return (
                .hybrid,
                [.barbell, .dumbbells, .bench, .pullupBar, .bodyweight],
                [.compoundLifts, .calisthenics, .mobility],
                .tried,
                .five,
                ["cal.pushup", "pp.pullup", "cl.hollow-body-30"],
                .light
            )
        case .nextBlockLifting:
            return (
                .bodyweight,
                [.bodyweight, .pullupBar, .rings, .bands],
                [.calisthenics, .mobility],
                .current,
                .five,
                ["pp.muscle-up", "cal.ring-dip", "hs.wall-handstand-30"],
                .moderate
            )
        case .freeformProtected:
            return (
                .hybrid,
                [.dumbbells, .bench, .pullupBar, .bands, .bodyweight],
                [.compoundLifts, .calisthenics, .cardioIntervals, .mobility],
                .current,
                .four,
                ["pp.pullup", "cal.pushup"],
                .deload
            )
        }
    }

    static func generateScenarioProgram(from profile: UserProfile) async -> TrainingProgram? {
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
            await ProgramStore.shared.save(program, userId: userId)
            try? await DatabaseService.shared.create(program, collection: "programs", documentId: program.id)
            try? await DatabaseService.shared.update(["currentProgramId": program.id], collection: "users", documentId: userId)
            return program
        } catch {
            LoggingService.shared.log(
                "Dev dynamic program generation failed: \(error)",
                level: .error,
                context: ["userId": userId]
            )
            return nil
        }
    }

    static func seedDynamicProgressionStates(for scenario: DevDynamicProgramScenario) async {
        let states: [ProgressionState]
        switch scenario {
        case .programQALab, .oneSkillLifting, .nextBlockLifting, .sixSkillHybrid, .freeformProtected:
            states = [
                dynamicProgressionState(
                    exercise: "Barbell Bench Press",
                    weightKg: 60,
                    reps: 6...9,
                    targetRPE: 8,
                    block: .accumulation
                ),
                dynamicProgressionState(
                    exercise: "Dumbbell Bench Press",
                    weightKg: 28,
                    reps: 8...10,
                    targetRPE: 8,
                    block: .accumulation
                ),
                dynamicProgressionState(
                    exercise: "Decline Press",
                    weightKg: 62.5,
                    reps: 6...9,
                    targetRPE: 8,
                    block: .accumulation
                ),
                dynamicProgressionState(
                    exercise: "Landmine Press",
                    weightKg: 35,
                    reps: 8...11,
                    targetRPE: 8,
                    block: .accumulation
                ),
                dynamicProgressionState(
                    exercise: "Barbell Row",
                    weightKg: 72.5,
                    reps: 6...8,
                    targetRPE: 8,
                    block: .accumulation
                ),
                dynamicProgressionState(
                    exercise: "Back Squat",
                    weightKg: 92.5,
                    reps: 5...8,
                    targetRPE: 8,
                    block: .accumulation
                )
            ]
        case .calisthenicsWeekBands:
            states = [
                dynamicProgressionState(
                    exercise: "Pushup",
                    weightKg: 0,
                    reps: 10...16,
                    targetRPE: 7,
                    block: .accumulation
                ),
                dynamicProgressionState(
                    exercise: "Pullup",
                    weightKg: 0,
                    reps: 4...7,
                    targetRPE: 7,
                    block: .accumulation
                )
            ]
        }

        for state in states {
            await ProgressionStateStore.shared.save(state)
        }
    }

    static func dynamicProgressionState(
        exercise: String,
        weightKg: Double,
        reps: ClosedRange<Int>,
        targetRPE: Int,
        block: BlockType
    ) -> ProgressionState {
        var state = ProgressionState.seed(
            userId: userId,
            exercise: exercise,
            startingWeightKg: weightKg,
            block: block
        )
        state.displayName = exercise
        state.targetRepMin = reps.lowerBound
        state.targetRepMax = reps.upperBound
        state.targetRPE = targetRPE
        state.consecutiveSessionsAtTarget = 1
        state.updatedAt = Date()
        return state
    }

    static func alignScenarioProgramToVisibleTrainingDay(_ program: TrainingProgram) -> TrainingProgram {
        guard let trainingIndex = program.days.firstIndex(where: { !$0.isRestDay && $0.workout != nil }) else {
            return program
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: DevProgramClock.today)
        let alignedStart = calendar.date(byAdding: .day, value: -trainingIndex, to: today) ?? today
        let alignedArcs = program.arcs.map { arc in
            guard arc.id == program.currentArcId || (program.currentArcId == nil && arc.id == program.arcs.last?.id) else {
                return arc
            }
            return Arc(
                id: arc.id,
                programId: arc.programId,
                startDate: alignedStart,
                state: arc.state,
                sourceArcID: arc.sourceArcID
            )
        }

        return TrainingProgram(
            id: program.id,
            scanId: program.scanId,
            analysisId: program.analysisId,
            userId: program.userId,
            createdAt: alignedStart,
            name: program.name,
            description: program.description,
            durationDays: program.durationDays,
            days: program.days,
            nutritionPlan: program.nutritionPlan,
            recoveryPlan: program.recoveryPlan,
            difficultyLevel: program.difficultyLevel,
            requiredEquipment: program.requiredEquipment,
            estimatedDailyMinutes: program.estimatedDailyMinutes,
            rationale: program.rationale,
            arcs: alignedArcs,
            currentArcId: program.currentArcId
        )
    }

    static func seedDynamicProgramFocuses(
        _ skillIds: [String],
        weekPhase: WeekPhase
    ) async {
        let validIds = Set(skillIds.filter { SkillGraph.shared.node(id: $0) != nil })
        let now = Date()
        let optimized = ProgramScheduler.shared.optimizedWeeklySchedule(programFocusIds: validIds)
        var progress = UserSkillProgress.empty(userId: userId)
        progress.nodeStates = Dictionary(uniqueKeysWithValues: validIds.map { ($0, NodeState.proven) })
        progress.provenAt = Dictionary(uniqueKeysWithValues: validIds.map { ($0, now) })
        progress.bookmarkedNodeIds = validIds
        progress.activeGoalIds = validIds
        progress.weeklySchedule = optimized.map(Optional.some)
        progress.currentWeekPhase = weekPhase
        progress.updatedAt = now
        try? await DatabaseService.shared.create(progress, collection: "skillProgress", documentId: userId)
        await SkillProgressService.shared.load(userId: userId)
    }

    @discardableResult
    static func setPreferredDynamicScenarioDate(for scenario: DevDynamicProgramScenario) -> Int {
        guard scenario != .freeformProtected else {
            return DevProgramClock.reset()
        }

        for offset in 0..<7 {
            let date = DevProgramClock.today(offset: offset)
            if ProgramScheduler.shared.skillIds(forDate: date).isEmpty == false {
                return DevProgramClock.setDayOffset(offset)
            }
        }

        return DevProgramClock.reset()
    }

    static func seedProgramQALabFixtures(in program: TrainingProgram) async -> TrainingProgram {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: DevProgramClock.today)
        let now = Date()
        let savedWorkouts = programQALabSavedWorkouts(now: now)

        SavedWorkoutStore.shared.clear()
        savedWorkouts.forEach { SavedWorkoutStore.shared.save($0) }

        await MainActor.run {
            ProgramScheduleStore.shared.clear(userId: userId)
            WorkoutDraftStore().clear()

            if let todayWorkout = savedWorkouts.first {
                ProgramScheduleStore.shared.replacePrimary(
                    on: today,
                    userId: userId,
                    programId: program.id,
                    with: ProgramScheduleOccurrence(
                        id: UUID(uuidString: "00000000-0000-0000-0000-00000000E401") ?? UUID(),
                        userId: userId,
                        programId: program.id,
                        date: today,
                        kind: .saved,
                        title: todayWorkout.title,
                        savedWorkoutId: todayWorkout.id,
                        attachScheduledSkills: true,
                        adaptsWithProgression: true,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            }

            let plannedOffsets = [1, 3, 6]
            for (index, workout) in savedWorkouts.dropFirst().enumerated() {
                let offset = plannedOffsets.indices.contains(index) ? plannedOffsets[index] : index + 1
                let date = calendar.date(byAdding: .day, value: offset, to: today) ?? today
                ProgramScheduleStore.shared.upsert(
                    ProgramScheduleOccurrence(
                        id: UUID(uuidString: "00000000-0000-0000-0000-00000000E40\(index + 2)") ?? UUID(),
                        userId: userId,
                        programId: program.id,
                        date: date,
                        kind: .saved,
                        title: workout.title,
                        savedWorkoutId: workout.id,
                        attachScheduledSkills: true,
                        adaptsWithProgression: true,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            }
        }

        if let firstDraft = savedWorkouts.first?.asDraft(
            userId: userId,
            date: today,
            programId: program.id,
            dayNumber: 1
        ) {
            TrainingSessionDraftStore().saveRecent(firstDraft)
        }

        ProgramTrainingContextStore.shared.saveDailyContext(
            selection: ProgramTrainingContextSelection(
                scope: .thisWeek,
                mode: .calisthenics,
                equipment: [.bodyweight, .pullupBar, .rings, .bands],
                experience: .current
            ),
            userId: userId,
            programId: program.id,
            anchorDate: today
        )
        ProgramTrainingContextStore.shared.savePendingNextBlockContext(
            selection: ProgramTrainingContextSelection(
                scope: .nextBlock,
                mode: .lifting,
                equipment: [.barbell, .dumbbells, .bench, .pullupBar],
                experience: .current
            ),
            userId: userId,
            programId: program.id
        )

        let startDate = BlockRolloverScheduler.activeStartDate(for: program)
        await seedWorkoutLogs(
            programStartDate: startDate,
            completedDayNumbers: [1, 2, 3, 5, 6, 8, 9, 10]
        )
        await seedScanHistory(daysAgo: 31)

        return program
    }

    static func programQALabSavedWorkouts(now: Date) -> [SavedWorkout] {
        [
            SavedWorkout(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000D401") ?? UUID(),
                title: "QA Handstand Push Prep",
                blocks: [
                    TrainingBlock(
                        kind: .skill,
                        title: "Handstand Skill",
                        skillId: "hs.wall-handstand-30",
                        prescriptions: [
                            TrainingBlockPrescription(
                                exerciseName: "Wall Handstand",
                                sets: 5,
                                target: .holdSeconds(30),
                                restSeconds: 90,
                                muscleGroups: [.shoulders, .core],
                                rpe: 7,
                                notes: "Quality first. Stop before the line collapses."
                            ),
                            TrainingBlockPrescription(
                                exerciseName: "Pike Push-Up",
                                sets: 4,
                                target: .repsRange(5, 8),
                                restSeconds: 120,
                                muscleGroups: [.shoulders, .chest, .arms],
                                rpe: 8
                            )
                        ]
                    ),
                    TrainingBlock(
                        kind: .strength,
                        title: "Push Support",
                        prescriptions: [
                            TrainingBlockPrescription(
                                exerciseName: "Dumbbell Bench Press",
                                sets: 3,
                                target: .repsRange(8, 10),
                                restSeconds: 105,
                                muscleGroups: [.chest, .shoulders, .arms],
                                rpe: 8,
                                suggestedWeightKg: 28
                            ),
                            TrainingBlockPrescription(
                                exerciseName: "Band Face Pull",
                                sets: 3,
                                target: .repsRange(12, 15),
                                restSeconds: 60,
                                muscleGroups: [.shoulders, .traps],
                                rpe: 7
                            )
                        ]
                    )
                ],
                order: 1,
                preferredEquipment: [.bodyweight, .dumbbells, .bench, .bands],
                sessionRole: "push",
                createdAt: now,
                updatedAt: now
            ),
            SavedWorkout(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000D402") ?? UUID(),
                title: "QA Muscle-Up Pull",
                blocks: [
                    TrainingBlock(
                        kind: .skill,
                        title: "Muscle-Up Skill",
                        skillId: "pp.muscle-up",
                        prescriptions: [
                            TrainingBlockPrescription(
                                exerciseName: "Chest-to-Bar Pull-Up",
                                sets: 5,
                                target: .repsRange(2, 4),
                                restSeconds: 150,
                                muscleGroups: [.back, .lats, .arms],
                                rpe: 8
                            ),
                            TrainingBlockPrescription(
                                exerciseName: "Band-Assisted Muscle-Up Transition",
                                sets: 4,
                                target: .repsRange(2, 4),
                                restSeconds: 120,
                                muscleGroups: [.back, .lats, .chest, .arms],
                                rpe: 7
                            )
                        ]
                    ),
                    TrainingBlock(
                        kind: .strength,
                        title: "Pull Support",
                        prescriptions: [
                            TrainingBlockPrescription(
                                exerciseName: "Ring Row",
                                sets: 4,
                                target: .repsRange(8, 12),
                                restSeconds: 75,
                                muscleGroups: [.back, .lats, .arms],
                                rpe: 8
                            ),
                            TrainingBlockPrescription(
                                exerciseName: "Hollow Body Hold",
                                sets: 4,
                                target: .holdSeconds(25),
                                restSeconds: 45,
                                muscleGroups: [.core],
                                rpe: 7
                            )
                        ]
                    )
                ],
                order: 2,
                preferredEquipment: [.pullupBar, .rings, .bands, .bodyweight],
                sessionRole: "pull",
                createdAt: now,
                updatedAt: now
            ),
            SavedWorkout(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000D403") ?? UUID(),
                title: "QA Pistol Lower",
                blocks: [
                    TrainingBlock(
                        kind: .skill,
                        title: "Pistol Skill",
                        skillId: "ld.pistol-squat",
                        prescriptions: [
                            TrainingBlockPrescription(
                                exerciseName: "Box Pistol Squat",
                                sets: 5,
                                target: .repsRange(3, 5),
                                restSeconds: 120,
                                muscleGroups: [.legs, .glutes, .core],
                                rpe: 8
                            ),
                            TrainingBlockPrescription(
                                exerciseName: "Cossack Squat",
                                sets: 3,
                                target: .repsRange(6, 8),
                                restSeconds: 75,
                                muscleGroups: [.legs, .glutes],
                                rpe: 7
                            )
                        ]
                    ),
                    TrainingBlock(
                        kind: .strength,
                        title: "Lower Support",
                        prescriptions: [
                            TrainingBlockPrescription(
                                exerciseName: "Goblet Squat",
                                sets: 4,
                                target: .repsRange(8, 10),
                                restSeconds: 90,
                                muscleGroups: [.legs, .glutes, .core],
                                rpe: 8,
                                suggestedWeightKg: 32
                            )
                        ]
                    )
                ],
                order: 3,
                preferredEquipment: [.bodyweight, .dumbbells, .bench],
                sessionRole: "lower",
                createdAt: now,
                updatedAt: now
            ),
            SavedWorkout(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000D404") ?? UUID(),
                title: "QA Hybrid Strength",
                blocks: [
                    TrainingBlock(
                        kind: .strength,
                        title: "Strength",
                        prescriptions: [
                            TrainingBlockPrescription(
                                exerciseName: "Back Squat",
                                sets: 4,
                                target: .repsRange(4, 6),
                                restSeconds: 180,
                                muscleGroups: [.legs, .glutes, .core],
                                rpe: 8,
                                suggestedWeightKg: 92.5
                            ),
                            TrainingBlockPrescription(
                                exerciseName: "Pull-Up",
                                sets: 4,
                                target: .repsRange(5, 8),
                                restSeconds: 120,
                                muscleGroups: [.back, .lats, .arms],
                                rpe: 8
                            ),
                            TrainingBlockPrescription(
                                exerciseName: "Farmer Carry",
                                sets: 4,
                                target: .distanceMeters(35),
                                restSeconds: 90,
                                muscleGroups: [.forearms, .traps, .core],
                                rpe: 8
                            )
                        ]
                    )
                ],
                order: 4,
                preferredEquipment: [.barbell, .dumbbells, .pullupBar],
                sessionRole: "full-body",
                createdAt: now,
                updatedAt: now
            )
        ]
    }

    static func seedProtectedFreeformWorkout(in program: TrainingProgram) -> TrainingProgram? {
        let saved = SavedWorkout(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000D411") ?? UUID(),
            title: "Dev Freeform Control",
            blocks: [
                TrainingBlock(
                    kind: .strength,
                    title: "Lift",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Dumbbell Bench Press",
                            sets: 4,
                            target: .repsRange(8, 10),
                            restSeconds: 105,
                            muscleGroups: [.chest, .shoulders]
                        ),
                        TrainingBlockPrescription(
                            exerciseName: "Pull-Up",
                            sets: 4,
                            target: .repsRange(5, 8),
                            restSeconds: 120,
                            muscleGroups: [.back, .lats, .arms]
                        )
                    ]
                ),
                TrainingBlock(
                    kind: .carry,
                    title: "Carry",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Farmer Carry",
                            sets: 4,
                            target: .distanceMeters(35),
                            restSeconds: 90,
                            muscleGroups: [.forearms, .traps, .core]
                        )
                    ]
                ),
                TrainingBlock(
                    kind: .cardio,
                    title: "Finish",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Bike Sprint",
                            sets: 6,
                            target: .timedSeconds(20),
                            restSeconds: 100,
                            muscleGroups: []
                        )
                    ]
                )
            ],
            preferredEquipment: [.dumbbells, .pullupBar, .bands],
            sessionRole: "custom"
        )
        SavedWorkoutStore.shared.save(saved)
        return try? SavedWorkoutScheduler.schedule(
            saved,
            on: [1],
            in: program,
            userId: userId,
            replacingCustomizedDays: true
        )
    }

}

#endif
