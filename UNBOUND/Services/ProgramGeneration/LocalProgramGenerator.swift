import Foundation

// MARK: - LocalProgramGenerator
//
// Rule-based 12-week TrainingProgram generator that runs entirely on-device.
// Replaces the remote network call in the legacy ProgramGenerationService.
//
// Inputs (from UserProfile + archetype):
//   - archetype           → signature-lift emphasis
//   - targetFrequency     → sessions per week (3/4/5/6)
//   - equipment           → exercise pool filtering
//   - experience          → starting intensity + volume
//   - sessionLength       → per-session volume cap
//   - exerciseStyles      → accessory-slot bias
//   - targetAreas         → accessory-slot weighting
//
// Output: 12-week TrainingProgram (84 days, split into 3 Arcs of 4 weeks)
// with sessions balanced by archetype signature movements.
//
// Design: hand-tuned templates per archetype rather than a full programming
// engine. Each archetype gets a "split philosophy" + signature-lift emphasis
// per Arc (progression through the 12 weeks). Exercise selection respects
// equipment availability; sets/reps respect experience level.

enum LocalProgramGenerator {

    // MARK: Entry point

    static func generate(
        archetype: Archetype,
        targetFrequency: TargetFrequency?,
        equipment: Set<Equipment>,
        experience: Experience?,
        sessionLength: SessionLength?,
        exerciseStyles: Set<ExerciseStyle>,
        targetAreas: Set<TargetArea>,
        goals: Set<Goal> = [],
        obstacles: Set<Obstacle> = [],
        sleepQuality: Int = 5,
        stressLevel: Int = 5,
        currentFrequency: Frequency? = nil,
        commitment: Int = 8,
        displayHandle: String = "",
        age: Int = 0,
        gender: Gender = .unspecified,
        heightCm: Double = 0,
        weightKg: Double = 0,
        preferences: [ExercisePreference] = [],
        progressionStates: [ProgressionState] = [],
        familyStates: [ProgressionFamilyState] = [],
        customExercises: [CustomExercise] = [],
        calibrations: [CalibrationBaseline] = [],
        forceDeload: Bool = false,
        archetypeRank: SubRank = .eMinus,
        userId: String,
        scanId: String = UUID().uuidString,
        analysisId: String = UUID().uuidString
    ) -> TrainingProgram {

        // Target frequency must not exceed current frequency + 2 (smooth ramp).
        // Example: currently 0 days → floor caps target at 2.
        let daysPerWeek = rampedDaysPerWeek(
            target: targetFrequency,
            current: currentFrequency
        )
        let minutesPerSession = adjustedSessionMinutes(
            baseline: sessionLength?.minutes ?? 45,
            obstacles: obstacles
        )
        let difficulty = difficultyLevel(for: experience)
        let availableEquipment = equipment.isEmpty ? [Equipment.bodyweight] : Array(equipment)

        // Index preferences + progression state by canonical exercise key
        // (lowercased exercise name) so per-exercise lookups are O(1).
        let prefsByKey = Dictionary(
            uniqueKeysWithValues: preferences.map { ($0.exerciseName.lowercased(), $0) }
        )
        var statesByKey = Dictionary(
            uniqueKeysWithValues: progressionStates.map { ($0.exerciseKey, $0) }
        )

        // Calibration baselines override existing progression state when the
        // user has logged a known number. Unknown baselines fall through so
        // archetype defaults still get a chance to render.
        for baseline in calibrations where baseline.isKnown && baseline.kind == .weight {
            guard let kg = baseline.weightInKg, kg > 0 else { continue }
            statesByKey[baseline.exerciseKey] = ProgressionState.seed(
                userId: userId,
                exercise: baseline.exerciseKey,
                startingWeightKg: kg
            )
        }

        let familyTiers: [String: Int] = Dictionary(
            uniqueKeysWithValues: familyStates.map { ($0.family, $0.unlockedTier) }
        )

        // Generate 84 days (12 weeks). Block schedule for the final arc is
        // rank-gated: realization unlocks at B-, peaking unlocks at A-.
        let realizationUnlocked = archetypeRank.ordinal >= SubRank.bMinus.ordinal
        let peakingUnlocked = archetypeRank.ordinal >= SubRank.aMinus.ordinal

        var days: [ProgramDay] = []
        for day in 1...84 {
            let weekNumber = (day - 1) / 7 + 1
            let dayInWeek = (day - 1) % 7 + 1
            let arcNumber = (weekNumber - 1) / 4 + 1     // 1, 2, or 3
            let weekInArc = ((weekNumber - 1) % 4) + 1   // 1..4

            // Resolve which block this week falls under.
            let blockForWeek = scheduledBlock(
                week: weekNumber,
                realizationUnlocked: realizationUnlocked,
                peakingUnlocked: peakingUnlocked
            )

            let isRest = !trainingDayMap(daysPerWeek: daysPerWeek).contains(dayInWeek)
            if isRest {
                days.append(ProgramDay(
                    id: UUID().uuidString,
                    dayNumber: day,
                    label: "Rest day",
                    isRestDay: true,
                    workout: nil,
                    nutritionOverride: nil,
                    recoveryActivities: []
                ))
            } else {
                let sessionIndex = trainingDayMap(daysPerWeek: daysPerWeek)
                    .firstIndex(of: dayInWeek) ?? 0
                let workout = generateWorkout(
                    archetype: archetype,
                    arcNumber: arcNumber,
                    weekInArc: weekInArc,
                    sessionIndex: sessionIndex,
                    daysPerWeek: daysPerWeek,
                    equipment: availableEquipment,
                    targetAreas: targetAreas,
                    experience: experience,
                    minutesPerSession: minutesPerSession,
                    exerciseStyles: exerciseStyles,
                    goals: goals,
                    obstacles: obstacles,
                    sleepQuality: sleepQuality,
                    stressLevel: stressLevel,
                    commitment: commitment,
                    prefsByKey: prefsByKey,
                    statesByKey: statesByKey,
                    familyTiers: familyTiers,
                    customExercises: customExercises,
                    forceDeload: forceDeload && weekNumber == 1,
                    blockForWeek: blockForWeek
                )
                days.append(ProgramDay(
                    id: UUID().uuidString,
                    dayNumber: day,
                    label: workout.name,
                    isRestDay: false,
                    workout: workout,
                    nutritionOverride: nil,
                    recoveryActivities: []
                ))
            }
        }

        let rationale = buildRationale(
            archetype: archetype,
            daysPerWeek: daysPerWeek,
            minutesPerSession: minutesPerSession,
            equipment: availableEquipment,
            exerciseStyles: exerciseStyles,
            goals: goals,
            obstacles: obstacles,
            sleepQuality: sleepQuality,
            stressLevel: stressLevel,
            currentFrequency: currentFrequency,
            commitment: commitment,
            experience: experience,
            displayHandle: displayHandle,
            age: age,
            gender: gender,
            heightCm: heightCm,
            weightKg: weightKg,
            targetAreas: targetAreas,
            archetypeRank: archetypeRank,
            realizationUnlocked: realizationUnlocked,
            peakingUnlocked: peakingUnlocked
        )

        return TrainingProgram(
            id: UUID().uuidString,
            scanId: scanId,
            analysisId: analysisId,
            userId: userId,
            createdAt: Date(),
            archetype: archetype,
            name: programName(for: archetype),
            description: programDescription(for: archetype),
            durationDays: 84,
            days: days,
            nutritionPlan: defaultNutritionPlan(experience: experience),
            recoveryPlan: defaultRecoveryPlan(daysPerWeek: daysPerWeek),
            difficultyLevel: difficulty,
            requiredEquipment: availableEquipment.map(\.rawValue),
            estimatedDailyMinutes: minutesPerSession,
            rationale: rationale
        )
    }

    // MARK: Preview rationale — built from in-flight onboarding answers
    //
    // Used during onboarding reveal before the full program generator runs
    // post-paywall. Same shape as the real rationale so the reveal copy
    // matches what lands on Program Overview.

