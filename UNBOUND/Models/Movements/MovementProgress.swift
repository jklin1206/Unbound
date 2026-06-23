import Foundation

enum RewardLedgerQuantizer {
    static func wholePoints(from rawValue: Double, minimumForPositive: Int = 1) -> Double {
        guard rawValue.isFinite, rawValue > 0 else { return 0 }
        return Double(max(minimumForPositive, Int(rawValue.rounded())))
    }

    static func splitWholePoints(
        total rawTotal: Double,
        weights: [(key: AttributeKey, weight: Double)]
    ) -> [AttributeKey: Double] {
        let total = Int(wholePoints(from: rawTotal))
        guard total > 0 else { return [:] }

        let positiveWeights = weights.filter { $0.weight > 0 }
        let weightSum = positiveWeights.reduce(0.0) { $0 + $1.weight }
        guard weightSum > 0 else { return [:] }

        let keyOrder = Dictionary(uniqueKeysWithValues: AttributeKey.allCases.enumerated().map { ($0.element, $0.offset) })
        var rows = positiveWeights.map { entry in
            let exact = Double(total) * entry.weight / weightSum
            let floorValue = Int(floor(exact))
            return (
                key: entry.key,
                points: floorValue,
                remainder: exact - Double(floorValue)
            )
        }

        let assigned = rows.reduce(0) { $0 + $1.points }
        let remaining = max(0, total - assigned)
        if remaining > 0 {
            let indicesByRemainder = rows.indices.sorted { lhs, rhs in
                if rows[lhs].remainder == rows[rhs].remainder {
                    return (keyOrder[rows[lhs].key] ?? Int.max) < (keyOrder[rows[rhs].key] ?? Int.max)
                }
                return rows[lhs].remainder > rows[rhs].remainder
            }
            for index in indicesByRemainder.prefix(remaining) {
                rows[index].points += 1
            }
        }

        var result: [AttributeKey: Double] = [:]
        for row in rows where row.points > 0 {
            result[row.key] = Double(row.points)
        }
        return result
    }
}

