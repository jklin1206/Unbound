import XCTest
@testable import UNBOUND

// Thin glue for the year simulator. It has two jobs and no progression math:
//   1. Synthesize the athlete's per-session performance (reps / hold seconds /
//      RPE / the load the app would prescribe) from the current state + flags.
//   2. Drive the REAL `ProgressionEngine` against the REAL
//      `ProgressionStateStore` to advance state, then mirror the store back.
// Weight bumps, tier unlocks, autoregulation, the `.easier` bias, and
// AutoDeloadService are all decided by the shipping engine, so the sim
// validates the real code path — never a reimplementation of it.

struct SimulatedExercisePerformance {
    /// `MovementCatalog.normalized` key used to look the post-state up in the mirror.
    let exerciseKey: String
    let entry: ExerciseLogEntry
    let reps: Int
    let holdSeconds: Int?
    let rpe: Int
    /// The load the athlete actually lifted this session (the app's prescription).
    let usedWeightKg: Double
    let wasGrindy: Bool
    let isTimedHold: Bool
}

struct SimulationProgressionTracker {
    /// Mirror of the engine's store for this user, keyed by
    /// `MovementCatalog.normalized(exerciseKey)` so the generator/resolver find it.
    private(set) var states: [String: ProgressionState] = [:]
    private var bumpCount = 0
    private var grindBumpCount = 0
    private var exposureCounts: [String: Int] = [:]

    let userId: String
    let experience: Experience
    let bodyweightKg: Double
    let feedbackMode: TrainingFeedbackMode
    let mode: ProgressionMode

    init(
        userId: String,
        experience: Experience,
        bodyweightKg: Double,
        feedbackMode: TrainingFeedbackMode,
        mode: ProgressionMode
    ) {
        self.userId = userId
        self.experience = experience
        self.bodyweightKg = bodyweightKg
        self.feedbackMode = feedbackMode
        self.mode = mode
    }

    var summary: YearProgressionSummary {
        YearProgressionSummary(
            trackedExerciseCount: states.count,
            totalWeightBumps: bumpCount,
            grindyRPEBumps: grindBumpCount,
            accessoryRepCeilingWarnings: 0,
            finalStates: states.values.sorted { $0.exerciseKey < $1.exerciseKey }.map {
                YearProgressionStateExport(
                    exerciseKey: $0.exerciseKey,
                    displayName: $0.displayName,
                    currentWorkingWeightKg: rounded($0.currentWorkingWeightKg),
                    targetRepMin: $0.targetRepMin,
                    targetRepMax: $0.targetRepMax,
                    targetRPE: $0.targetRPE,
                    blockType: $0.blockType.rawValue,
                    consecutiveSessionsAtTarget: $0.consecutiveSessionsAtTarget
                )
            }
        )
    }

    // MARK: Performance synthesis (simulation input — no progression math)