    static func previewRationale(
        archetype: Archetype,
        targetFrequency: TargetFrequency?,
        equipment: Set<Equipment>,
        experience: Experience?,
        sessionLength: SessionLength?,
        exerciseStyles: Set<ExerciseStyle>,
        targetAreas: Set<TargetArea>,
        goals: Set<Goal>,
        obstacles: Set<Obstacle>,
        sleepQuality: Int,
        stressLevel: Int,
        currentFrequency: Frequency?,
        commitment: Int,
        displayHandle: String,
        age: Int,
        gender: Gender,
        heightCm: Double,
        weightKg: Double,
        archetypeRank: SubRank = .eMinus
    ) -> ProgramRationale {
        let daysPerWeek = rampedDaysPerWeek(target: targetFrequency, current: currentFrequency)
        let minutes = adjustedSessionMinutes(
            baseline: sessionLength?.minutes ?? 45,
            obstacles: obstacles
        )
        let available = equipment.isEmpty ? [Equipment.bodyweight] : Array(equipment)
        return buildRationale(
            archetype: archetype,
            daysPerWeek: daysPerWeek,
            minutesPerSession: minutes,
            equipment: available,
            exerciseStyles: exerciseStyles,
            goals: goals,
            obstacles: obstacles,
            sleepQuality: sleepQuality,
            stressLevel: stressLevel,
            currentFrequency: currentFrequency,
            commitment: commitment,
            experience: experience,
            displayHandle: displayHandle,
            age: age,
            gender: gender,
            heightCm: heightCm,
            weightKg: weightKg,
            targetAreas: targetAreas,
            archetypeRank: archetypeRank,
            realizationUnlocked: archetypeRank.ordinal >= SubRank.bMinus.ordinal,
            peakingUnlocked: archetypeRank.ordinal >= SubRank.aMinus.ordinal
        )
    }

    // MARK: Frequency → which days of week

    /// Returns day-of-week indexes (1-based, Mon..Sun). E.g. 3 days/week = [1, 3, 5].
    private static func trainingDayMap(daysPerWeek: Int) -> [Int] {
        switch daysPerWeek {
        case 3:  return [1, 3, 5]
        case 4:  return [1, 2, 4, 5]
        case 5:  return [1, 2, 3, 5, 6]
        case 6:  return [1, 2, 3, 4, 5, 6]
        default: return [1, 3, 5]
        }
    }

    private static func frequencyDays(_ freq: TargetFrequency?) -> Int {
        switch freq {
        case .three: return 3
        case .four:  return 4
        case .five:  return 5
        case .six:   return 6
        case nil:    return 4
        }
    }

    private static func difficultyLevel(for experience: Experience?) -> DifficultyLevel {
        switch experience {
        case .never, .tried:  return .beginner
        case .used:           return .intermediate
        case .current:        return .intermediate
        case nil:             return .beginner
        }
    }

    // MARK: Workout generation — archetype + arc progression

    private static func generateWorkout(
        archetype: Archetype,
        arcNumber: Int,
        weekInArc: Int,
        sessionIndex: Int,
        daysPerWeek: Int,
        equipment: [Equipment],
        targetAreas: Set<TargetArea>,
        experience: Experience?,
        minutesPerSession: Int,
        exerciseStyles: Set<ExerciseStyle>,
        goals: Set<Goal>,
        obstacles: Set<Obstacle>,
        sleepQuality: Int,
        stressLevel: Int,
        commitment: Int,
        prefsByKey: [String: ExercisePreference] = [:],
        statesByKey: [String: ProgressionState] = [:],
        familyTiers: [String: Int] = [:],
        customExercises: [CustomExercise] = [],
        forceDeload: Bool = false,
        blockForWeek: BlockType = .accumulation
    ) -> Workout {
        let split = splitPattern(for: archetype, daysPerWeek: daysPerWeek)
        let pattern = split[sessionIndex % split.count]

        let warmup = generateWarmup(pattern: pattern, equipment: equipment)
        let mainExercises = generateMain(
            pattern: pattern,
            archetype: archetype,
            arcNumber: arcNumber,
            weekInArc: weekInArc,
            equipment: equipment,
            targetAreas: targetAreas,
            experience: experience,
            minutesPerSession: minutesPerSession,
            exerciseStyles: exerciseStyles,
            goals: goals,
            obstacles: obstacles,
            sleepQuality: sleepQuality,
            stressLevel: stressLevel,
            commitment: commitment,
            prefsByKey: prefsByKey,
            statesByKey: statesByKey,
            familyTiers: familyTiers,
            customExercises: customExercises,
            forceDeload: forceDeload
        )
        let cooldown = generateCooldown(pattern: pattern)

        var notes: String? = forceDeload
            ? "Deload week. Keep weights moderate, stop 3 reps short of failure. Let the CNS recover."
            : blockAwareNotes(block: blockForWeek, arcNumber: arcNumber)

        if !forceDeload {
            if exerciseStyles.contains(.cardioIntervals) {
                notes = (notes ?? "") + " Finisher: 4 rounds · 30s work / 30s rest. Pick a conditioning tool (bike, rower, burpees)."
            } else if exerciseStyles.contains(.steadyCardio) {
                notes = (notes ?? "") + " Add 15 min easy Zone 2 after the session — walk, bike, or row."
            }
        }

        let name = forceDeload
            ? "Deload · \(pattern.name)"
            : sessionName(pattern: pattern, archetype: archetype, arcNumber: arcNumber)

        return Workout(
            name: name,
            targetMuscleGroups: pattern.muscleGroups,
            warmup: warmup,
            mainExercises: mainExercises,
            cooldown: cooldown,
            estimatedMinutes: minutesPerSession,
            notes: notes,
            blockType: forceDeload ? .deload : blockForWeek
        )
    }

    // MARK: Session split — what body parts on what day

    private struct SessionPattern {
        let name: String
        let muscleGroups: [MuscleGroup]
        let focus: SessionFocus
    }

    private enum SessionFocus {
        case push, pull, legs, fullBody, upper, lower, pullFocused, pushFocused, corePower
    }

    private static func splitPattern(for archetype: Archetype, daysPerWeek: Int) -> [SessionPattern] {
        // Archetype biases the split — V-TAPER does more pull, UNIT does more legs, etc.
        let basePullDay = SessionPattern(name: "Pull", muscleGroups: [.back, .lats, .arms, .forearms], focus: .pull)
        let basePushDay = SessionPattern(name: "Push", muscleGroups: [.chest, .shoulders, .arms], focus: .push)
        let baseLegsDay = SessionPattern(name: "Legs", muscleGroups: [.legs, .glutes, .calves], focus: .legs)
        let baseUpperDay = SessionPattern(name: "Upper body", muscleGroups: [.chest, .back, .shoulders, .arms], focus: .upper)
        let baseLowerDay = SessionPattern(name: "Lower body + core", muscleGroups: [.legs, .glutes, .core], focus: .lower)
        let fullBodyDay = SessionPattern(name: "Full body", muscleGroups: [.chest, .back, .legs, .shoulders, .core], focus: .fullBody)
        let corePowerDay = SessionPattern(name: "Core + conditioning", muscleGroups: [.core, .shoulders, .back], focus: .corePower)

        switch (archetype, daysPerWeek) {
        case (.heavyDuty, 3): return [baseLowerDay, baseUpperDay, baseLowerDay]
        case (.heavyDuty, 4): return [baseLowerDay, baseUpperDay, baseLowerDay, baseUpperDay]
        case (.heavyDuty, 5): return [baseLegsDay, basePushDay, baseLegsDay, basePullDay, baseLowerDay]
        case (.heavyDuty, 6): return [baseLegsDay, basePushDay, baseLegsDay, basePullDay, baseLegsDay, corePowerDay]

        case (.leanCut, 3):  return [fullBodyDay, fullBodyDay, fullBodyDay]
        case (.leanCut, 4):  return [baseUpperDay, baseLowerDay, baseUpperDay, baseLowerDay]
        case (.leanCut, 5):  return [basePushDay, basePullDay, baseLegsDay, baseUpperDay, corePowerDay]
        case (.leanCut, 6):  return [basePushDay, basePullDay, baseLegsDay, basePushDay, basePullDay, corePowerDay]

        case (.shredded, 3): return [corePowerDay, fullBodyDay, corePowerDay]
        case (.shredded, 4): return [corePowerDay, baseUpperDay, corePowerDay, baseLowerDay]
        case (.shredded, 5): return [corePowerDay, basePushDay, basePullDay, corePowerDay, baseLegsDay]
        case (.shredded, 6): return [corePowerDay, basePushDay, basePullDay, corePowerDay, baseLegsDay, fullBodyDay]

        case (.vTaper, 3):   return [basePullDay, baseLegsDay, SessionPattern(name: "Push + pull", muscleGroups: [.chest, .back, .shoulders], focus: .pullFocused)]
        case (.vTaper, 4):   return [basePullDay, baseLegsDay, basePullDay, SessionPattern(name: "Shoulders + push", muscleGroups: [.shoulders, .chest, .arms], focus: .pushFocused)]
        case (.vTaper, 5):   return [basePullDay, basePushDay, baseLegsDay, basePullDay, SessionPattern(name: "Shoulders + core", muscleGroups: [.shoulders, .core], focus: .pushFocused)]
        case (.vTaper, 6):   return [basePullDay, basePushDay, baseLegsDay, basePullDay, basePushDay, corePowerDay]

        default: return [fullBodyDay, fullBodyDay, fullBodyDay, fullBodyDay]
        }
    }