struct MovementProgressState: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(userId):\(rankStandardMovementId)" }

    let userId: String
    var rankStandardMovementId: String
    var displayName: String
    var rankTemplate: MovementRankTemplate

    /// Whole-number workout ledger earned for this ranked movement standard.
    /// The stored field still uses the legacy AP name; it does not grant a
    /// movement rank by itself.
    var totalAP: Double
    var provenTier: SkillTier

    var bestEstimatedOneRepMaxKg: Double?
    var bestLoadKg: Double?
    var bestReps: Int?
    var bestHoldSeconds: Int?
    var bestDurationSeconds: Int?
    var bestDistanceMeters: Int?
    var bestCalories: Int?

    var lastGainedAP: Double
    var lastLoggedAt: Date?
    var contributingMovementIds: [String]
    var processedSourceLogIds: [String]
    var updatedAt: Date

    init(
        userId: String,
        rankStandardMovementId: String,
        displayName: String,
        rankTemplate: MovementRankTemplate,
        totalAP: Double = 0,
        provenTier: SkillTier = .initiate,
        bestEstimatedOneRepMaxKg: Double? = nil,
        bestLoadKg: Double? = nil,
        bestReps: Int? = nil,
        bestHoldSeconds: Int? = nil,
        bestDurationSeconds: Int? = nil,
        bestDistanceMeters: Int? = nil,
        bestCalories: Int? = nil,
        lastGainedAP: Double = 0,
        lastLoggedAt: Date? = nil,
        contributingMovementIds: [String] = [],
        processedSourceLogIds: [String] = [],
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.rankStandardMovementId = rankStandardMovementId
        self.displayName = displayName
        self.rankTemplate = rankTemplate
        self.totalAP = totalAP
        self.provenTier = provenTier
        self.bestEstimatedOneRepMaxKg = bestEstimatedOneRepMaxKg
        self.bestLoadKg = bestLoadKg
        self.bestReps = bestReps
        self.bestHoldSeconds = bestHoldSeconds
        self.bestDurationSeconds = bestDurationSeconds
        self.bestDistanceMeters = bestDistanceMeters
        self.bestCalories = bestCalories
        self.lastGainedAP = lastGainedAP
        self.lastLoggedAt = lastLoggedAt
        self.contributingMovementIds = contributingMovementIds
        self.processedSourceLogIds = processedSourceLogIds
        self.updatedAt = updatedAt
    }

    mutating func apply(gains: [MovementAPGain], sourceLogId: String) {
        guard !gains.isEmpty else { return }

        let gainedAP = gains.reduce(0) { $0 + $1.rawAP }
        totalAP += gainedAP
        lastGainedAP = gainedAP
        lastLoggedAt = gains.map(\.occurredAt).max() ?? lastLoggedAt

        bestEstimatedOneRepMaxKg = maxOptional(bestEstimatedOneRepMaxKg, gains.compactMap(\.estimatedOneRepMaxKg).max())
        bestLoadKg = maxOptional(bestLoadKg, gains.compactMap(\.loadKg).max())
        bestReps = maxOptional(bestReps, gains.compactMap(\.reps).max())
        bestHoldSeconds = maxOptional(bestHoldSeconds, gains.compactMap(\.holdSeconds).max())
        bestDurationSeconds = maxOptional(bestDurationSeconds, gains.compactMap(\.durationSeconds).max())
        bestDistanceMeters = maxOptional(bestDistanceMeters, gains.compactMap(\.distanceMeters).max())
        bestCalories = maxOptional(bestCalories, gains.compactMap(\.calories).max())

        var movementIds = Set(contributingMovementIds)
        gains.forEach { movementIds.insert($0.movementId) }
        contributingMovementIds = movementIds.sorted()

        if !processedSourceLogIds.contains(sourceLogId) {
            processedSourceLogIds.append(sourceLogId)
        }
        updatedAt = Date()
    }

    /// Fold a retired standard's row into this one (P3 consolidation): the same
    /// physical movement that used to bank into a separate rank standard. Sums
    /// the ledger, keeps the best of every metric, and unions the dedupe sets so
    /// no source log is ever re-applied.
    mutating func merge(from other: MovementProgressState) {
        totalAP += other.totalAP
        provenTier = max(provenTier, other.provenTier)

        bestEstimatedOneRepMaxKg = maxOptional(bestEstimatedOneRepMaxKg, other.bestEstimatedOneRepMaxKg)
        bestLoadKg = maxOptional(bestLoadKg, other.bestLoadKg)
        bestReps = maxOptional(bestReps, other.bestReps)
        bestHoldSeconds = maxOptional(bestHoldSeconds, other.bestHoldSeconds)
        bestDurationSeconds = maxOptional(bestDurationSeconds, other.bestDurationSeconds)
        bestDistanceMeters = maxOptional(bestDistanceMeters, other.bestDistanceMeters)
        bestCalories = maxOptional(bestCalories, other.bestCalories)

        // Keep the most recent activity and its reward amount.
        if let otherLast = other.lastLoggedAt,
           lastLoggedAt.map({ otherLast > $0 }) ?? true {
            lastGainedAP = other.lastGainedAP
            lastLoggedAt = otherLast
        }

        contributingMovementIds = Set(contributingMovementIds).union(other.contributingMovementIds).sorted()
        processedSourceLogIds = Set(processedSourceLogIds).union(other.processedSourceLogIds).sorted()
        updatedAt = Date()
    }

    mutating func refreshProvenTier(bodyweightKg: Double?, sex: BiologicalSex?) {
        provenTier = MovementProgressTierResolver.provenTier(
            for: self,
            bodyweightKg: bodyweightKg,
            sex: sex
        )
    }

    private func maxOptional<T: Comparable>(_ lhs: T?, _ rhs: T?) -> T? {
        switch (lhs, rhs) {
        case let (l?, r?): return max(l, r)
        case let (l?, nil): return l
        case let (nil, r?): return r
        case (nil, nil): return nil
        }
    }
}

