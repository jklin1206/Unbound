import Foundation

struct GateKeyDefinition: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let movementIds: [String]
    let metric: GateKeyMetric
}

enum GateKeyMetric: Equatable, Sendable {
    case repsInOneSet(Int)
    case loadedRepsInOneSet(reps: Int, ratioOfBodyweight: Double)
    case holdSeconds(Int)
    case attributeFloor(RankTier)
    case gatesAnswered(Int)
}

struct GateKeySetRecord: Equatable, Sendable {
    let movementIds: Set<String>
    let reps: Int
    let loadKg: Double?
    let holdSeconds: Int?
    let isProofEligible: Bool
}

protocol GateKeyHistory {
    var gateKeySetRecords: [GateKeySetRecord] { get }
    var gateKeyAttributeProfile: AttributeProfile? { get }
    var gateKeyTrialProgress: OverallRankTrialProgress { get }
}

struct WorkoutLogGateKeyHistory: GateKeyHistory, Sendable {
    let gateKeySetRecords: [GateKeySetRecord]
    let gateKeyAttributeProfile: AttributeProfile?
    let gateKeyTrialProgress: OverallRankTrialProgress

    init(
        workoutLogs: [WorkoutLog],
        attributeProfile: AttributeProfile?,
        trialProgress: OverallRankTrialProgress
    ) {
        self.gateKeySetRecords = Self.setRecords(from: workoutLogs)
        self.gateKeyAttributeProfile = attributeProfile
        self.gateKeyTrialProgress = trialProgress
    }

    private static func setRecords(from logs: [WorkoutLog]) -> [GateKeySetRecord] {
        logs.flatMap { log in
            log.exerciseEntries.flatMap { entry in
                setRecords(from: entry)
            }
        }
    }

    private static func setRecords(from entry: ExerciseLogEntry) -> [GateKeySetRecord] {
        let resolved = MovementResolver.resolve(entry.exerciseName)
        let trainingMovement = MovementCatalog.resolvedTrainingMovement(
            name: entry.exerciseName,
            movementId: entry.movementId,
            rankStandardMovementId: entry.rankStandardMovementId
        )
        let movementIds = Set([
            entry.movementId,
            entry.rankStandardMovementId,
            Optional(resolved.movementId),
            Optional(resolved.rankStandardMovementId),
            trainingMovement?.exact.id,
            trainingMovement?.standard?.id
        ].compactMap { $0 })

        return entry.sets.map { set in
            GateKeySetRecord(
                movementIds: movementIds,
                reps: set.reps,
                loadKg: set.weightKg,
                holdSeconds: set.durationSeconds ?? (isHoldMovement(entry) ? set.reps : nil),
                isProofEligible: !set.isWarmup && set.isProofEligible
            )
        }
    }

    private static func isHoldMovement(_ entry: ExerciseLogEntry) -> Bool {
        let resolved = MovementResolver.resolve(entry.exerciseName)
        let movement = entry.movementId.flatMap(MovementCatalog.definition(for:))
            ?? MovementCatalog.definition(for: resolved.movementId)
        return movement?.defaultMetric == .holdSeconds
            || movement?.loggerMode == .hold
            || resolved.canonicalExerciseName.map {
                ProofFamily.inferred(fromExerciseName: $0, defaultFamily: .reps)
            } == .hold
    }
}