    // MARK: Warmup

    private static func generateWarmup(pattern: SessionPattern, equipment: [Equipment]) -> [Exercise] {
        [
            Exercise(id: UUID().uuidString, name: "5-minute dynamic warmup", muscleGroups: pattern.muscleGroups, sets: 1, reps: "5 min", restSeconds: 0, rpe: nil, notes: "Leg swings, arm circles, cat-cow, world's greatest stretch.", substitution: nil),
            Exercise(id: UUID().uuidString, name: "Activation set", muscleGroups: pattern.muscleGroups, sets: 1, reps: "10 reps", restSeconds: 30, rpe: nil, notes: "Light version of your first main lift — grease the groove.", substitution: nil)
        ]
    }

    // MARK: Main block

    private static func generateMain(
        pattern: SessionPattern,
        archetype: Archetype,
        arcNumber: Int,
        weekInArc: Int,
        equipment: [Equipment],
        targetAreas: Set<TargetArea>,
        experience: Experience?,
        minutesPerSession: Int,
        exerciseStyles: Set<ExerciseStyle>,
        goals: Set<Goal>,
        obstacles: Set<Obstacle>,
        sleepQuality: Int,
        stressLevel: Int,
        commitment: Int,
        prefsByKey: [String: ExercisePreference] = [:],
        statesByKey: [String: ProgressionState] = [:],
        familyTiers: [String: Int] = [:],
        customExercises: [CustomExercise] = [],
        forceDeload: Bool = false
    ) -> [Exercise] {
        let slots = adjustedSlotCount(
            minutesPerSession: minutesPerSession,
            obstacles: obstacles,
            commitment: commitment
        )
        let setsRepsProfile = forceDeload
            ? deloadSetsRepsProfile()
            : setsRepsProfile(
                arcNumber: arcNumber,
                weekInArc: weekInArc,
                experience: experience,
                goals: goals,
                sleepQuality: sleepQuality,
                stressLevel: stressLevel
            )

        // Plateau breaker: more variation week-to-week when the user said
        // "hit a plateau" is their biggest obstacle.
        let variationSeed = obstacles.contains(.plateau) ? (arcNumber * 7 + weekInArc) : 0

        // Pool for this session pattern
        var pool = exercisePool(
            for: pattern.focus,
            archetype: archetype,
            equipment: equipment,
            exerciseStyles: exerciseStyles,
            familyTiers: familyTiers,
            customExercises: customExercises
        )

        // User preferences: drop anything marked `.avoid`, swap anything
        // marked `.substitute` for the user's preferred substitute.
        pool = pool.compactMap { template -> ExerciseTemplate? in
            let key = template.name.lowercased()
            guard let pref = prefsByKey[key] else { return template }
            switch pref.status {
            case .avoid:
                return nil
            case .substitute:
                // Try to find the user's preferred sub in the pool; if it's
                // not in-pattern, fall back to the catalog's default for
                // this template.
                if let subName = pref.substitutePreference,
                   let subTemplate = bundledExercisePool().first(where: {
                       $0.name.lowercased() == subName.lowercased()
                   }) {
                    return subTemplate
                }
                if let fallback = template.substitution,
                   let fbTemplate = bundledExercisePool().first(where: {
                       $0.name.lowercased() == fallback.lowercased()
                   }) {
                    return fbTemplate
                }
                return template   // worst case — keep original
            case .available:
                return template
            }
        }

        // Bias toward target areas
        pool.sort { a, b in
            let aScore = targetAreaMatch(exercise: a, targetAreas: targetAreas)
            let bScore = targetAreaMatch(exercise: b, targetAreas: targetAreas)
            return aScore > bScore
        }

        // Ensure signature-lift first for this archetype
        if let signatureIndex = pool.firstIndex(where: { isSignatureLift(exercise: $0, archetype: archetype) }) {
            let sig = pool.remove(at: signatureIndex)
            pool.insert(sig, at: 0)
        }

        // If plateau-breaking is active, rotate accessories window-to-window
        // so each week gets a different selection than the last.
        if variationSeed > 0, pool.count > slots {
            let keepSignature = pool.prefix(1)
            var accessories = Array(pool.dropFirst())
            let rotation = variationSeed % max(accessories.count, 1)
            accessories = Array(accessories[rotation...] + accessories[..<rotation])
            pool = Array(keepSignature) + accessories
        }

        let chosen = Array(pool.prefix(slots))

        return chosen.enumerated().map { (idx, template) in
            let profile = idx == 0 ? setsRepsProfile.signature : setsRepsProfile.accessory

            // If ProgressionEngine has already tracked weight for this
            // exercise, surface it in the note so the user sees their
            // current working weight on the session screen.
            let stateKey = template.name.lowercased()
            let seededNote: String? = {
                if let state = statesByKey[stateKey], state.currentWorkingWeightKg > 0 {
                    let w = String(format: "%g", state.currentWorkingWeightKg)
                    let base = template.notes ?? ""
                    return base.isEmpty
                        ? "Current working weight: \(w) kg"
                        : "\(base) · Current working: \(w) kg"
                }
                return template.notes
            }()

            return Exercise(
                id: UUID().uuidString,
                name: template.name,
                muscleGroups: template.muscleGroups,
                sets: profile.sets,
                reps: profile.reps,
                restSeconds: profile.restSeconds,
                rpe: profile.rpe,
                notes: seededNote,
                substitution: template.substitution
            )
        }
    }

    private static func exerciseSlotCount(minutesPerSession: Int) -> Int {
        switch minutesPerSession {
        case ..<35: return 3
        case ..<50: return 4
        case ..<70: return 5
        default:    return 6
        }
    }

    /// Slot count with obstacle/commitment modifiers. Time pressure (obstacle
    /// `.time`) or low commitment (≤5) trims one accessory slot, floored at 3.
    private static func adjustedSlotCount(
        minutesPerSession: Int,
        obstacles: Set<Obstacle>,
        commitment: Int
    ) -> Int {
        let base = exerciseSlotCount(minutesPerSession: minutesPerSession)
        var adjusted = base
        if obstacles.contains(.time) { adjusted -= 1 }
        if commitment <= 5 { adjusted -= 1 }
        return max(adjusted, 3)
    }