    /// Builds the ExerciseLogEntry a real athlete would produce for one prescribed
    /// exercise. Silent-feedback personas log no RPE, matching the app. The load
    /// is whatever the app prescribes (`suggestedWeightKg`), falling back to a
    /// persona/movement calibration only the first time an exercise is seen.
    mutating func synthesize(
        exercise: Exercise,
        absoluteDay: Int,
        sequence: Int,
        shouldGrind: Bool,
        shouldUnderperform: Bool
    ) -> SimulatedExercisePerformance {
        let key = exerciseKey(exercise)
        let exposure = exposureCounts[key, default: 0] + 1
        exposureCounts[key] = exposure
        let state = stateForSynthesis(exercise: exercise, key: key)
        let classification = state.classification
        let definition = MovementCatalog.canonicalExercise(named: exercise.name)
        let prescriptionText = exercise.reps.lowercased()
        let hasSecondsTarget = prescriptionText.contains("sec")
            || prescriptionText.range(of: #"\d+\s*s\b"#, options: .regularExpression) != nil
        let isTimedHold = definition?.defaultMetric == .holdSeconds
            || definition?.defaultMetric == .durationSeconds
            || hasSecondsTarget
        let entryId = "sim-\(userId)-d\(absoluteDay)-e\(sequence)"
        let silent = feedbackMode == .silent

        if isTimedHold {
            let prescribed = RepRange.lowerBound(exercise.reps) ?? state.currentTargetDurationSeconds
            let holdSeconds: Int
            if shouldUnderperform {
                holdSeconds = max(1, Int(Double(prescribed) * 0.8))
            } else if !shouldGrind && exposure.isMultiple(of: 3) {
                holdSeconds = IsometricDurationPolicy.nextTarget(after: prescribed, exerciseKey: key)
            } else {
                holdSeconds = prescribed
            }
            let rpe = shouldGrind ? 9 : (holdSeconds > prescribed ? 7 : 8)
            let entry = logEntry(
                id: entryId,
                exercise: exercise,
                definition: definition,
                weightKg: nil,
                reps: 0,
                rpe: silent ? nil : rpe,
                durationSeconds: holdSeconds
            )
            return SimulatedExercisePerformance(
                exerciseKey: key,
                entry: entry,
                reps: 0,
                holdSeconds: holdSeconds,
                rpe: rpe,
                usedWeightKg: 0,
                wasGrindy: shouldGrind,
                isTimedHold: true
            )
        }

        let prescribedReps = RepRange.lowerBound(exercise.reps) ?? state.currentTargetReps
        let reps: Int
        if shouldUnderperform {
            reps = max(1, prescribedReps - 2)
        } else if !shouldGrind && exposure.isMultiple(of: 3) {
            reps = min(state.targetRepMax + 3, prescribedReps + 2)
        } else {
            reps = max(prescribedReps, min(state.targetRepMax, prescribedReps + (exposure.isMultiple(of: 2) ? 1 : 0)))
        }
        let rpe = shouldGrind
            ? min(10, max(state.targetRPE + 2, 9))
            : (reps >= prescribedReps + 2 ? 7 : max(7, state.targetRPE))

        let isBodyweight = classification == .bodyweightSkill
        let usedWeightKg = isBodyweight
            ? 0
            : (exercise.suggestedWeightKg ?? states[key]?.currentWorkingWeightKg ?? startingWeight(for: exercise, key: key))
        let entry = logEntry(
            id: entryId,
            exercise: exercise,
            definition: definition,
            weightKg: isBodyweight ? nil : usedWeightKg,
            reps: reps,
            rpe: silent ? nil : rpe,
            durationSeconds: nil
        )
        return SimulatedExercisePerformance(
            exerciseKey: key,
            entry: entry,
            reps: reps,
            holdSeconds: nil,
            rpe: rpe,
            usedWeightKg: usedWeightKg,
            wasGrindy: shouldGrind,
            isTimedHold: false
        )
    }

    // MARK: Engine drive (real ProgressionEngine + ProgressionStateStore)

    /// Ingests one day's synthesized session through the shipping engine, mirrors
    /// the store back, and derives per-exercise outcomes by comparing pre/post
    /// state. `bumpedOnGrindyRPE` is now a genuine assertion against the engine:
    /// it fires only if the engine actually raised load on a session it itself
    /// flagged grindy (which correct engine behavior never does).
    mutating func ingest(
        performances: [SimulatedExercisePerformance],
        programId: String,
        dayNumber: Int,
        absoluteDay: Int,
        date: Date
    ) async -> [String: ProgressionLogOutcome] {
        guard !performances.isEmpty else { return [:] }
        let log = WorkoutLog(
            id: "sim-\(userId)-day\(absoluteDay)",
            userId: userId,
            programId: programId,
            dayNumber: dayNumber,
            plannedWorkoutName: "Simulated Session",
            startedAt: date,
            completedAt: date.addingTimeInterval(1_800),
            exerciseEntries: performances.map(\.entry)
        )
        // Persist the session first, exactly as TrainingCompletionService does
        // before ingest, so the engine's PlateauDetector (via AutoDeloadService)
        // sees this and prior sessions in its recent-log window. Without this the
        // auto-deload path would never fire and the deload lifecycle would stay
        // invisible to the sim.
        try? await DatabaseService.shared.create(log, collection: "workoutLogs", documentId: log.id)
        await ProgressionEngine.shared.ingest(log: log, mode: mode, feedbackMode: feedbackMode)
        await refreshStates()

        var outcomes: [String: ProgressionLogOutcome] = [:]
        for performance in performances {
            let post = states[performance.exerciseKey]
            // A real progression bump prescribes MORE than the athlete just
            // lifted. Comparing against the lifted load (not the pre-state) means
            // plate-snapping the working weight to the prescribed load — which the
            // engine does even in preserve/cut mode — is not miscounted as a bump.
            let baseline = performance.usedWeightKg
            let postWeight = post?.currentWorkingWeightKg ?? baseline
            let bumped = postWeight > baseline + 0.0001
            let grindy = post?.lastSessionWasGrindy == true
            if bumped {
                bumpCount += 1
                if grindy { grindBumpCount += 1 }
            }
            outcomes[performance.entry.id] = ProgressionLogOutcome(
                reps: performance.reps,
                holdSeconds: performance.holdSeconds,
                rpe: performance.rpe,
                weightKg: rounded(postWeight),
                classification: post?.classification
                    ?? ExerciseClassification.classify(exerciseKey: performance.exerciseKey),
                targetRepMaxAfter: post?.targetRepMax ?? 0,
                bumpedOnGrindyRPE: bumped && grindy,
                accessoryRepCeilingTooHigh: false
            )
        }
        return outcomes
    }

    /// Deletes this run's engine-owned rows from the shared local store. The
    /// unique per-run userId makes this a targeted sweep; it keeps the store
    /// (and every subsequent full-dir query) from growing across personas and
    /// repeated test runs.
    func cleanUpEngineState() async {
        for collection in ["workoutLogs", "progression_states", "progression_families"] {
            _ = try? await DatabaseService.shared.deleteWhere(
                collection: collection,
                field: "userId",
                isEqualTo: userId
            )
        }
    }

    /// Rebuilds the mirror from the store the engine just wrote. Keyed by
    /// `MovementCatalog.normalized` so generator/resolver lookups resolve.
    private mutating func refreshStates() async {
        let all = await ProgressionStateStore.shared.fetchAll(userId: userId)
        var rebuilt: [String: ProgressionState] = [:]
        for state in all {
            rebuilt[MovementCatalog.normalized(state.exerciseKey)] = state
        }
        states = rebuilt
    }

    // MARK: Seeds / helpers (simulation input — not progression math)

    private func logEntry(
        id: String,
        exercise: Exercise,
        definition: MovementDefinition?,
        weightKg: Double?,
        reps: Int,
        rpe: Int?,
        durationSeconds: Int?
    ) -> ExerciseLogEntry {
        ExerciseLogEntry(
            id: id,
            exerciseName: exercise.name,
            movementId: definition?.id,
            rankStandardMovementId: definition?.rankStandardMovementId,
            plannedSets: exercise.sets,
            plannedReps: exercise.reps,
            sets: [
                SetLog(
                    id: "\(id)-s1",
                    setNumber: 1,
                    weightKg: weightKg,
                    reps: reps,
                    rpe: rpe,
                    isWarmup: false,
                    durationSeconds: durationSeconds
                )
            ],
            skipped: false,
            notes: nil
        )
    }

    /// Ephemeral state used only to read the current rep/hold/RPE targets when
    /// synthesizing performance. Never persisted — the engine owns real seeding.
    private func stateForSynthesis(exercise: Exercise, key: String) -> ProgressionState {
        if let existing = states[key] { return existing }
        var state = ProgressionState.seed(
            userId: userId,
            exercise: key,
            startingWeightKg: exercise.suggestedWeightKg ?? startingWeight(for: exercise, key: key)
        )
        state.displayName = exercise.name
        state.initialWorkingWeightKg = state.currentWorkingWeightKg
        state.targetRPE = exercise.rpe ?? feedbackMode.defaultTargetRPE
        return state
    }

    private func exerciseKey(_ exercise: Exercise) -> String {
        if let definition = MovementCatalog.canonicalExercise(named: exercise.name) {
            return MovementCatalog.normalized(definition.canonicalExerciseName ?? definition.displayName)
        }
        return MovementCatalog.normalized(exercise.name)
    }

    /// Persona + movement-specific calibration for the FIRST load an athlete
    /// demonstrates on an exercise the app has not yet prescribed a weight for.
    /// This is simulation input (demonstrated capacity), not progression logic:
    /// once seeded, the real engine owns every subsequent working weight.
    private func startingWeight(for exercise: Exercise, key: String) -> Double {
        let classification = ExerciseClassification.classify(exerciseKey: key)
        guard classification != .bodyweightSkill else { return 0 }

        let experienceFactor: Double
        switch experience {
        case .never: experienceFactor = 0.45
        case .tried: experienceFactor = 0.65
        case .used: experienceFactor = 0.82
        case .current: experienceFactor = 1
        }

        let ratio: Double
        if key.contains("deadlift") && !key.contains("romanian") {
            ratio = 1.6
        } else if key.contains("squat") || key.contains("leg press") {
            ratio = key.contains("leg press") ? 1.7 : 1.25
        } else if key.contains("bench press") || key.contains("chest press") {
            ratio = 0.9
        } else if key.contains("overhead press") || key.contains("shoulder press") {
            ratio = 0.55
        } else if key.contains("row") {
            ratio = 0.75
        } else if key.contains("pulldown") {
            ratio = key.contains("straight arm") ? 0.3 : 0.65
        } else if key.contains("romanian") || key.contains("rdl") || key.contains("hip thrust") {
            ratio = 1.05
        } else if key.contains("curl") && !key.contains("leg curl") {
            ratio = 0.16
        } else if key.contains("lateral raise") || key.contains("rear delt") {
            ratio = 0.08
        } else if key.contains("triceps") || key.contains("pushdown") {
            ratio = 0.18
        } else if key.contains("leg curl") || key.contains("leg extension") {
            ratio = 0.38
        } else {
            switch MovementCatalog.canonicalExercise(named: exercise.name)?.movementSlot {
            case .squat, .hinge: ratio = 0.8
            case .horizontalPush, .verticalPush: ratio = 0.45
            case .horizontalPull, .verticalPull: ratio = 0.5
            case .arms, .calves, .core: ratio = 0.15
            default: ratio = 0.2
            }
        }

        let identityVariation = 0.95 + Double(key.utf8.reduce(0) { ($0 + Int($1)) % 11 }) / 100
        let raw = bodyweightKg * experienceFactor * ratio * identityVariation
        return max(2.5, WeightPlatePolicy.snap(raw, to: 2.5))
    }

    private func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