enum MovementProgressTierResolver {
    static func provenTier(
        for state: MovementProgressState,
        bodyweightKg: Double?,
        sex: BiologicalSex?
    ) -> SkillTier {
        guard let derived = derivedTier(for: state, bodyweightKg: bodyweightKg, sex: sex) else {
            return state.provenTier
        }
        return max(state.provenTier, derived)
    }

    static func derivedTier(
        for state: MovementProgressState,
        bodyweightKg: Double?,
        sex: BiologicalSex?
    ) -> SkillTier? {
        guard let metric = metricValue(for: state) else { return nil }
        return StrengthStandards.progressToNextRank(
            metricValue: metric,
            bodyweightKg: bodyweightKg ?? 0,
            exerciseKey: state.displayName,
            sex: sex
        )?.current
    }

    private static func metricValue(for state: MovementProgressState) -> Double? {
        switch state.rankTemplate {
        case .barbellStrength, .machineStrength, .weightedBodyweight:
            return state.bestEstimatedOneRepMaxKg ?? state.bestLoadKg
        case .bodyweightReps:
            return state.bestReps.map(Double.init)
        case .holdControl:
            return (state.bestHoldSeconds ?? state.bestDurationSeconds).map(Double.init)
        case .carrySled, .cardioPerformance, .mobilityDuration, .routineCompletion, .unranked:
            return nil
        }
    }
}

struct MovementProgressSourceReceipt: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(sourceLogId):\(rankStandardMovementId)" }

    let sourceLogId: String
    let userId: String
    let rankStandardMovementId: String
    let gains: [MovementAPGain]
    let priorState: MovementProgressState
    let updatedState: MovementProgressState
}

struct MovementAPGain: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var userId: String
    var sourceLogId: String
    var sourceExerciseId: String?
    var movementId: String
    var rankStandardMovementId: String
    var movementDisplayName: String
    var standardDisplayName: String
    var rankTemplate: MovementRankTemplate
    var rawAP: Double
    var reps: Int?
    var loadKg: Double?
    var holdSeconds: Int?
    var durationSeconds: Int?
    var distanceMeters: Int?
    var calories: Int?
    var estimatedOneRepMaxKg: Double?
    var occurredAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        sourceLogId: String,
        sourceExerciseId: String?,
        movementId: String,
        rankStandardMovementId: String,
        movementDisplayName: String,
        standardDisplayName: String,
        rankTemplate: MovementRankTemplate,
        rawAP: Double,
        reps: Int? = nil,
        loadKg: Double? = nil,
        holdSeconds: Int? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Int? = nil,
        calories: Int? = nil,
        estimatedOneRepMaxKg: Double? = nil,
        occurredAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.sourceLogId = sourceLogId
        self.sourceExerciseId = sourceExerciseId
        self.movementId = movementId
        self.rankStandardMovementId = rankStandardMovementId
        self.movementDisplayName = movementDisplayName
        self.standardDisplayName = standardDisplayName
        self.rankTemplate = rankTemplate
        self.rawAP = rawAP
        self.reps = reps
        self.loadKg = loadKg
        self.holdSeconds = holdSeconds
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.calories = calories
        self.estimatedOneRepMaxKg = estimatedOneRepMaxKg
        self.occurredAt = occurredAt
    }
}

struct MovementProgressIngestResult: Hashable, Sendable {
    var gains: [MovementAPGain] = []
    var updatedStates: [MovementProgressState] = []
    /// Per-standard state BEFORE this log was applied, keyed by standard id.
    /// Used to derive each movement's prior RankTier for rank-up detection.
    var priorStates: [String: MovementProgressState] = [:]

    var totalAP: Double {
        gains.reduce(0) { $0 + $1.rawAP }
    }
}