    /// Shave 5 minutes off the baseline if `.time` is flagged — we honor the
    /// session length the user picked but trim it tighter so they always
    /// finish under the clock.
    private static func adjustedSessionMinutes(baseline: Int, obstacles: Set<Obstacle>) -> Int {
        obstacles.contains(.time) ? max(baseline - 5, 25) : baseline
    }

    /// Ramp target frequency by current frequency — never prescribe more than
    /// current + 2 so the week 1 jump is survivable.
    private static func rampedDaysPerWeek(
        target: TargetFrequency?,
        current: Frequency?
    ) -> Int {
        let requested = frequencyDays(target)
        let floor: Int
        switch current {
        case .zero: floor = 2
        case .oneToTwo: floor = 3
        case .threeToFour: floor = 4
        case .fivePlus: floor = 5
        case nil: floor = requested
        }
        return min(requested, max(floor, 3))
    }

    private struct SetsRepsProfile {
        let sets: Int
        let reps: String
        let restSeconds: Int
        let rpe: Int?
    }

    private struct SessionSetsReps {
        let signature: SetsRepsProfile
        let accessory: SetsRepsProfile
    }

    private static func setsRepsProfile(
        arcNumber: Int,
        weekInArc: Int,
        experience: Experience?,
        goals: Set<Goal>,
        sleepQuality: Int,
        stressLevel: Int
    ) -> SessionSetsReps {
        // Arc 1 = Foundation, Arc 2 = Growth, Arc 3 = Power.
        // Primary goal biases rep ranges:
        //   .buildMuscle   → hypertrophy (8–12)
        //   .getStronger   → strength (3–6)
        //   .loseFat/.getDefined → higher-volume density (12–15) with short rests
        //   .athletic      → explosive / balanced
        //   .feelBetter    → balanced moderate
        let beginnerBias = (experience == .never || experience == .tried)
        let primary = primaryGoal(goals)

        // Recovery modifier: if Arc 1, knock RPE down 1 for low sleep or high stress.
        let recoveryDrop = (arcNumber == 1 && (sleepQuality <= 4 || stressLevel >= 7)) ? 1 : 0

        switch primary {
        case .getStronger:
            switch arcNumber {
            case 1:
                return SessionSetsReps(
                    signature: .init(sets: 4, reps: beginnerBias ? "6" : "5", restSeconds: 150, rpe: 7 - recoveryDrop),
                    accessory: .init(sets: 3, reps: "8", restSeconds: 90, rpe: 7 - recoveryDrop)
                )
            case 2:
                return SessionSetsReps(
                    signature: .init(sets: 5, reps: beginnerBias ? "5" : "4", restSeconds: 180, rpe: 8),
                    accessory: .init(sets: 3, reps: "6–8", restSeconds: 120, rpe: 8)
                )
            default:
                return SessionSetsReps(
                    signature: .init(sets: 5, reps: beginnerBias ? "4" : "3", restSeconds: 210, rpe: 9),
                    accessory: .init(sets: 3, reps: "5–6", restSeconds: 120, rpe: 8)
                )
            }
        case .loseFat, .getDefined:
            switch arcNumber {
            case 1:
                return SessionSetsReps(
                    signature: .init(sets: 3, reps: "12", restSeconds: 60, rpe: 7 - recoveryDrop),
                    accessory: .init(sets: 3, reps: "12–15", restSeconds: 45, rpe: 7 - recoveryDrop)
                )
            case 2:
                return SessionSetsReps(
                    signature: .init(sets: 4, reps: "10–12", restSeconds: 60, rpe: 8),
                    accessory: .init(sets: 4, reps: "12–15", restSeconds: 45, rpe: 8)
                )
            default:
                return SessionSetsReps(
                    signature: .init(sets: 4, reps: "8–10", restSeconds: 75, rpe: 9),
                    accessory: .init(sets: 4, reps: "10–15", restSeconds: 45, rpe: 8)
                )
            }
        case .buildMuscle:
            switch arcNumber {
            case 1:
                return SessionSetsReps(
                    signature: .init(sets: 3, reps: beginnerBias ? "10" : "8–10", restSeconds: 90, rpe: 7 - recoveryDrop),
                    accessory: .init(sets: 3, reps: "10–12", restSeconds: 75, rpe: 7 - recoveryDrop)
                )
            case 2:
                return SessionSetsReps(
                    signature: .init(sets: 4, reps: "8–10", restSeconds: 120, rpe: 8),
                    accessory: .init(sets: 3, reps: "10–12", restSeconds: 75, rpe: 8)
                )
            default:
                return SessionSetsReps(
                    signature: .init(sets: 4, reps: "6–8", restSeconds: 150, rpe: 9),
                    accessory: .init(sets: 3, reps: "8–12", restSeconds: 90, rpe: 8)
                )
            }
        default:
            // Balanced / .athletic / .feelBetter / no goal set
            switch arcNumber {
            case 1:
                return SessionSetsReps(
                    signature: .init(sets: 3, reps: beginnerBias ? "8–10" : "6–8", restSeconds: 120, rpe: 7 - recoveryDrop),
                    accessory: .init(sets: 3, reps: "10–12", restSeconds: 75, rpe: 7 - recoveryDrop)
                )
            case 2:
                return SessionSetsReps(
                    signature: .init(sets: 4, reps: beginnerBias ? "6–8" : "5–6", restSeconds: 150, rpe: 8),
                    accessory: .init(sets: 3, reps: "8–12", restSeconds: 90, rpe: 8)
                )
            case 3:
                return SessionSetsReps(
                    signature: .init(sets: 5, reps: beginnerBias ? "5" : "3–5", restSeconds: 180, rpe: 9),
                    accessory: .init(sets: 3, reps: "6–10", restSeconds: 90, rpe: 8)
                )
            default:
                return SessionSetsReps(
                    signature: .init(sets: 3, reps: "8", restSeconds: 120, rpe: 7),
                    accessory: .init(sets: 3, reps: "10", restSeconds: 75, rpe: 7)
                )
            }
        }
    }

    private static func primaryGoal(_ goals: Set<Goal>) -> Goal? {
        // Priority order — first match in this list wins.
        let order: [Goal] = [.getStronger, .buildMuscle, .loseFat, .getDefined, .athletic, .feelBetter]
        return order.first { goals.contains($0) }
    }

    private static func deloadSetsRepsProfile() -> SessionSetsReps {
        SessionSetsReps(
            signature: .init(sets: 3, reps: "5", restSeconds: 150, rpe: 6),
            accessory: .init(sets: 2, reps: "8", restSeconds: 75, rpe: 6)
        )
    }

    // MARK: Exercise pool

    private struct ExerciseTemplate {
        let name: String
        let muscleGroups: [MuscleGroup]
        let focus: SessionFocus
        let requiredEquipment: [Equipment]
        let notes: String?
        let substitution: String?
    }

    private static func exercisePool(
        for focus: SessionFocus,
        archetype: Archetype,
        equipment: [Equipment],
        exerciseStyles: Set<ExerciseStyle>,
        familyTiers: [String: Int] = [:],
        customExercises: [CustomExercise] = []
    ) -> [ExerciseTemplate] {
        let calisthenicsBias = archetype == .shredded
            || exerciseStyles.contains(.calisthenics)
            || (equipment.count == 1 && equipment.contains(.bodyweight))

        let all = bundledExercisePool(
            calisthenicsBias: calisthenicsBias,
            familyTiers: familyTiers,
            customExercises: customExercises
        )
        var filtered = all.filter { template in
            guard template.focus == focus || matches(template: template, focus: focus) else { return false }
            if template.requiredEquipment.contains(.bodyweight) { return true }
            return !Set(template.requiredEquipment).isDisjoint(with: Set(equipment))
        }

        // When the user is bodyweight-only, drop every template that needs a
        // non-bodyweight item so the final pool is truly equipment-matched.
        if equipment == [.bodyweight] {
            filtered = filtered.filter { template in
                template.requiredEquipment.contains(.bodyweight)
            }
        }

        // Under calisthenics bias, float bodyweight-eligible entries to the top.
        if calisthenicsBias {
            filtered.sort { a, b in
                let aBW = a.requiredEquipment.contains(.bodyweight) ? 1 : 0
                let bBW = b.requiredEquipment.contains(.bodyweight) ? 1 : 0
                return aBW > bBW
            }
        }

        return filtered
    }

