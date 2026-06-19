import Foundation

struct GateKeyDefinition: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let movementIds: [String]
    let metric: GateKeyMetric
}

enum GateKeyMetric: Equatable, Sendable {
    /// Reach `rank` in any `count` of the 6 attributes — build-expressive (you pick
    /// which axes). Replaces the old per-exercise keystone keys.
    case attributesAtRank(count: Int, rank: RankTier)
    /// Structural meta-gate: N prior gates cleared (the final gate only).
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
        case .firstLight:   return []                       // level only
        case .theCount:     return [attrs(1, .novice)]
        case .theForging:   return [attrs(1, .apprentice)]
        case .deckOfProof:  return [attrs(2, .forged)]
        case .theAscent:    return [attrs(2, .veteran)]
        case .sevenSeals:   return [attrs(3, .veteran)]
        case .theThreshold: return [attrs(3, .master)]
        case .theLastGate:  return [gatesCleared(7), attrs(3, .master)]
        }
    }

    /// "Any K of your 6 attributes at rank R" — pick the axes that fit your build.
    private static func attrs(_ count: Int, _ rank: RankTier) -> GateKeyDefinition {
        GateKeyDefinition(
            id: "key-attrs-\(count)-\(rank.token)",
            label: "Any \(count) attribute\(count == 1 ? "" : "s") at \(rank.displayName)",
            movementIds: [],
            metric: .attributesAtRank(count: count, rank: rank)
        )
    }

    /// Structural meta-gate: N prior gates cleared (the final gate only).
    private static func gatesCleared(_ count: Int) -> GateKeyDefinition {
        GateKeyDefinition(
            id: "key-gates-answered-\(count)",
            label: "\(count) gates answered",
            movementIds: [],
            metric: .gatesAnswered(count)
        )
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
        case .attributesAtRank(let count, let rank):
            guard let profile = gateKeyAttributeProfile else { return false }
            let met = AttributeKey.allCases.filter { profile.value(for: $0).rankTitle >= rank }.count
            return met >= count
        case .gatesAnswered(let count):
            return passedGateCount >= count
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
