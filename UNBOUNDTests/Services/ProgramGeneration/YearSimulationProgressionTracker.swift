import XCTest
@testable import UNBOUND

struct SimulationProgressionTracker {
    private(set) var states: [String: ProgressionState] = [:]
    private var bumpCount = 0
    private var grindBumpCount = 0
    private var accessoryRunawayCount = 0

    let userId: String
    let experience: Experience

    init(userId: String, experience: Experience) {
        self.userId = userId
        self.experience = experience
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
        let classification = state.classification
        let reps: Int
        if shouldUnderperform {
            reps = max(1, state.targetRepMax - 2)
        } else {
            reps = state.targetRepMax
        }
        let rpe = shouldGrind ? min(10, max(state.targetRPE + 2, 9)) : state.targetRPE
        let hitTopOfRange = reps >= state.targetRepMax
        let hitTargetRPE = state.targetRPE == 0 || rpe <= state.targetRPE
        let previousWeight = state.currentWorkingWeightKg

        if hitTopOfRange && hitTargetRPE {
            state.consecutiveSessionsAtTarget += 1
        } else {
            state.consecutiveSessionsAtTarget = 0
        }

        var bumpedOnGrindyRPE = false
        let accessoryCeilingTooHigh = false
        if state.consecutiveSessionsAtTarget >= 2 {
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
                    state.currentWorkingWeightKg = WeightPlatePolicy.progressedWeightKilograms(
                        from: state.currentWorkingWeightKg,
                        classification: classification,
                        unit: .kilograms,
                        microloadingEnabled: false
                    )
                    state.targetRepMax = classification.defaultRepRange(for: state.blockType).upperBound
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
            startingWeightKg: startingWeight(for: key)
        )
        state.displayName = exercise.name
        if let rpe = exercise.rpe {
            state.targetRPE = rpe
        }
        return state
    }

    private func startingWeight(for key: String) -> Double {
        let classification = ExerciseClassification.classify(exerciseKey: key)
        let multiplier: Double
        switch experience {
        case .never: multiplier = 0.65
        case .tried: multiplier = 0.8
        case .used: multiplier = 0.95
        case .current: multiplier = 1.15
        }
        switch classification {
        case .lowerCompound: return 80 * multiplier
        case .upperCompound: return 50 * multiplier
        case .accessory: return 16 * multiplier
        case .bodyweightSkill: return 0
        }
    }

    private func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private func accessoryRepCeiling(for state: ProgressionState) -> Int {
        max(20, state.classification.defaultRepRange(for: state.blockType).upperBound)
    }
}
