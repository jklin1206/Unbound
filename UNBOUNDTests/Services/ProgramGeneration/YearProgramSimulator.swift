import XCTest
@testable import UNBOUND

struct BaselineYearProgramSimulator {
    static let fullYearSimulationDays = 365
    static let smokeSimulationDays = 56

    static var defaultSimulationDays: Int {
        guard let rawValue = ProcessInfo.processInfo.environment["UNBOUND_YEAR_SIM_DAYS"],
              let days = Int(rawValue),
              days > 0 else {
            return smokeSimulationDays
        }
        return days
    }

    static let personas: [YearSimulationPersona] = [
        YearSimulationPersona(
            id: "home-bodyweight-beginner",
            displayName: "Home Bodyweight Beginner",
            lens: "normal-user home training",
            buildIdentity: BuildIdentity(primary: .control, secondary: nil, shape: .specialist),
            trainingStyle: .bodyweight,
            equipment: [.bodyweight],
            targetFrequency: .three,
            trainingDays: [.monday, .wednesday, .friday],
            experience: .never,
            sessionLengthMinutes: 30,
            goals: ["buildMuscle", "getDefined"],
            obstacles: ["time", "consistency"],
            sleepQuality: 5,
            stressLevel: 6,
            commitment: 7,
            focusAreas: [
                FocusArea(muscleGroup: .chest, priority: 1, rationale: "Onboarding target", suggestedFocus: "Upper body density"),
                FocusArea(muscleGroup: .core, priority: 2, rationale: "Onboarding target", suggestedFocus: "Control")
            ],
            cutModeActive: false,
            adherence: .steady,
            simulatedCarryEveryNDays: 21
        ),
        YearSimulationPersona(
            id: "home-dumbbell-bench",
            displayName: "Home Dumbbell Bench User",
            lens: "home user with limited gear",
            buildIdentity: BuildIdentity(primary: .power, secondary: .control, shape: .hybrid),
            trainingStyle: .freeWeights,
            equipment: [.dumbbells, .bench, .pullupBar, .bodyweight],
            targetFrequency: .four,
            trainingDays: [.monday, .tuesday, .thursday, .saturday],
            experience: .tried,
            sessionLengthMinutes: 45,
            goals: ["getStronger", "athletic"],
            obstacles: ["unsure"],
            sleepQuality: 6,
            stressLevel: 5,
            commitment: 8,
            focusAreas: [
                FocusArea(muscleGroup: .back, priority: 1, rationale: "Onboarding target", suggestedFocus: "V taper"),
                FocusArea(muscleGroup: .shoulders, priority: 2, rationale: "Onboarding target", suggestedFocus: "Frame")
            ],
            cutModeActive: false,
            adherence: .steady
        ),
        YearSimulationPersona(
            id: "full-gym-intermediate",
            displayName: "Full Gym Intermediate",
            lens: "professional trainer baseline",
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .specialist),
            trainingStyle: .freeWeights,
            equipment: [.fullGym, .barbell, .dumbbells, .bench, .pullupBar, .machines],
            targetFrequency: .five,
            trainingDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            experience: .current,
            sessionLengthMinutes: 60,
            goals: ["buildMuscle", "getStronger", "athletic"],
            obstacles: ["plateau"],
            sleepQuality: 7,
            stressLevel: 4,
            commitment: 9,
            focusAreas: [
                FocusArea(muscleGroup: .legs, priority: 1, rationale: "Scan lag", suggestedFocus: "Lower body"),
                FocusArea(muscleGroup: .back, priority: 2, rationale: "Scan lag", suggestedFocus: "Back width")
            ],
            cutModeActive: false,
            adherence: .steady
        ),
        YearSimulationPersona(
            id: "advanced-strength",
            displayName: "Advanced Strength Athlete",
            lens: "elite-performance strength",
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .specialist),
            trainingStyle: .freeWeights,
            equipment: [.fullGym, .barbell, .dumbbells, .bench, .pullupBar, .machines],
            targetFrequency: .six,
            trainingDays: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday],
            experience: .current,
            sessionLengthMinutes: 90,
            goals: ["getStronger", "athletic"],
            obstacles: ["plateau"],
            sleepQuality: 8,
            stressLevel: 5,
            commitment: 10,
            focusAreas: [
                FocusArea(muscleGroup: .legs, priority: 1, rationale: "Performance priority", suggestedFocus: "Squat/deadlift base"),
                FocusArea(muscleGroup: .glutes, priority: 2, rationale: "Performance priority", suggestedFocus: "Posterior chain")
            ],
            cutModeActive: false,
            adherence: .aggressive,
            simulatedCarryEveryNDays: 14
        ),
        YearSimulationPersona(
            id: "advanced-calisthenics",
            displayName: "Advanced Calisthenics Athlete",
            lens: "elite-performance skill",
            buildIdentity: BuildIdentity(primary: .control, secondary: nil, shape: .specialist),
            trainingStyle: .bodyweight,
            equipment: [.bodyweight, .pullupBar, .bands],
            targetFrequency: .five,
            trainingDays: [.monday, .tuesday, .wednesday, .friday, .saturday],
            experience: .current,
            sessionLengthMinutes: 60,
            goals: ["athletic", "getDefined"],
            obstacles: ["plateau"],
            sleepQuality: 7,
            stressLevel: 5,
            commitment: 9,
            focusAreas: [
                FocusArea(muscleGroup: .core, priority: 1, rationale: "Skill target", suggestedFocus: "Lever/planche control"),
                FocusArea(muscleGroup: .shoulders, priority: 2, rationale: "Skill target", suggestedFocus: "Vertical push")
            ],
            cutModeActive: false,
            adherence: .steady,
            simulatedSkillIds: ["hs.wall-handstand-30", "pl.tuck-planche"]
        ),
        YearSimulationPersona(
            id: "travel-inconsistent",
            displayName: "Travel Inconsistent User",
            lens: "adherence stress test",
            buildIdentity: BuildIdentity(primary: .endurance, secondary: .power, shape: .hybrid),
            trainingStyle: .hybrid,
            equipment: [.fullGym, .dumbbells, .bench, .pullupBar, .bodyweight, .bands],
            targetFrequency: .four,
            trainingDays: [.monday, .wednesday, .friday, .sunday],
            experience: .used,
            sessionLengthMinutes: 45,
            goals: ["athletic", "buildMuscle"],
            obstacles: ["time", "consistency"],
            sleepQuality: 5,
            stressLevel: 8,
            commitment: 7,
            focusAreas: [
                FocusArea(muscleGroup: .chest, priority: 1, rationale: "Scan lag", suggestedFocus: "Push volume"),
                FocusArea(muscleGroup: .legs, priority: 2, rationale: "Scan lag", suggestedFocus: "Leg density")
            ],
            cutModeActive: false,
            adherence: .inconsistent
        ),
        YearSimulationPersona(
            id: "cut-mode-hybrid",
            displayName: "Hybrid Cut Mode User",
            lens: "recovery and preserve-mode stress test",
            buildIdentity: BuildIdentity(primary: .power, secondary: .endurance, shape: .hybrid),
            trainingStyle: .hybrid,
            equipment: [.fullGym, .barbell, .dumbbells, .bench, .pullupBar, .machines],
            targetFrequency: .four,
            trainingDays: [.monday, .tuesday, .thursday, .saturday],
            experience: .current,
            sessionLengthMinutes: 60,
            goals: ["getDefined", "getStronger"],
            obstacles: ["motivation", "plateau"],
            sleepQuality: 5,
            stressLevel: 7,
            commitment: 8,
            focusAreas: [
                FocusArea(muscleGroup: .back, priority: 1, rationale: "Cut preservation", suggestedFocus: "Maintain pull strength"),
                FocusArea(muscleGroup: .shoulders, priority: 2, rationale: "Cut preservation", suggestedFocus: "Frame")
            ],
            cutModeActive: true,
            adherence: .stressed
        )
    ]

    private let calendar = Calendar.fixedGMT
    private let startDate: Date
    private let personas: [YearSimulationPersona]
    private let simulationDays: Int

    init(
        personas: [YearSimulationPersona] = Self.personas,
        simulationDays: Int = Self.defaultSimulationDays
    ) {
        self.personas = personas
        self.simulationDays = simulationDays
        var components = DateComponents()
        components.calendar = Calendar.fixedGMT
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 25
        startDate = components.date!
    }

    func run() async throws -> YearSimulationReport {
        var runs: [YearPersonaRun] = []
        for persona in personas {
            let run = try await run(persona: persona)
            runs.append(run)
        }
        return YearSimulationReport(
            generatedAt: Date(),
            simulationStartDate: dateString(startDate),
            simulationDays: simulationDays,
            staticFindings: StaticTrainingLogicFinding.knownBaselineFindings,
            personaRuns: runs
        )
    }

    private func run(persona: YearSimulationPersona) async throws -> YearPersonaRun {
        var cursor = startDate
        let endDate = calendar.date(byAdding: .day, value: simulationDays, to: startDate)!
        var absoluteDay = 1
        var blockNumber = 1
        let maximumBlocks = 80
        var previousBlock: ProgramBlock?
        let simulatedBodyweightKg: Double = persona.experience == .current ? 82 : 72
        var progression = SimulationProgressionTracker(
            userId: persona.id,
            experience: persona.experience,
            bodyweightKg: simulatedBodyweightKg
        )
        var exerciseBlockCounts: [String: Int] = [:]
        var previousBlockExercises = Set<String>()
        var days: [YearDayExport] = []
        var programs: [YearProgramExport] = []
        var violations: [YearConstraintViolation] = []
        var actionLedger: [YearCoachActionExport] = []
        var weeklyVolume: [Int: [String: Int]] = [:]
        var weeklyBodyLoads: [Int: [String: BodyRegionTrainingLoad]] = [:]

        print("UNBOUND_YEAR_SIM_PROGRESS persona=\(persona.id) status=start")
        while cursor < endDate {
            if blockNumber > maximumBlocks {
                violations.append(
                    YearConstraintViolation(
                        severity: .critical,
                        day: absoluteDay,
                        date: dateString(cursor),
                        code: "year_sim_block_limit_exceeded",
                        detail: "Simulation stopped after \(maximumBlocks) generated blocks without reaching day 365."
                    )
                )
                break
            }

            print("UNBOUND_YEAR_SIM_PROGRESS persona=\(persona.id) block=\(blockNumber) day=\(absoluteDay) date=\(dateString(cursor))")
            let isCalibration = blockNumber == 1
            let keyedHistory = Dictionary(uniqueKeysWithValues: exerciseBlockCounts.map { key, count in
                (
                    key,
                    ExerciseRefreshRule.ExerciseHistory(
                        exerciseKey: key,
                        consecutiveBlocksPrescribed: count,
                        hadTierUnlock: false,
                        hadPlateauDeload: false
                    )
                )
            })

            let rollover = BlockRolloverService.resolveRollover(
                previousBlock: previousBlock,
                newFocusAreas: persona.focusAreas,
                exerciseHistory: keyedHistory,
                cutModeActive: persona.cutModeActive
            )
            if !rollover.exercisesToRotate.isEmpty {
                actionLedger.append(
                    YearCoachActionExport(
                        day: absoluteDay,
                        date: dateString(cursor),
                        kind: "rolloverRotationSuggested",
                        detail: rollover.exercisesToRotate.joined(separator: ", ")
                    )
                )
            }

            let program = try DeterministicProgramGenerator.generate(input: input(
                persona: persona,
                date: cursor,
                previousBlock: previousBlock,
                exerciseRotationsToApply: rollover.exercisesToRotate,
                progressionStates: progression.states,
                calibration: isCalibration ? .learningWeek(knownExerciseKeys: []) : .standardReady(knownExerciseKeys: Set(progression.states.keys))
            ))

            let simulatedProgram = program

            programs.append(
                YearProgramExport(
                    blockNumber: blockNumber,
                    programId: simulatedProgram.id,
                    name: simulatedProgram.name,
                    startedAt: dateString(simulatedProgram.createdAt),
                    durationDays: simulatedProgram.durationDays,
                    hasArc: simulatedProgram.currentArc != nil,
                    requiredEquipment: simulatedProgram.requiredEquipment,
                    estimatedDailyMinutes: simulatedProgram.estimatedDailyMinutes,
                    trainingDayCount: simulatedProgram.days.filter { !$0.isRestDay }.count,
                    rolloverRotationsSuggested: rollover.exercisesToRotate
                )
            )

            let currentBlockExercises = Set(simulatedProgram.days
                .compactMap { $0.workout }
                .flatMap { $0.mainExercises }
                .map(exerciseKey))
            for key in Set(previousBlockExercises).union(currentBlockExercises) {
                exerciseBlockCounts[key] = currentBlockExercises.contains(key)
                    ? (previousBlockExercises.contains(key) ? (exerciseBlockCounts[key, default: 0] + 1) : 1)
                    : 0
            }
            previousBlockExercises = currentBlockExercises

            let daysRemaining = calendar.dateComponents([.day], from: cursor, to: endDate).day ?? 0
            let daysToSimulate = min(simulatedProgram.durationDays, max(0, daysRemaining))
            if daysRemaining <= 0 {
                break
            }
            if daysToSimulate <= 0 {
                violations.append(
                    YearConstraintViolation(
                        severity: .critical,
                        day: absoluteDay,
                        date: dateString(cursor),
                        code: "year_sim_no_time_advance",
                        detail: "Generated program \(simulatedProgram.id) had durationDays=\(simulatedProgram.durationDays) with \(daysRemaining) days remaining, so the simulation could not advance."
                    )
                )
                break
            }

            for localOffset in 0..<daysToSimulate {
                let date = calendar.date(byAdding: .day, value: localOffset, to: cursor)!
                guard let programDay = simulatedProgram.days.first(where: { $0.dayNumber == localOffset + 1 }) else { continue }
                let result = await simulateDay(
                    persona: persona,
                    program: simulatedProgram,
                    day: programDay,
                    date: date,
                    absoluteDay: absoluteDay,
                    progression: &progression
                )
                days.append(result.day)
                violations.append(contentsOf: result.violations)
                actionLedger.append(contentsOf: result.actions)

                let week = ((absoluteDay - 1) / 7) + 1
                for exercise in programDay.workout?.mainExercises ?? [] where result.day.completed {
                    for muscle in exercise.muscleGroups {
                        weeklyVolume[week, default: [:]][muscle.rawValue, default: 0] += exercise.sets
                    }
                }
                if result.day.completed, !result.bodyLoads.isEmpty {
                    var weekLoads = weeklyBodyLoads[week] ?? [:]
                    for load in result.bodyLoads {
                        var current = weekLoads[load.region.rawValue] ?? BodyRegionTrainingLoad(region: load.region)
                        current.merge(load)
                        weekLoads[load.region.rawValue] = current
                    }
                    weeklyBodyLoads[week] = weekLoads
                }
                absoluteDay += 1
            }

            previousBlock = ProgramBlock(
                id: "block-\(persona.id)-\(blockNumber)",
                userId: persona.id,
                programId: simulatedProgram.id,
                blockNumber: blockNumber,
                startedAt: cursor,
                scanId: nil,
                accessoryBias: rollover.accessoryBiasResult.bias,
                cutModeActive: persona.cutModeActive,
                biasRefreshedFromPrevious: rollover.accessoryBiasResult.carriedForward,
                exerciseRotationsThisBlock: rollover.exercisesToRotate
            )

            cursor = calendar.date(byAdding: .day, value: daysToSimulate, to: cursor) ?? endDate
            blockNumber += 1
        }
        print("UNBOUND_YEAR_SIM_PROGRESS persona=\(persona.id) status=end days=\(days.count) programs=\(programs.count) violations=\(violations.count)")

        if simulationDays >= Self.fullYearSimulationDays {
            violations.append(contentsOf: annualConstraintChecks(
                persona: persona,
                days: days,
                programs: programs,
                progression: progression
            ))
        }

        return YearPersonaRun(
            persona: persona.export,
            days: days,
            programs: programs,
            weeklyVolume: weeklyVolume
                .keys
                .sorted()
                .map { YearWeeklyVolumeExport(week: $0, setsByMuscle: weeklyVolume[$0] ?? [:]) },
            weeklyBodyRegionLoad: weeklyBodyLoads
                .keys
                .sorted()
                .map { YearWeeklyBodyRegionLoadExport(week: $0, loadsByRegion: weeklyBodyLoads[$0] ?? [:]) },
            progressionSummary: progression.summary,
            coachActionLedger: actionLedger,
            violations: violations
        )
    }

    private func simulateDay(
        persona: YearSimulationPersona,
        program: TrainingProgram,
        day: ProgramDay,
        date: Date,
        absoluteDay: Int,
        progression: inout SimulationProgressionTracker
    ) async -> DaySimulationResult {
        guard !day.isRestDay, let workout = day.workout else {
            let bodyLoads = BodyRegionTrainingLedger.loads(for: recoveryDraft(
                persona: persona,
                activities: day.recoveryActivities,
                date: date
            ))
            return DaySimulationResult(
                day: YearDayExport(
                    absoluteDay: absoluteDay,
                    date: dateString(date),
                    blockDay: day.dayNumber,
                    label: day.label,
                    isRestDay: true,
                    completed: true,
                    workoutName: nil,
                    estimatedMinutes: 0,
                    exercises: [],
                    notes: []
                ),
                violations: [],
                actions: [],
                bodyLoads: bodyLoads
            )
        }

        var violations: [YearConstraintViolation] = []
        var actions: [YearCoachActionExport] = []
        let missed = shouldMissWorkout(persona: persona, absoluteDay: absoluteDay)
        let travel = isTravelDay(persona: persona, absoluteDay: absoluteDay)
        let stressed = isStressSpike(persona: persona, absoluteDay: absoluteDay)
        let modifierContext = DailyWorkoutModifierContext(
            availableEquipment: travel ? [.bodyweight, .bands] : nil,
            deloadFactor: stressed ? 0.75 : nil
        )
        let scheduledSkillIds = scheduledSkillIds(for: persona, absoluteDay: absoluteDay)
        let shouldAttachCarry = shouldAttachCarryFinisher(persona: persona, absoluteDay: absoluteDay)
        let resolved = await MainActor.run {
            let resolvedWorkout = DailyWorkoutResolver.resolvedWorkout(
                from: workout,
                scheduledSkillIds: scheduledSkillIds,
                modifierContext: modifierContext
            )
            var draft = DailyWorkoutResolver.programDraft(
                from: workout,
                userId: persona.id,
                programId: program.id,
                dayNumber: day.dayNumber,
                date: date,
                scheduledSkillIds: scheduledSkillIds,
                modifierContext: modifierContext,
                progressionStates: progression.states
            )
            if shouldAttachCarry {
                draft.blocks.append(carryFinisherBlock())
            }
            return (workoutApplyingResolvedPrescriptions(resolvedWorkout, draft: draft), draft)
        }
        let effectiveWorkout = resolved.0
        let bodyLoads = missed ? [] : BodyRegionTrainingLedger.loads(for: resolved.1)

        if !scheduledSkillIds.isEmpty {
            actions.append(YearCoachActionExport(
                day: absoluteDay,
                date: dateString(date),
                kind: "scheduledSkillAttached",
                detail: "Simulation attached skill work: \(scheduledSkillIds.joined(separator: ", "))."
            ))
        }
        if shouldAttachCarry {
            actions.append(YearCoachActionExport(
                day: absoluteDay,
                date: dateString(date),
                kind: "carryFinisherAttached",
                detail: "Simulation attached a loaded carry finisher to test joint/tendon stress accounting."
            ))
        }

        if travel {
            actions.append(YearCoachActionExport(
                day: absoluteDay,
                date: dateString(date),
                kind: "travelModifierExpected",
                detail: "User is traveling; simulation checks the app-resolved workout after bodyweight/band substitutions."
            ))
        }
        if stressed {
            actions.append(YearCoachActionExport(
                day: absoluteDay,
                date: dateString(date),
                kind: "recoveryAdjustmentExpected",
                detail: "High stress/low sleep week should reduce friction or volume."
            ))
        }

        if effectiveWorkout.estimatedMinutes > persona.sessionLengthMinutes + 10 {
            violations.append(YearConstraintViolation(
                severity: .warning,
                day: absoluteDay,
                date: dateString(date),
                code: "session_length_overage",
                detail: "\(effectiveWorkout.name) estimates \(effectiveWorkout.estimatedMinutes)m for a \(persona.sessionLengthMinutes)m onboarding answer."
            ))
        }

        if effectiveWorkout.warmup.isEmpty {
            violations.append(YearConstraintViolation(
                severity: .info,
                day: absoluteDay,
                date: dateString(date),
                code: "empty_warmup",
                detail: "\(effectiveWorkout.name) has no generated warmup."
            ))
        }

        let exercises = effectiveWorkout.mainExercises.map { exercise -> YearExerciseExport in
            let compatibilityEquipment: [Equipment] = travel ? [.bodyweight, .bands] : persona.equipment
            if let definition = MovementCatalog.canonicalExercise(named: exercise.name),
               !MovementCatalog.isProgramCompatible(definition, style: travel ? .bodyweight : persona.trainingStyle, userEquipment: compatibilityEquipment) {
                violations.append(YearConstraintViolation(
                    severity: .critical,
                    day: absoluteDay,
                    date: dateString(date),
                    code: "equipment_mismatch",
                    detail: "\(exercise.name) does not fit available equipment \(compatibilityEquipment.map(\.rawValue).joined(separator: ", "))."
                ))
            } else if MovementCatalog.canonicalExercise(named: exercise.name) == nil {
                violations.append(YearConstraintViolation(
                    severity: .warning,
                    day: absoluteDay,
                    date: dateString(date),
                    code: "uncatalogued_exercise",
                    detail: "\(exercise.name) could not be resolved in MovementCatalog."
                ))
            }

            let outcome = progression.log(
                exercise: exercise,
                date: date,
                shouldGrind: stressed || absoluteDay % 43 == 0,
                shouldUnderperform: missed || absoluteDay % 37 == 0,
                cutModeActive: persona.cutModeActive
            )
            if outcome.bumpedOnGrindyRPE {
                violations.append(YearConstraintViolation(
                    severity: .warning,
                    day: absoluteDay,
                    date: dateString(date),
                    code: "progressed_on_grindy_rpe",
                    detail: "\(exercise.name) progressed after top-range reps at RPE \(outcome.rpe), which should probably be held or reviewed."
                ))
            }
            if outcome.accessoryRepCeilingTooHigh {
                violations.append(YearConstraintViolation(
                    severity: .warning,
                    day: absoluteDay,
                    date: dateString(date),
                    code: "accessory_rep_ceiling_runaway",
                    detail: "\(exercise.name) accessory rep ceiling reached \(outcome.targetRepMaxAfter); load may never bump."
                ))
            }

            return YearExerciseExport(
                name: exercise.name,
                sets: exercise.sets,
                reps: exercise.reps,
                rpe: exercise.rpe,
                completedSets: missed ? 0 : exercise.sets,
                simulatedTopSetReps: missed ? 0 : outcome.reps,
                simulatedTopSetHoldSeconds: missed ? nil : outcome.holdSeconds,
                simulatedTopSetRPE: missed ? nil : outcome.rpe,
                simulatedWeightKg: outcome.weightKg,
                classification: outcome.classification.rawValue,
                substitution: exercise.substitution
            )
        }

        return DaySimulationResult(
            day: YearDayExport(
                absoluteDay: absoluteDay,
                date: dateString(date),
                blockDay: day.dayNumber,
                label: day.label,
                isRestDay: false,
                completed: !missed,
                workoutName: effectiveWorkout.name,
                estimatedMinutes: effectiveWorkout.estimatedMinutes,
                exercises: exercises,
                notes: [
                    travel ? "travel" : nil,
                    stressed ? "stress-spike" : nil,
                    missed ? "missed" : nil,
                    !scheduledSkillIds.isEmpty ? "skill-attached" : nil,
                    shouldAttachCarry ? "carry-finisher" : nil
                ].compactMap { $0 }
            ),
            violations: violations,
            actions: actions,
            bodyLoads: bodyLoads
        )
    }

    private func scheduledSkillIds(for persona: YearSimulationPersona, absoluteDay: Int) -> [String] {
        guard !persona.simulatedSkillIds.isEmpty else { return [] }
        let week = max(0, (absoluteDay - 1) / 7)
        return [persona.simulatedSkillIds[week % persona.simulatedSkillIds.count]]
    }

    private func workoutApplyingResolvedPrescriptions(
        _ workout: Workout,
        draft: TrainingSessionDraft
    ) -> Workout {
        let prescriptions = draft.blocks.flatMap(\.prescriptions)
        var resolved = workout
        resolved.mainExercises = workout.mainExercises.map { exercise in
            guard let prescription = prescriptions.first(where: {
                MovementCatalog.normalized($0.exerciseName) == MovementCatalog.normalized(exercise.name)
            }) else { return exercise }
            var updated = exercise
            updated.sets = prescription.sets
            updated.reps = prescription.target.displayText
            updated.restSeconds = prescription.restSeconds
            updated.rpe = prescription.rpe
            updated.suggestedWeightKg = prescription.suggestedWeightKg
            return updated
        }
        return resolved
    }

    private func shouldAttachCarryFinisher(persona: YearSimulationPersona, absoluteDay: Int) -> Bool {
        guard let cadence = persona.simulatedCarryEveryNDays, cadence > 0 else { return false }
        return absoluteDay % cadence == 0
    }

    private func carryFinisherBlock() -> TrainingBlock {
        TrainingBlock(
            kind: .carry,
            title: "Loaded Carry Finisher",
            prescriptions: [
                TrainingBlockPrescription(
                    exerciseName: "Farmer Carry",
                    sets: 3,
                    target: .distanceMeters(40),
                    restSeconds: 90,
                    muscleGroups: [.back, .arms, .shoulders]
                )
            ]
        )
    }

    private func recoveryDraft(
        persona: YearSimulationPersona,
        activities: [RecoveryActivity],
        date: Date
    ) -> TrainingSessionDraft {
        let mobilityActivities = activities.filter { activity in
            let text = "\(activity.name) \(activity.description)".lowercased()
            return text.contains("mobility") || text.contains("hips") || text.contains("shoulders")
        }
        guard !mobilityActivities.isEmpty else {
            return TrainingSessionDraft(
                userId: persona.id,
                source: .routine,
                title: "Rest Day Recovery",
                date: date,
                estimatedMinutes: 0,
                blocks: []
            )
        }

        return TrainingSessionDraft(
            userId: persona.id,
            source: .routine,
            title: "Rest Day Mobility",
            date: date,
            estimatedMinutes: mobilityActivities.reduce(0) { $0 + $1.durationMinutes },
            blocks: [
                TrainingBlock(
                    kind: .routine,
                    title: "Mobility Flow",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Deep Squat Hold",
                            sets: 2,
                            target: .holdSeconds(45),
                            restSeconds: 20
                        ),
                        TrainingBlockPrescription(
                            exerciseName: "Shoulder Dislocates",
                            sets: 2,
                            target: .repsRange(10, 15),
                            restSeconds: 20
                        )
                    ]
                )
            ]
        )
    }

    private func input(
        persona: YearSimulationPersona,
        date: Date,
        previousBlock: ProgramBlock?,
        exerciseRotationsToApply: [String],
        progressionStates: [String: ProgressionState],
        calibration: ProgramCalibrationInput
    ) -> ProgramGeneratorInput {
        ProgramGeneratorInput(
            userId: persona.id,
            scanId: nil,
            analysisId: nil,
            buildIdentity: persona.buildIdentity,
            trainingStyle: persona.trainingStyle,
            equipment: persona.equipment,
            targetFrequency: persona.targetFrequency,
            trainingDays: persona.trainingDays,
            experience: persona.experience,
            sessionLengthMinutes: persona.sessionLengthMinutes,
            focusAreas: persona.focusAreas,
            cutModeActive: persona.cutModeActive,
            trainingFeedbackMode: TrainingFeedbackMode.default(for: persona.experience),
            progressionStates: progressionStates,
            previousBlock: previousBlock,
            exerciseRotationsToApply: exerciseRotationsToApply,
            weightKg: persona.experience == .current ? 82 : 72,
            heightCm: 178,
            age: persona.experience == .never ? 22 : 29,
            sex: .male,
            blockStartDate: date,
            exercisePreferences: [],
            calibration: calibration,
            engagedSkillIds: Set(persona.simulatedSkillIds)
        )
    }

    private func annualConstraintChecks(
        persona: YearSimulationPersona,
        days: [YearDayExport],
        programs: [YearProgramExport],
        progression: SimulationProgressionTracker
    ) -> [YearConstraintViolation] {
        var violations: [YearConstraintViolation] = []
        let completed = days.filter { !$0.isRestDay && $0.completed }.count
        let missed = days.filter { !$0.isRestDay && !$0.completed }.count
        if completed == 0 {
            violations.append(YearConstraintViolation(
                severity: .critical,
                day: nil,
                date: nil,
                code: "no_completed_training",
                detail: "\(persona.displayName) completed zero training sessions."
            ))
        }
        if missed > completed / 2 && persona.adherence != .inconsistent {
            violations.append(YearConstraintViolation(
                severity: .warning,
                day: nil,
                date: nil,
                code: "unexpected_adherence_collapse",
                detail: "\(persona.displayName) missed \(missed) sessions against \(completed) completed."
            ))
        }
        if programs.filter({ $0.hasArc }).count < 10 {
            violations.append(YearConstraintViolation(
                severity: .critical,
                day: nil,
                date: nil,
                code: "insufficient_annual_arcs",
                detail: "Only \(programs.filter { $0.hasArc }.count) arc programs generated across the simulated year."
            ))
        }
        if persona.cutModeActive && progression.summary.totalWeightBumps > 0 {
            violations.append(YearConstraintViolation(
                severity: .critical,
                day: nil,
                date: nil,
                code: "cut_mode_weight_bumps",
                detail: "Cut-mode persona recorded \(progression.summary.totalWeightBumps) simulated weight bumps."
            ))
        }
        return violations
    }

    private func shouldMissWorkout(persona: YearSimulationPersona, absoluteDay: Int) -> Bool {
        switch persona.adherence {
        case .steady:
            return absoluteDay % 61 == 0
        case .aggressive:
            return absoluteDay % 89 == 0
        case .inconsistent:
            return absoluteDay % 11 == 0 || (absoluteDay >= 120 && absoluteDay <= 127)
        case .stressed:
            return absoluteDay % 29 == 0
        }
    }

    private func isTravelDay(persona: YearSimulationPersona, absoluteDay: Int) -> Bool {
        persona.adherence == .inconsistent && ((80...87).contains(absoluteDay) || (210...218).contains(absoluteDay))
    }

    private func isStressSpike(persona: YearSimulationPersona, absoluteDay: Int) -> Bool {
        persona.stressLevel >= 7 && absoluteDay % 23 == 0
    }

    private func dateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }

    private func exerciseKey(_ exercise: Exercise) -> String {
        if let definition = MovementCatalog.canonicalExercise(named: exercise.name) {
            return MovementCatalog.normalized(definition.canonicalExerciseName ?? definition.displayName)
        }
        return MovementCatalog.normalized(exercise.name)
    }

    private func prescriptionSignature(_ program: TrainingProgram) -> String {
        program.days.map { day in
            guard let workout = day.workout else { return "\(day.dayNumber):rest" }
            let exercises = workout.mainExercises.map {
                "\($0.name)|\($0.sets)|\($0.reps)|\($0.rpe ?? -1)"
            }.joined(separator: ",")
            return "\(day.dayNumber):\(exercises)"
        }.joined(separator: ";")
    }
}