    private static func matches(template: ExerciseTemplate, focus: SessionFocus) -> Bool {
        switch focus {
        case .upper:
            return template.focus == .push || template.focus == .pull || template.focus == .pullFocused || template.focus == .pushFocused
        case .lower:
            return template.focus == .legs
        case .fullBody:
            return true
        case .pullFocused:
            return template.focus == .pull
        case .pushFocused:
            return template.focus == .push
        case .corePower:
            return template.focus == .corePower || template.focus == .pullFocused
        default:
            return false
        }
    }

    private static func isSignatureLift(exercise: ExerciseTemplate, archetype: Archetype) -> Bool {
        switch archetype {
        case .heavyDuty: return exercise.name.localizedCaseInsensitiveContains("squat") && !exercise.name.localizedCaseInsensitiveContains("goblet")
        case .leanCut:   return exercise.name.localizedCaseInsensitiveContains("bench press")
        case .shredded:  return exercise.name.localizedCaseInsensitiveContains("l-sit") || exercise.name.localizedCaseInsensitiveContains("dragon") || exercise.name.localizedCaseInsensitiveContains("plank")
        case .vTaper:    return exercise.name.localizedCaseInsensitiveContains("pullup") || exercise.name.localizedCaseInsensitiveContains("pull-up")
        }
    }

    private static func targetAreaMatch(exercise: ExerciseTemplate, targetAreas: Set<TargetArea>) -> Int {
        guard !targetAreas.isEmpty else { return 0 }
        var score = 0
        for area in targetAreas {
            if exerciseCoversArea(exercise: exercise, area: area) {
                score += 1
            }
        }
        return score
    }

    private static func exerciseCoversArea(exercise: ExerciseTemplate, area: TargetArea) -> Bool {
        let muscles = exercise.muscleGroups
        switch area {
        case .chest:     return muscles.contains(.chest)
        case .back:      return muscles.contains(.back) || muscles.contains(.lats)
        case .shoulders: return muscles.contains(.shoulders) || muscles.contains(.traps)
        case .arms:      return muscles.contains(.arms) || muscles.contains(.forearms)
        case .core:      return muscles.contains(.core)
        case .legs:      return muscles.contains(.legs) || muscles.contains(.calves)
        case .glutes:    return muscles.contains(.glutes)
        case .fullBody:  return muscles.count >= 3
        }
    }

    // MARK: Exercise pool — bundled, hand-authored

    private static func bundledExercisePool(
        calisthenicsBias: Bool = false,
        familyTiers: [String: Int] = [:],
        customExercises: [CustomExercise] = []
    ) -> [ExerciseTemplate] {
        let base: [ExerciseTemplate] = [
            // MARK: Pull movements
            .init(name: "Deadlift",            muscleGroups: [.back, .legs, .glutes, .forearms], focus: .pull, requiredEquipment: [.fullGym, .homeWeights], notes: "Brace hard. Bar stays close. Drive through the floor.", substitution: "Kettlebell deadlift"),
            .init(name: "Pullup",              muscleGroups: [.back, .lats, .arms], focus: .pull, requiredEquipment: [.fullGym, .bodyweight], notes: "Full hang start. Chest to bar when able.", substitution: "Banded pullup / lat pulldown"),
            .init(name: "Chin-up",             muscleGroups: [.back, .lats, .arms], focus: .pull, requiredEquipment: [.fullGym, .bodyweight], notes: "Underhand grip. Focus on bicep + lat contraction.", substitution: nil),
            .init(name: "Bent-over row",       muscleGroups: [.back, .lats, .arms], focus: .pull, requiredEquipment: [.fullGym, .homeWeights], notes: "Flat back, elbows in, row to lower ribs.", substitution: "Seated cable row / dumbbell row"),
            .init(name: "Dumbbell row",        muscleGroups: [.back, .lats, .arms], focus: .pull, requiredEquipment: [.homeWeights, .fullGym], notes: "One arm at a time, support on bench.", substitution: nil),
            .init(name: "Face pull",           muscleGroups: [.shoulders, .back, .traps], focus: .pull, requiredEquipment: [.fullGym, .bands], notes: "High anchor, pull to forehead, elbows high.", substitution: "Band pull-apart"),
            .init(name: "Inverted row",        muscleGroups: [.back, .lats, .arms], focus: .pull, requiredEquipment: [.bodyweight, .fullGym], notes: "Feet elevated to scale up.", substitution: nil),

            // MARK: Push movements
            .init(name: "Bench press",         muscleGroups: [.chest, .shoulders, .arms], focus: .push, requiredEquipment: [.fullGym, .homeWeights], notes: "Tight back, elbows ~45°, touch mid-chest.", substitution: "Dumbbell bench press"),
            .init(name: "Overhead press",      muscleGroups: [.shoulders, .arms, .core], focus: .push, requiredEquipment: [.fullGym, .homeWeights], notes: "Core braced, full lockout overhead.", substitution: "Seated dumbbell press"),
            .init(name: "Dumbbell bench press", muscleGroups: [.chest, .shoulders, .arms], focus: .push, requiredEquipment: [.homeWeights, .fullGym], notes: "Range of motion beats the barbell here.", substitution: nil),
            .init(name: "Incline dumbbell press", muscleGroups: [.chest, .shoulders, .arms], focus: .push, requiredEquipment: [.homeWeights, .fullGym], notes: "30–45° bench. Upper chest focus.", substitution: nil),
            .init(name: "Pushup",              muscleGroups: [.chest, .shoulders, .arms, .core], focus: .push, requiredEquipment: [.bodyweight], notes: "Elbows track back ~45°. Lock shoulders.", substitution: "Incline pushup"),
            .init(name: "Dip",                 muscleGroups: [.chest, .shoulders, .arms], focus: .push, requiredEquipment: [.bodyweight, .fullGym], notes: "Lean forward for chest, upright for triceps.", substitution: "Bench dip"),
            .init(name: "Lateral raise",       muscleGroups: [.shoulders], focus: .push, requiredEquipment: [.homeWeights, .fullGym, .bands], notes: "Lead with pinkies. Control the negative.", substitution: "Band lateral raise"),

            // MARK: Legs
            .init(name: "Back squat",          muscleGroups: [.legs, .glutes, .core], focus: .legs, requiredEquipment: [.fullGym], notes: "Chest up. Knees track over toes. Break below parallel.", substitution: "Goblet squat"),
            .init(name: "Front squat",         muscleGroups: [.legs, .glutes, .core], focus: .legs, requiredEquipment: [.fullGym], notes: "Elbows high, torso upright. Quad emphasis.", substitution: "Goblet squat"),
            .init(name: "Goblet squat",        muscleGroups: [.legs, .glutes, .core], focus: .legs, requiredEquipment: [.homeWeights, .fullGym], notes: "Hold bell at chest. Elbows between knees at bottom.", substitution: nil),
            .init(name: "Romanian deadlift",   muscleGroups: [.legs, .glutes, .back], focus: .legs, requiredEquipment: [.fullGym, .homeWeights], notes: "Hinge at hips. Barbell slides down thighs.", substitution: "Single-leg RDL"),
            .init(name: "Walking lunge",       muscleGroups: [.legs, .glutes], focus: .legs, requiredEquipment: [.bodyweight, .homeWeights, .fullGym], notes: "Step through fully. Front heel drives you up.", substitution: nil),
            .init(name: "Bulgarian split squat", muscleGroups: [.legs, .glutes], focus: .legs, requiredEquipment: [.homeWeights, .fullGym, .bodyweight], notes: "Rear foot elevated. Front-leg dominant.", substitution: nil),
            .init(name: "Pistol squat",        muscleGroups: [.legs, .glutes, .core], focus: .legs, requiredEquipment: [.bodyweight], notes: "Hold the heel down. Assist with TRX/band early.", substitution: "Box pistol"),
            .init(name: "Calf raise",          muscleGroups: [.calves], focus: .legs, requiredEquipment: [.bodyweight, .homeWeights, .fullGym], notes: "Full range. Pause at top.", substitution: nil),

            // MARK: Core / power / carries
            .init(name: "Plank",               muscleGroups: [.core], focus: .corePower, requiredEquipment: [.bodyweight], notes: "Glutes squeezed, ribs down. Quality seconds only.", substitution: nil),
            .init(name: "Hanging knee raise",  muscleGroups: [.core], focus: .corePower, requiredEquipment: [.bodyweight, .fullGym], notes: "No swinging. Controlled both directions.", substitution: "Lying knee raise"),
            .init(name: "Hanging leg raise",   muscleGroups: [.core], focus: .corePower, requiredEquipment: [.bodyweight, .fullGym], notes: "Straight legs. Pause at top.", substitution: "Hanging knee raise"),
            .init(name: "L-sit progression",   muscleGroups: [.core, .shoulders, .arms], focus: .corePower, requiredEquipment: [.bodyweight, .fullGym], notes: "Tuck → one-leg → full L. Build over weeks.", substitution: nil),
            .init(name: "Dragon flag",         muscleGroups: [.core], focus: .corePower, requiredEquipment: [.bodyweight, .fullGym], notes: "Lie on bench, grip behind head. Control the descent.", substitution: "Dragon flag negative"),
            .init(name: "Hollow rock",         muscleGroups: [.core], focus: .corePower, requiredEquipment: [.bodyweight], notes: "Lower back pressed. Rock from shoulders to hips.", substitution: nil),
            .init(name: "Farmer carry",        muscleGroups: [.forearms, .traps, .core, .legs], focus: .corePower, requiredEquipment: [.homeWeights, .fullGym], notes: "Walk tall. Dense grip. Short steps.", substitution: nil),
            .init(name: "Kettlebell swing",    muscleGroups: [.glutes, .back, .core], focus: .corePower, requiredEquipment: [.homeWeights, .fullGym], notes: "Hip hinge drives the swing. Power comes from glutes.", substitution: nil),
            .init(name: "Dead hang",           muscleGroups: [.forearms, .shoulders, .back], focus: .corePower, requiredEquipment: [.bodyweight, .fullGym], notes: "Active shoulders. Build grip for everything else.", substitution: nil)
        ]

        let customTemplates = customExercises.map(customTemplate(from:))

        guard calisthenicsBias else { return customTemplates + base }

        let pushFamily = ExerciseCatalog.progressionFamily("push")
        let pullFamily = ExerciseCatalog.progressionFamily("pull")
        let legsFamily = ExerciseCatalog.progressionFamily("legs-single")
        let coreFamily = ExerciseCatalog.progressionFamily("core-lever")

        let pushTier = familyTiers["push"] ?? 0
        let pullTier = familyTiers["pull"] ?? 0
        let legsTier = familyTiers["legs-single"] ?? 0
        let coreTier = familyTiers["core-lever"] ?? 0

        let calisthenicsExtras: [ExerciseTemplate] = [
            catalogTemplate(from: pushFamily, maxTier: pushTier, focus: .push),
            catalogTemplate(from: pullFamily, maxTier: pullTier, focus: .pull),
            catalogTemplate(from: legsFamily, maxTier: legsTier, focus: .legs),
            catalogTemplate(from: coreFamily, maxTier: coreTier, focus: .corePower)
        ].compactMap { $0 }

        return customTemplates + calisthenicsExtras + base
    }

