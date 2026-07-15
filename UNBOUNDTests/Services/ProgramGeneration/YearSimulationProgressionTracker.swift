import XCTest
@testable import UNBOUND

struct SimulationProgressionTracker {
    private(set) var states: [String: ProgressionState] = [:]
    private var bumpCount = 0
    private var grindBumpCount = 0
    private var accessoryRunawayCount = 0
    private var exposureCounts: [String: Int] = [:]

    let userId: String
    let experience: Experience
    let bodyweightKg: Double

    init(userId: String, experience: Experience, bodyweightKg: Double) {
        self.userId = userId
        self.experience = experience
        self.bodyweightKg = bodyweightKg
    }

    var summary: YearProgressionSummary {
        YearProgressionSummary(
            trackedExerciseCount: states.count,
            totalWeightBumps: bumpCount,
            grindyRPEBumps: grindBumpCount,
            accessoryRepCeilingWarnings: accessoryRunawayCount,
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

    mutating func log(
        exercise: Exercise,
        date: Date,
        shouldGrind: Bool,
        shouldUnderperform: Bool,
        cutModeActive: Bool
    ) -> ProgressionLogOutcome {
        let key = exerciseKey(exercise)
        var state = states[key] ?? seedState(for: exercise, key: key)
        let exposure = exposureCounts[key, default: 0] + 1
        exposureCounts[key] = exposure
        let classification = state.classification
        let definition = MovementCatalog.canonicalExercise(named: exercise.name)
        let prescriptionText = exercise.reps.lowercased()
        let hasSecondsTarget = prescriptionText.contains("sec")
            || prescriptionText.range(of: #"\d+\s*s\b"#, options: .regularExpression) != nil
        let isTimedHold = definition?.defaultMetric == .holdSeconds
            || definition?.defaultMetric == .durationSeconds
            || hasSecondsTarget

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
            let effortAllowed = state.targetRPE == 0 || rpe <= state.targetRPE
            let overPerformed = rpe <= 7 && holdSeconds > prescribed
            if overPerformed {
                state.consecutiveSessionsAtTarget = 2
            } else if holdSeconds >= state.currentTargetDurationSeconds && effortAllowed {
                state.consecutiveSessionsAtTarget += 1
            } else {
                state.consecutiveSessionsAtTarget = 0
            }
            if state.consecutiveSessionsAtTarget >= 2 && !cutModeActive {
                state.targetDurationSeconds = IsometricDurationPolicy.nextTarget(
                    after: max(state.currentTargetDurationSeconds, holdSeconds),
                    exerciseKey: key
                )
                state.consecutiveSessionsAtTarget = 0
            } else if state.consecutiveSessionsAtTarget >= 2 {
                state.consecutiveSessionsAtTarget = 0
            }
            state.lastSessionDurationSeconds = holdSeconds
            state.lastSessionReps = nil
            state.lastSessionRPE = rpe
            state.updatedAt = date
            states[key] = state
            return ProgressionLogOutcome(
                reps: 0,
                holdSeconds: holdSeconds,
                rpe: rpe,
                weightKg: 0,
                classification: classification,
                targetRepMaxAfter: state.targetRepMax,
                bumpedOnGrindyRPE: false,
                accessoryRepCeilingTooHigh: false
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
        let rpe = shouldGrind ? min(10, max(state.targetRPE + 2, 9)) : (reps >= prescribedReps + 2 ? 7 : max(7, state.targetRPE))
        let hitTopOfRange = reps >= state.targetRepMax
        let hitTargetRPE = state.targetRPE == 0 || rpe <= state.targetRPE
        let overPerformed = reps >= prescribedReps + 2 && rpe <= 7
        let previousWeight = state.currentWorkingWeightKg

        state.lastSessionReps = reps
        state.lastSessionDurationSeconds = nil
        state.lastSessionRPE = rpe
        state.lastSessionHitTarget = overPerformed || (hitTopOfRange && hitTargetRPE)
        state.lastSessionWasGrindy = shouldGrind
        state.prescriptionBias = overPerformed ? .harder : .hold

        if overPerformed {
            state.consecutiveSessionsAtTarget = 2
        } else if hitTopOfRange && hitTargetRPE {
            state.consecutiveSessionsAtTarget += 1
        } else {
            state.consecutiveSessionsAtTarget = 0
        }

        var bumpedOnGrindyRPE = false
        let accessoryCeilingTooHigh = false
        if state.consecutiveSessionsAtTarget >= 2 && cutModeActive {
            state.consecutiveSessionsAtTarget = 0
        } else if state.consecutiveSessionsAtTarget >= 2 {
            switch classification {
            case .upperCompound, .lowerCompound:
                if !cutModeActive {
                    state.currentWorkingWeightKg = WeightPlatePolicy.progressedWeightKilograms(
                        from: state.currentWorkingWeightKg,
                        classification: classification,
                        unit: .kilograms,
                        microloadingEnabled: false
                    )
                    if state.currentWorkingWeightKg > previousWeight {
                        bumpCount += 1
                        if shouldGrind {
                            grindBumpCount += 1
                            bumpedOnGrindyRPE = true
                        }
                    }
                }
                state.consecutiveSessionsAtTarget = 0
            case .accessory:
                let ceiling = accessoryRepCeiling(for: state)
                if state.targetRepMax < ceiling {
                    state.targetRepMax = min(ceiling, state.targetRepMax + 2)
                    state.consecutiveSessionsAtTarget = 0
                } else {
                    let candidate = WeightPlatePolicy.progressedWeightKilograms(
                        from: state.currentWorkingWeightKg,
                        classification: classification,
                        unit: .kilograms,
                        microloadingEnabled: false
                    )
                    if candidate <= maximumAutomaticAccessoryWeight(for: state) {
                        state.currentWorkingWeightKg = candidate
                        state.targetRepMax = classification.defaultRepRange(for: state.blockType).upperBound
                    }
                    state.consecutiveSessionsAtTarget = 0
                }
            case .bodyweightSkill:
                state.consecutiveSessionsAtTarget = 0
            }
        }
        state.updatedAt = date
        states[key] = state

        return ProgressionLogOutcome(
            reps: reps,
            holdSeconds: nil,
            rpe: rpe,
            weightKg: rounded(state.currentWorkingWeightKg),
            classification: classification,
            targetRepMaxAfter: state.targetRepMax,
            bumpedOnGrindyRPE: bumpedOnGrindyRPE,
            accessoryRepCeilingTooHigh: accessoryCeilingTooHigh
        )
    }

    private func exerciseKey(_ exercise: Exercise) -> String {
        if let definition = MovementCatalog.canonicalExercise(named: exercise.name) {
            return MovementCatalog.normalized(definition.canonicalExerciseName ?? definition.displayName)
        }
        return MovementCatalog.normalized(exercise.name)
    }

    private func seedState(for exercise: Exercise, key: String) -> ProgressionState {
        var state = ProgressionState.seed(
            userId: userId,
            exercise: key,
            startingWeightKg: exercise.suggestedWeightKg ?? startingWeight(for: exercise, key: key)
        )
        state.displayName = exercise.name
        state.initialWorkingWeightKg = state.currentWorkingWeightKg
        if let rpe = exercise.rpe {
            state.targetRPE = rpe
        }
        return state
    }

    /// Persona + movement-specific calibration model. This deliberately avoids
    /// classification buckets: a curl, row, pulldown, and press no longer share
    /// one seed merely because their broad classification matches.
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

    private func accessoryRepCeiling(for state: ProgressionState) -> Int {
        max(20, state.classification.defaultRepRange(for: state.blockType).upperBound)
    }

    private func maximumAutomaticAccessoryWeight(for state: ProgressionState) -> Double {
        let anchor = max(0, state.initialWorkingWeightKg ?? state.currentWorkingWeightKg)
        guard anchor > 0 else { return 0 }
        return max(state.currentWorkingWeightKg, min(80, max(anchor * 1.75, anchor + 15)))
    }
}