enum GateKeys {
    static func keys(for format: RankTrialFormat) -> [GateKeyDefinition] {
        switch format {
        case .firstLight, .theCount, .deckOfProof:
            return []
        case .theForging:
            return [
                GateKeyDefinition(
                    id: "key-forge-pullups",
                    label: "3 strict pull-ups, one set",
                    movementIds: ["exercise.pullup"],
                    metric: .repsInOneSet(3)
                ),
                GateKeyDefinition(
                    id: "key-forge-hinge",
                    label: "Hinge 1.25x bodyweight for 5",
                    movementIds: [
                        "exercise.romanian-deadlift",
                        "exercise.dumbbell-romanian-deadlift",
                        "exercise.deadlift"
                    ],
                    metric: .loadedRepsInOneSet(reps: 5, ratioOfBodyweight: 1.25)
                )
            ]
        case .theAscent:
            return [
                GateKeyDefinition(
                    id: "key-ascent-pullups",
                    label: "10 pull-ups, one set",
                    movementIds: ["exercise.pullup"],
                    metric: .repsInOneSet(10)
                ),
                GateKeyDefinition(
                    id: "key-ascent-hold",
                    label: "60s unbroken hold",
                    movementIds: ["exercise.plank"],
                    metric: .holdSeconds(60)
                )
            ]
        case .sevenSeals:
            return [
                GateKeyDefinition(
                    id: "key-seals-hexagon",
                    label: "Every attribute at Master floor",
                    movementIds: [
                        "exercise.deadlift",
                        "exercise.pullup",
                        "exercise.plank",
                        "cardio.run",
                        "exercise.romanian-deadlift",
                        "exercise.jump-squat"
                    ],
                    metric: .attributeFloor(.master)
                ),
                GateKeyDefinition(
                    id: "key-seals-power",
                    label: "Loaded hinge 1.5x bodyweight for 3",
                    movementIds: [
                        "exercise.deadlift",
                        "exercise.romanian-deadlift",
                        "exercise.dumbbell-romanian-deadlift"
                    ],
                    metric: .loadedRepsInOneSet(reps: 3, ratioOfBodyweight: 1.50)
                )
            ]
        case .theThreshold:
            return [
                GateKeyDefinition(
                    id: "key-threshold-press",
                    label: "Loaded upper 0.5x bodyweight for 8",
                    movementIds: [
                        "exercise.dumbbell-row",
                        "exercise.cable-row-seated",
                        "exercise.machine-row"
                    ],
                    metric: .loadedRepsInOneSet(reps: 8, ratioOfBodyweight: 0.50)
                ),
                GateKeyDefinition(
                    id: "key-threshold-hold",
                    label: "120s unbroken hold",
                    movementIds: ["exercise.plank"],
                    metric: .holdSeconds(120)
                )
            ]
        case .theLastGate:
            return [
                GateKeyDefinition(
                    id: "key-lastgate-stamps",
                    label: "Seven gates answered",
                    movementIds: [
                        "exercise.pullup",
                        "exercise.romanian-deadlift",
                        "exercise.plank",
                        "carry.farmer-carry"
                    ],
                    metric: .gatesAnswered(7)
                ),
                GateKeyDefinition(
                    id: "key-lastgate-pullups",
                    label: "15 strict pull-ups, one set",
                    movementIds: ["exercise.pullup"],
                    metric: .repsInOneSet(15)
                )
            ]
        }
    }

    static func clearedKeys(
        for format: RankTrialFormat,
        history: GateKeyHistory,
        bodyweightKg: Double
    ) -> Set<String> {
        Set(keys(for: format).filter {
            history.satisfies($0, bodyweightKg: bodyweightKg)
        }.map(\.id))
    }
}

extension GateKeyHistory {
    func satisfies(_ key: GateKeyDefinition, bodyweightKg: Double) -> Bool {
        switch key.metric {
        case .repsInOneSet(let reps):
            return matchingRecords(for: key).contains { record in
                record.reps >= reps
            }
        case .loadedRepsInOneSet(let reps, let ratioOfBodyweight):
            guard bodyweightKg > 0 else { return false }
            let minimumLoadKg = bodyweightKg * ratioOfBodyweight
            return matchingRecords(for: key).contains { record in
                record.reps >= reps && (record.loadKg ?? 0) >= minimumLoadKg
            }
        case .holdSeconds(let seconds):
            return matchingRecords(for: key).contains { record in
                (record.holdSeconds ?? 0) >= seconds
            }
        case .attributeFloor(let tier):
            guard let profile = gateKeyAttributeProfile else { return false }
            return AttributeKey.allCases.allSatisfy { key in
                profile.value(for: key).rankTitle >= tier
            }
        case .gatesAnswered(let count):
            return passedGateCount >= count
        }
    }

    private func matchingRecords(for key: GateKeyDefinition) -> [GateKeySetRecord] {
        let keyMovementIds = Set(key.movementIds)
        return gateKeySetRecords.filter { record in
            record.isProofEligible && !record.movementIds.isDisjoint(with: keyMovementIds)
        }
    }

    private var passedGateCount: Int {
        let passedDefinitionIds = Set(
            gateKeyTrialProgress.attempts
                .filter(\.passed)
                .map(\.definitionId)
        )
        return OverallRankTrialDefinitions.all
            .filter { $0.format != .theLastGate }
            .filter { definition in
                passedDefinitionIds.contains(definition.id)
                    || !passedDefinitionIds.isDisjoint(with: definition.legacyIds)
            }
            .count
    }
}