    private static func customTemplate(from custom: CustomExercise) -> ExerciseTemplate {
        let focus: SessionFocus = {
            switch custom.pattern {
            case .legsQuad, .legsPosterior, .calves: return .legs
            case .pushHorizontal, .pushVertical: return .push
            case .pullHorizontal, .pullVertical: return .pull
            case .core: return .corePower
            case .arms: return .push
            }
        }()
        let reps = custom.defaultRepMin == custom.defaultRepMax
            ? "\(custom.defaultRepMin)"
            : "\(custom.defaultRepMin)–\(custom.defaultRepMax)"
        return ExerciseTemplate(
            name: custom.displayName,
            muscleGroups: musclesForPattern(custom.pattern),
            focus: focus,
            requiredEquipment: [.bodyweight, .homeWeights, .fullGym],
            notes: custom.notes.map { $0 } ?? "Custom exercise · \(reps) reps",
            substitution: nil
        )
    }

    private static func musclesForPattern(_ pattern: MovementPattern) -> [MuscleGroup] {
        switch pattern {
        case .legsQuad: return [.legs, .glutes]
        case .legsPosterior: return [.legs, .glutes, .back]
        case .pushHorizontal: return [.chest, .shoulders, .arms]
        case .pushVertical: return [.shoulders, .arms]
        case .pullHorizontal: return [.back, .lats, .arms]
        case .pullVertical: return [.back, .lats, .arms]
        case .arms: return [.arms, .forearms]
        case .core: return [.core]
        case .calves: return [.calves]
        }
    }

    private static func catalogTemplate(
        from family: [CatalogExercise],
        maxTier: Int,
        focus: SessionFocus
    ) -> ExerciseTemplate? {
        let candidates = family.filter { ($0.progressionTier ?? 0) <= maxTier }
        guard let pick = candidates.last else { return nil }
        return ExerciseTemplate(
            name: pick.displayName,
            muscleGroups: pick.muscleGroups,
            focus: focus,
            requiredEquipment: [.bodyweight],
            notes: "Bodyweight progression · \(pick.displayName). Own this tier before the next unlock.",
            substitution: pick.defaultSubstitute
        )
    }

    // MARK: Cooldown

    private static func generateCooldown(pattern: SessionPattern) -> [Exercise] {
        [
            Exercise(
                id: UUID().uuidString,
                name: "Cooldown stretch",
                muscleGroups: pattern.muscleGroups,
                sets: 1,
                reps: "3–5 min",
                restSeconds: 0,
                rpe: nil,
                notes: "Slow stretches for the groups you just trained. Breathe.",
                substitution: nil
            )
        ]
    }

    // MARK: Naming

    private static func sessionName(pattern: SessionPattern, archetype: Archetype, arcNumber: Int) -> String {
        let arcPrefix: String
        switch arcNumber {
        case 1: arcPrefix = "Foundation"
        case 2: arcPrefix = "Growth"
        case 3: arcPrefix = "Power"
        default: arcPrefix = ""
        }
        return "\(arcPrefix) · \(pattern.name)"
    }

    private static func sessionNotes(arcNumber: Int, weekInArc: Int) -> String? {
        switch arcNumber {
        case 1: return "Focus on form and range. RPE 7. You should feel worked, not wrecked."
        case 2: return "Push the middle reps. RPE 8. Last reps should be hard."
        case 3: return "Heavy and clean. RPE 9. One rep in the tank."
        default: return nil
        }
    }

    /// Session note tuned to the resolved block for this week. Rank-gated
    /// blocks (realization, peaking) get distinct language so users can
    /// tell what phase they're in at a glance.
    private static func blockAwareNotes(block: BlockType, arcNumber: Int) -> String? {
        switch block {
        case .accumulation:
            return "Focus on form and range. RPE 7. You should feel worked, not wrecked."
        case .intensification:
            return "Push the middle reps. RPE 8. Last reps should be hard."
        case .realization:
            return "Realization block. RPE 9. Low reps, heavy weight — one in the tank."
        case .peaking:
            return "Peaking block. Singles and doubles at RPE 9-9.5. Lift like PR day is next week."
        case .deload:
            return "Deload. Drop intensity. Keep form crisp; let your CNS refill."
        }
    }

