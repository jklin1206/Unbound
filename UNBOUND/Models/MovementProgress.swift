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

    /// Whole-number Ascension Points earned for this ranked movement standard.
    /// AP is a work ledger; it does not grant a movement rank by itself.
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

    private func maxOptional<T: Comparable>(_ lhs: T?, _ rhs: T?) -> T? {
        switch (lhs, rhs) {
        case let (l?, r?): return max(l, r)
        case let (l?, nil): return l
        case let (nil, r?): return r
        case (nil, nil): return nil
        }
    }
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

    var totalAP: Double {
        gains.reduce(0) { $0 + $1.rawAP }
    }
}

enum OverallLevelCurve {
    /// Overall LV uses the same concave shape as attribute levels, but a
    /// larger pool so it represents total time-in-game instead of one axis.
    static let lvBase: Double = 250
    static let exponent: Double = AttributeLevelCurve.exponent
    static let softCapLevel: Int = 100
    static let cappedXPPerLevel: Double = 3_750

    static func level(forXP xp: Double) -> Int {
        guard xp > 0 else { return 0 }
        let softCapXP = xpRequiredForUncappedLevel(softCapLevel)
        guard xp >= softCapXP else {
            return max(0, Int(floor(pow(xp / lvBase, 1.0 / exponent) + 1e-9)))
        }
        return softCapLevel + Int(floor((xp - softCapXP) / cappedXPPerLevel + 1e-9))
    }

    static func xpRequired(forLevel level: Int) -> Double {
        guard level > 0 else { return 0 }
        guard level > softCapLevel else {
            return xpRequiredForUncappedLevel(level)
        }
        return xpRequiredForUncappedLevel(softCapLevel)
            + Double(level - softCapLevel) * cappedXPPerLevel
    }

    static func progressFraction(forXP xp: Double) -> Double {
        let level = level(forXP: xp)
        let floorXP = xpRequired(forLevel: level)
        let nextXP = xpRequired(forLevel: level + 1)
        guard nextXP > floorXP else { return 0 }
        return min(1, max(0, (xp - floorXP) / (nextXP - floorXP)))
    }

    private static func xpRequiredForUncappedLevel(_ level: Int) -> Double {
        lvBase * pow(Double(max(0, level)), exponent)
    }
}

struct OverallLevelProgress: Codable, Identifiable, Hashable, Sendable {
    var id: String { userId }

    let userId: String
    var totalXP: Double
    var lastGainedXP: Double
    var processedSourceLogIds: [String]
    var updatedAt: Date

    init(
        userId: String,
        totalXP: Double = 0,
        lastGainedXP: Double = 0,
        processedSourceLogIds: [String] = [],
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.totalXP = totalXP
        self.lastGainedXP = lastGainedXP
        self.processedSourceLogIds = processedSourceLogIds
        self.updatedAt = updatedAt
    }

    var level: Int {
        OverallLevelCurve.level(forXP: totalXP)
    }

    var progressToNextLevel: Double {
        OverallLevelCurve.progressFraction(forXP: totalXP)
    }

    mutating func apply(xpGained: Double, sourceLogId: String, at date: Date) {
        totalXP += max(0, xpGained)
        lastGainedXP = max(0, xpGained)
        if !processedSourceLogIds.contains(sourceLogId) {
            processedSourceLogIds.append(sourceLogId)
        }
        if processedSourceLogIds.count > 250 {
            processedSourceLogIds.removeFirst(processedSourceLogIds.count - 250)
        }
        updatedAt = date
    }
}

struct OverallLevelReward: Codable, Hashable, Sendable {
    var xpGained: Double
    var noveltyMultiplier: Double
    var previousXP: Double
    var currentXP: Double
    var previousLevel: Int
    var currentLevel: Int
    var previousProgressToNextLevel: Double
    var currentProgressToNextLevel: Double

    var didLevelUp: Bool {
        currentLevel > previousLevel
    }
}

struct BodyRegionLoad: Codable, Hashable, Sendable {
    var recentLoad: Double
    var lifetimeLoad: Double
    var lastTrainedAt: Date?

    init(recentLoad: Double = 0, lifetimeLoad: Double = 0, lastTrainedAt: Date? = nil) {
        self.recentLoad = recentLoad
        self.lifetimeLoad = lifetimeLoad
        self.lastTrainedAt = lastTrainedAt
    }
}

struct BodyMapProfile: Codable, Identifiable, Hashable, Sendable {
    var id: String { userId }

    let userId: String
    var regionLoads: [String: BodyRegionLoad]
    var processedSourceLogIds: [String]
    var updatedAt: Date

    init(
        userId: String,
        regionLoads: [String: BodyRegionLoad] = [:],
        processedSourceLogIds: [String] = [],
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.regionLoads = regionLoads
        self.processedSourceLogIds = processedSourceLogIds
        self.updatedAt = updatedAt
    }

    func load(for region: BodyRegion) -> BodyRegionLoad {
        regionLoads[region.rawValue] ?? BodyRegionLoad()
    }

    mutating func setLoad(_ load: BodyRegionLoad, for region: BodyRegion) {
        regionLoads[region.rawValue] = load
    }
}

struct BodyMapRegionReward: Codable, Identifiable, Hashable, Sendable {
    var id: String { region.rawValue }

    var region: BodyRegion
    var loadAdded: Double
    var recentLoad: Double
    var lifetimeLoad: Double
    var lastTrainedAt: Date
}

struct BodyMapIngestResult: Codable, Hashable, Sendable {
    var noveltyMultiplier: Double = 1.0
    var regionRewards: [BodyMapRegionReward] = []
    var wasDuplicate: Bool = false

    var updatedRegions: [BodyRegion] {
        regionRewards.map(\.region)
    }
}

extension Notification.Name {
    static let movementProgressUpdated = Notification.Name("unbound.movementProgressUpdated")
    static let overallLevelProgressUpdated = Notification.Name("unbound.overallLevelProgressUpdated")
    static let bodyMapProgressUpdated = Notification.Name("unbound.bodyMapProgressUpdated")
}