    /// Resolve the block for a given week number against the user's rank.
    /// Base schedule: weeks 1-4 accumulation, 5-8 intensification, 9-12
    /// depends on rank:
    ///   A-+ : weeks 9-10 realization, week 11 peaking, week 12 deload
    ///   B-+ : weeks 9-11 realization, week 12 deload
    ///   < B-: weeks 9-11 intensification cycle, week 12 deload
    static func scheduledBlock(
        week: Int,
        realizationUnlocked: Bool,
        peakingUnlocked: Bool
    ) -> BlockType {
        switch week {
        case 1...4:  return .accumulation
        case 5...8:  return .intensification
        case 9, 10:  return realizationUnlocked ? .realization : .intensification
        case 11:
            if peakingUnlocked { return .peaking }
            if realizationUnlocked { return .realization }
            return .intensification
        case 12:     return .deload
        default:     return .accumulation
        }
    }

    // MARK: Program naming

    private static func programName(for archetype: Archetype) -> String {
        "\(archetype.shortName) · Adaptive protocol"
    }

    private static func programDescription(for archetype: Archetype) -> String {
        switch archetype {
        case .heavyDuty: return "Mass-monster compounds. Squat, bench, deadlift, press — fill out the whole frame."
        case .leanCut:   return "Balanced athlete. Push, pull, and squat proportionally."
        case .shredded:  return "Core and calisthenics mastery. Move your own bodyweight like a weapon."
        case .vTaper:    return "Pull progression to muscle-up. Build the shoulders and back that define the silhouette."
        }
    }

    // MARK: Default plans

    private static func defaultNutritionPlan(experience: Experience?) -> NutritionPlan {
        NutritionPlan(
            dailyCalories: 2600,
            proteinGrams: 160,
            carbsGrams: 280,
            fatGrams: 80,
            mealCount: 4,
            meals: [
                MealTemplate(id: UUID().uuidString, name: "Breakfast", timing: "Morning", calories: 600, protein: 35, carbs: 70, fat: 18, examples: ["Oats + whey + berries", "Eggs + toast + avocado"]),
                MealTemplate(id: UUID().uuidString, name: "Lunch", timing: "Midday", calories: 750, protein: 50, carbs: 80, fat: 25, examples: ["Chicken + rice + veg", "Salmon + sweet potato"]),
                MealTemplate(id: UUID().uuidString, name: "Pre-workout", timing: "Before training", calories: 300, protein: 20, carbs: 40, fat: 5, examples: ["Whey + banana", "Rice cake + PB"]),
                MealTemplate(id: UUID().uuidString, name: "Dinner", timing: "Evening", calories: 950, protein: 55, carbs: 90, fat: 32, examples: ["Ground beef + potatoes + broccoli", "Tofu + rice + stir fry"])
            ],
            hydrationLiters: 3.0,
            supplements: ["Creatine 5g daily", "Whey protein if you struggle to hit protein"],
            notes: "Protein is the leverage. Hit 0.8–1g per pound of bodyweight.",
            restDayCalories: 2300,
            restDayProteinGrams: 160,
            restDayCarbsGrams: 200,
            restDayFatGrams: 80
        )
    }

    // MARK: Rationale — the reveal copy that names the user's choices

    // swiftlint:disable:next function_parameter_count
    private static func buildRationale(
        archetype: Archetype,
        daysPerWeek: Int,
        minutesPerSession: Int,
        equipment: [Equipment],
        exerciseStyles: Set<ExerciseStyle>,
        goals: Set<Goal>,
        obstacles: Set<Obstacle>,
        sleepQuality: Int,
        stressLevel: Int,
        currentFrequency: Frequency?,
        commitment: Int,
        experience: Experience?,
        displayHandle: String,
        age: Int,
        gender: Gender,
        heightCm: Double,
        weightKg: Double,
        targetAreas: Set<TargetArea>,
        archetypeRank: SubRank = .eMinus,
        realizationUnlocked: Bool = false,
        peakingUnlocked: Bool = false
    ) -> ProgramRationale {
        let trimmedHandle = displayHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        let headline = trimmedHandle.isEmpty
            ? "Built for you."
            : "Built for you, \(trimmedHandle)."

        let summary = rationaleSummary(
            archetype: archetype,
            daysPerWeek: daysPerWeek,
            minutesPerSession: minutesPerSession,
            equipment: equipment,
            goals: goals,
            obstacles: obstacles,
            stressLevel: stressLevel,
            sleepQuality: sleepQuality,
            age: age,
            gender: gender
        )

        var decisions: [ProgramRationale.Decision] = []

        decisions.append(
            .init(
                inputSummary: "The \(archetype.displayName.replacingOccurrences(of: "The ", with: "")) archetype",
                decisionApplied: archetypeRationaleCopy(archetype: archetype, equipment: equipment, exerciseStyles: exerciseStyles),
                iconSystemName: archetypeIcon(archetype)
            )
        )

        decisions.append(
            .init(
                inputSummary: "\(daysPerWeek) days/week · \(minutesPerSession) minutes",
                decisionApplied: frequencyRationaleCopy(
                    daysPerWeek: daysPerWeek,
                    currentFrequency: currentFrequency,
                    archetype: archetype
                ),
                iconSystemName: "calendar"
            )
        )

        if let goal = primaryGoal(goals) {
            decisions.append(
                .init(
                    inputSummary: "Goal: \(goal.displayName)",
                    decisionApplied: goalRationaleCopy(goal),
                    iconSystemName: goal.icon
                )
            )
        }

        if !targetAreas.isEmpty {
            let names = targetAreas.map(\.displayName).sorted().joined(separator: ", ")
            decisions.append(
                .init(
                    inputSummary: "Focus: \(names)",
                    decisionApplied: "Accessories weighted to hit those zones every session you train them.",
                    iconSystemName: "target"
                )
            )
        }

        if obstacles.contains(.time) {
            decisions.append(
                .init(
                    inputSummary: "Time is your biggest obstacle",
                    decisionApplied: "Each session built for \(minutesPerSession) minutes. No fluff — drop sets, straight to work.",
                    iconSystemName: "timer"
                )
            )
        } else if obstacles.contains(.plateau) {
            decisions.append(
                .init(
                    inputSummary: "You've hit a plateau",
                    decisionApplied: "Accessories rotate weekly so your body never gets comfortable.",
                    iconSystemName: "chart.line.flattrend.xyaxis"
                )
            )
        } else if obstacles.contains(.consistency) {
            decisions.append(
                .init(
                    inputSummary: "Consistency is your biggest blocker",
                    decisionApplied: "Shorter ramp — we build streaks before we build volume.",
                    iconSystemName: "flame"
                )
            )
        }

        if sleepQuality <= 4 || stressLevel >= 7 {
            let recoveryInput: String
            if sleepQuality <= 4 && stressLevel >= 7 {
                recoveryInput = "Sleep: \(sleepQuality)/10 · Stress: \(stressLevel)/10"
            } else if sleepQuality <= 4 {
                recoveryInput = "Sleep quality: \(sleepQuality)/10"
            } else {
                recoveryInput = "Stress level: \(stressLevel)/10"
            }
            decisions.append(
                .init(
                    inputSummary: recoveryInput,
                    decisionApplied: "Starting Arc 1 at RPE 6 — intensity climbs as your recovery stabilizes.",
                    iconSystemName: "moon.zzz"
                )
            )
        }

        if exerciseStyles.contains(.cardioIntervals) {
            decisions.append(
                .init(
                    inputSummary: "You like cardio intervals",
                    decisionApplied: "A 4-round HIIT finisher bolts onto the end of every session.",
                    iconSystemName: "bolt.heart"
                )
            )
        } else if exerciseStyles.contains(.steadyCardio) {
            decisions.append(
                .init(
                    inputSummary: "You prefer steady-state cardio",
                    decisionApplied: "15 min Zone 2 after the main block — easy pace, long game.",
                    iconSystemName: "figure.run"
                )
            )
        }

        decisions.append(
            .init(
                inputSummary: equipmentSummary(equipment),
                decisionApplied: equipmentRationaleCopy(equipment: equipment),
                iconSystemName: equipmentIcon(equipment)
            )
        )

        // Rank-gated block decisions. Only surface when the archetype rank
        // is actually computed (> .eMinus) and the gate is open, so the
        // copy doesn't lie to new users.
        if peakingUnlocked {
            decisions.append(
                .init(
                    inputSummary: "Arc rank \(archetypeRank.displayName) — peaking unlocked",
                    decisionApplied: "Rank A- unlocks peaking blocks. Week 11 compresses to singles and doubles at RPE 9-9.5 — PR territory.",
                    iconSystemName: "chart.line.uptrend.xyaxis.circle.fill"
                )
            )
        } else if realizationUnlocked {
            decisions.append(
                .init(
                    inputSummary: "Arc rank \(archetypeRank.displayName) — realization unlocked",
                    decisionApplied: "Rank B- unlocks realization blocks. We schedule intensity peaks in weeks 9-11 so heavy singles show up on purpose.",
                    iconSystemName: "target"
                )
            )
        } else if archetypeRank > .eMinus {
            decisions.append(
                .init(
                    inputSummary: "Arc rank \(archetypeRank.displayName)",
                    decisionApplied: "Realization blocks unlock at B-. Until then, we cycle accumulation and intensification — the work that actually gets you there.",
                    iconSystemName: "lock.fill"
                )
            )
        }

        return ProgramRationale(
            headline: headline,
            summaryCopy: summary,
            decisions: decisions
        )
    }

    private static func rationaleSummary(
        archetype: Archetype,
        daysPerWeek: Int,
        minutesPerSession: Int,
        equipment: [Equipment],
        goals: Set<Goal>,
        obstacles: Set<Obstacle>,
        stressLevel: Int,
        sleepQuality: Int,
        age: Int,
        gender: Gender
    ) -> String {
        var parts: [String] = []
        parts.append("\(daysPerWeek) sessions a week, \(minutesPerSession) minutes each")
        if equipment == [.bodyweight] {
            parts.append("bodyweight-only")
        }
        if let primary = primaryGoal(goals) {
            switch primary {
            case .buildMuscle: parts.append("hypertrophy-biased")
            case .getStronger: parts.append("strength-biased")
            case .loseFat, .getDefined: parts.append("density-biased")
            case .athletic: parts.append("athletically balanced")
            case .feelBetter: parts.append("sustainable-paced")
            }
        }
        let base = parts.joined(separator: ", ")

        var suffix = ""
        if obstacles.contains(.time) {
            suffix = " — time-efficient because you said busy schedule was your biggest blocker."
        } else if sleepQuality <= 4 || stressLevel >= 7 {
            suffix = " — starting intensity dialed back so your recovery can catch up."
        } else if age > 0, age <= 25 {
            suffix = " — tuned for a \(age)-year-old frame that can handle steady ramp."
        } else if age >= 40 {
            suffix = " — scaled for longevity and long-term joint health at \(age)."
        } else {
            suffix = " — built around the \(archetype.displayName.lowercased()) template."
        }
        return (base.prefix(1).capitalized + base.dropFirst()) + suffix
    }

    private static func archetypeRationaleCopy(
        archetype: Archetype,
        equipment: [Equipment],
        exerciseStyles: Set<ExerciseStyle>
    ) -> String {
        switch archetype {
        case .shredded:
            let bodyweight = equipment == [.bodyweight] || exerciseStyles.contains(.calisthenics)
            return bodyweight
                ? "Bodyweight-first progressions: pushup → pike → archer. Every lift has a ladder."
                : "Calisthenics progressions with weighted options where your kit allows."
        case .vTaper:
            return "Pull-vertical emphasis: progression toward the muscle-up; shoulders and back own the split."
        case .heavyDuty:
            return "Squat-anchored lower body dominance; the frame gets bigger first."
        case .leanCut:
            return "Push/pull/squat in equal measure — the athletic baseline the whole flow rotates around."
        }
    }

    private static func frequencyRationaleCopy(
        daysPerWeek: Int,
        currentFrequency: Frequency?,
        archetype: Archetype
    ) -> String {
        if daysPerWeek <= 3 {
            return "Full-body rotation — every session hits everything so recovery stays on your side."
        }
        if daysPerWeek == 4 {
            switch archetype {
            case .heavyDuty: return "Upper / lower / upper / lower — volume without the CNS debt."
            case .vTaper: return "Pull-heavy rotation: 2 pull days, 1 leg, 1 push-focused upper."
            default: return "Upper / lower split — lets each zone recover while the other works."
            }
        }
        if daysPerWeek >= 5 {
            return "Push / pull / legs with an extra accessory day — room for arms, calves, conditioning."
        }
        return "Split tuned for your experience + ramp."
    }

    private static func goalRationaleCopy(_ goal: Goal) -> String {
        switch goal {
        case .buildMuscle:
            return "Rep ranges: 8–12 on compounds, 10–12 on accessories. Time-under-tension over ego weight."
        case .getStronger:
            return "Strength ranges: 3–6 on signature lifts with long rests. Peak weight every arc."
        case .loseFat:
            return "High-volume circuits, shorter rests. Burn the gas tank without sacrificing muscle."
        case .getDefined:
            return "Accessory volume up, rest down. Carve detail with tempo + density."
        case .athletic:
            return "Power moves first, hypertrophy second. Speed preserved through every arc."
        case .feelBetter:
            return "Moderate loads, clean reps. Consistency compounds — we protect that first."
        }
    }

    private static func archetypeIcon(_ archetype: Archetype) -> String {
        switch archetype {
        case .vTaper: return "figure.climbing"
        case .heavyDuty: return "figure.strengthtraining.traditional"
        case .shredded: return "figure.strengthtraining.functional"
        case .leanCut: return "figure.run"
        }
    }

    private static func equipmentSummary(_ equipment: [Equipment]) -> String {
        if equipment == [.bodyweight] { return "Bodyweight only" }
        if equipment.contains(.fullGym) { return "Full gym access" }
        if equipment.contains(.homeWeights) { return "Home weights setup" }
        return "Equipment: " + equipment.map(\.displayName).sorted().joined(separator: " + ")
    }

    private static func equipmentRationaleCopy(equipment: [Equipment]) -> String {
        if equipment == [.bodyweight] {
            return "Every movement has a bodyweight variant with a progression path — no gym required."
        }
        if equipment.contains(.fullGym) {
            return "Barbell anchors the signature lifts; machines cover accessories."
        }
        if equipment.contains(.homeWeights) {
            return "Dumbbell-first programming with kettlebell + bodyweight accessories."
        }
        return "Selections pulled from your available kit only — nothing you can't run today."
    }

    private static func equipmentIcon(_ equipment: [Equipment]) -> String {
        if equipment == [.bodyweight] { return "figure.strengthtraining.functional" }
        if equipment.contains(.fullGym) { return "dumbbell.fill" }
        if equipment.contains(.homeWeights) { return "house.fill" }
        return "wrench.and.screwdriver"
    }

    private static func defaultRecoveryPlan(daysPerWeek: Int) -> RecoveryPlan {
        RecoveryPlan(
            sleepHoursTarget: 8.0,
            restDaysPerWeek: 7 - daysPerWeek,
            activities: [
                RecoveryActivity(id: UUID().uuidString, name: "Walking", description: "20–30 minutes easy pace. Active recovery on rest days.", durationMinutes: 25, frequency: "Daily"),
                RecoveryActivity(id: UUID().uuidString, name: "Mobility", description: "Hip openers, thoracic rotations, shoulder dislocates.", durationMinutes: 10, frequency: "Daily"),
                RecoveryActivity(id: UUID().uuidString, name: "Sauna or cold", description: "Optional but effective for recovery + resilience.", durationMinutes: 15, frequency: "2x / week")
            ],
            notes: "Sleep is the real supplement. Everything else compounds on top of it."
        )
    }
}
