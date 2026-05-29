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
    /// Per-standard state BEFORE this log was applied, keyed by standard id.
    /// Used to derive each movement's prior RankTier for rank-up detection.
    var priorStates: [String: MovementProgressState] = [:]

    var totalAP: Double {
        gains.reduce(0) { $0 + $1.rawAP }
    }
}

enum OverallLevelCurve {
    /// Overall LVL uses the same concave shape as attribute levels, but a
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
    var recentDirectHardSets: Double
    var recentSecondaryExposureSets: Double
    var recentSkillPracticeSets: Double
    var recentMobilityControlSets: Double
    var recentJointTendonStressSets: Double

    init(
        recentLoad: Double = 0,
        lifetimeLoad: Double = 0,
        lastTrainedAt: Date? = nil,
        recentDirectHardSets: Double = 0,
        recentSecondaryExposureSets: Double = 0,
        recentSkillPracticeSets: Double = 0,
        recentMobilityControlSets: Double = 0,
        recentJointTendonStressSets: Double = 0
    ) {
        self.recentLoad = recentLoad
        self.lifetimeLoad = lifetimeLoad
        self.lastTrainedAt = lastTrainedAt
        self.recentDirectHardSets = recentDirectHardSets
        self.recentSecondaryExposureSets = recentSecondaryExposureSets
        self.recentSkillPracticeSets = recentSkillPracticeSets
        self.recentMobilityControlSets = recentMobilityControlSets
        self.recentJointTendonStressSets = recentJointTendonStressSets
    }

    var recentRoleCoachLoad: Double {
        recentDirectHardSets
            + recentSecondaryExposureSets * 0.35
            + recentSkillPracticeSets * 0.6
            + recentMobilityControlSets * 0.2
            + recentJointTendonStressSets * 0.5
    }

    func recentSets(for role: BodyRegionSetRole) -> Double {
        switch role {
        case .directHardSet:
            return recentDirectHardSets
        case .secondaryExposure:
            return recentSecondaryExposureSets
        case .skillPractice:
            return recentSkillPracticeSets
        case .mobilityControl:
            return recentMobilityControlSets
        case .jointTendonStress:
            return recentJointTendonStressSets
        }
    }

    mutating func decayRecentRoleSets(by factor: Double) {
        recentDirectHardSets *= factor
        recentSecondaryExposureSets *= factor
        recentSkillPracticeSets *= factor
        recentMobilityControlSets *= factor
        recentJointTendonStressSets *= factor
    }

    mutating func addRecentRoleSets(_ trainingLoad: BodyRegionTrainingLoad) {
        recentDirectHardSets += trainingLoad.directHardSets
        recentSecondaryExposureSets += trainingLoad.secondaryExposureSets
        recentSkillPracticeSets += trainingLoad.skillPracticeSets
        recentMobilityControlSets += trainingLoad.mobilityControlSets
        recentJointTendonStressSets += trainingLoad.jointTendonStressSets
    }

    private enum CodingKeys: String, CodingKey {
        case recentLoad
        case lifetimeLoad
        case lastTrainedAt
        case recentDirectHardSets
        case recentSecondaryExposureSets
        case recentSkillPracticeSets
        case recentMobilityControlSets
        case recentJointTendonStressSets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recentLoad = try container.decodeIfPresent(Double.self, forKey: .recentLoad) ?? 0
        lifetimeLoad = try container.decodeIfPresent(Double.self, forKey: .lifetimeLoad) ?? 0
        lastTrainedAt = try container.decodeIfPresent(Date.self, forKey: .lastTrainedAt)
        recentDirectHardSets = try container.decodeIfPresent(Double.self, forKey: .recentDirectHardSets) ?? 0
        recentSecondaryExposureSets = try container.decodeIfPresent(Double.self, forKey: .recentSecondaryExposureSets) ?? 0
        recentSkillPracticeSets = try container.decodeIfPresent(Double.self, forKey: .recentSkillPracticeSets) ?? 0
        recentMobilityControlSets = try container.decodeIfPresent(Double.self, forKey: .recentMobilityControlSets) ?? 0
        recentJointTendonStressSets = try container.decodeIfPresent(Double.self, forKey: .recentJointTendonStressSets) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recentLoad, forKey: .recentLoad)
        try container.encode(lifetimeLoad, forKey: .lifetimeLoad)
        try container.encodeIfPresent(lastTrainedAt, forKey: .lastTrainedAt)
        try container.encode(recentDirectHardSets, forKey: .recentDirectHardSets)
        try container.encode(recentSecondaryExposureSets, forKey: .recentSecondaryExposureSets)
        try container.encode(recentSkillPracticeSets, forKey: .recentSkillPracticeSets)
        try container.encode(recentMobilityControlSets, forKey: .recentMobilityControlSets)
        try container.encode(recentJointTendonStressSets, forKey: .recentJointTendonStressSets)
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

enum BodyRegionSetRole: String, Codable, CaseIterable, Hashable, Sendable {
    case directHardSet
    case secondaryExposure
    case skillPractice
    case mobilityControl
    case jointTendonStress
}

struct BodyRegionTrainingLoad: Codable, Hashable, Sendable, Identifiable {
    var id: String { region.rawValue }

    var region: BodyRegion
    var directHardSets: Double
    var secondaryExposureSets: Double
    var skillPracticeSets: Double
    var mobilityControlSets: Double
    var jointTendonStressSets: Double
    var rawTaggedSets: Double

    init(
        region: BodyRegion,
        directHardSets: Double = 0,
        secondaryExposureSets: Double = 0,
        skillPracticeSets: Double = 0,
        mobilityControlSets: Double = 0,
        jointTendonStressSets: Double = 0,
        rawTaggedSets: Double = 0
    ) {
        self.region = region
        self.directHardSets = directHardSets
        self.secondaryExposureSets = secondaryExposureSets
        self.skillPracticeSets = skillPracticeSets
        self.mobilityControlSets = mobilityControlSets
        self.jointTendonStressSets = jointTendonStressSets
        self.rawTaggedSets = rawTaggedSets
    }

    var coachLoadScore: Double {
        directHardSets
            + secondaryExposureSets * 0.35
            + skillPracticeSets * 0.6
            + mobilityControlSets * 0.2
            + jointTendonStressSets * 0.5
    }

    mutating func add(_ sets: Double, as role: BodyRegionSetRole) {
        guard sets > 0 else { return }
        rawTaggedSets += sets
        switch role {
        case .directHardSet:
            directHardSets += sets
        case .secondaryExposure:
            secondaryExposureSets += sets
        case .skillPractice:
            skillPracticeSets += sets
        case .mobilityControl:
            mobilityControlSets += sets
        case .jointTendonStress:
            jointTendonStressSets += sets
        }
    }

    mutating func merge(_ other: BodyRegionTrainingLoad) {
        directHardSets += other.directHardSets
        secondaryExposureSets += other.secondaryExposureSets
        skillPracticeSets += other.skillPracticeSets
        mobilityControlSets += other.mobilityControlSets
        jointTendonStressSets += other.jointTendonStressSets
        rawTaggedSets += other.rawTaggedSets
    }
}

enum BodyRegionTrainingLedger {
    static func loads(for workout: Workout, includeWarmupCooldown: Bool = false) -> [BodyRegionTrainingLoad] {
        let exercises = includeWarmupCooldown
            ? workout.warmup + workout.mainExercises + workout.cooldown
            : workout.mainExercises
        return loads(for: exercises)
    }

    static func loads(for exercises: [Exercise]) -> [BodyRegionTrainingLoad] {
        var rows: [BodyRegion: BodyRegionTrainingLoad] = [:]
        for exercise in exercises {
            add(
                name: exercise.name,
                movementId: nil,
                rankStandardMovementId: nil,
                sets: exercise.sets,
                muscleGroups: exercise.muscleGroups,
                blockKind: nil,
                to: &rows
            )
        }
        return sorted(rows)
    }

    static func loads(for performanceLog: PerformanceLog) -> [BodyRegionTrainingLoad] {
        var rows: [BodyRegion: BodyRegionTrainingLoad] = [:]
        for block in performanceLog.blocks {
            for exercise in block.exercises where !exercise.skipped {
                let completedSets = exercise.sets.filter { !$0.isWarmup }.count
                add(
                    name: exercise.name,
                    movementId: exercise.movementId,
                    rankStandardMovementId: exercise.rankStandardMovementId,
                    sets: completedSets > 0 ? completedSets : exercise.plannedSets,
                    muscleGroups: [],
                    blockKind: block.kind,
                    to: &rows
                )
            }
        }
        return sorted(rows)
    }

    static func loads(for draft: TrainingSessionDraft) -> [BodyRegionTrainingLoad] {
        var rows: [BodyRegion: BodyRegionTrainingLoad] = [:]
        for block in draft.blocks {
            for prescription in block.prescriptions {
                add(
                    name: prescription.exerciseName,
                    movementId: prescription.movementId,
                    rankStandardMovementId: prescription.rankStandardMovementId,
                    sets: prescription.sets,
                    muscleGroups: prescription.muscleGroups,
                    blockKind: block.kind,
                    to: &rows
                )
            }
        }
        return sorted(rows)
    }

    private static func add(
        name: String,
        movementId: String?,
        rankStandardMovementId: String?,
        sets: Int,
        muscleGroups: [MuscleGroup],
        blockKind: TrainingBlockKind?,
        to rows: inout [BodyRegion: BodyRegionTrainingLoad]
    ) {
        let setCount = Double(max(0, sets))
        guard setCount > 0 else { return }

        let definition = MovementCatalog.resolvedTrainingMovement(
            name: name,
            movementId: movementId,
            rankStandardMovementId: rankStandardMovementId
        )?.exact
        let catalogRegions = bodyRegions(definition: definition, name: name, fallbackMuscleGroups: muscleGroups)
        let regions = blockKind == .carry
            ? Array(Set(catalogRegions + bodyRegions(from: muscleGroups))).sorted { $0.rawValue < $1.rawValue }
            : catalogRegions
        guard !regions.isEmpty else { return }

        let primary = Set(primaryRegions(definition: definition, name: name, regions: regions))
        for region in regions {
            let role = role(
                for: region,
                primaryRegions: primary,
                definition: definition,
                blockKind: blockKind
            )
            var load = rows[region] ?? BodyRegionTrainingLoad(region: region)
            load.add(setCount, as: role)
            if shouldOverlayJointTendonStress(
                region: region,
                role: role,
                definition: definition
            ) {
                load.add(setCount, as: .jointTendonStress)
            }
            rows[region] = load
        }
    }

    private static func shouldOverlayJointTendonStress(
        region: BodyRegion,
        role: BodyRegionSetRole,
        definition: MovementDefinition?
    ) -> Bool {
        guard role == .skillPractice,
              let definition,
              definition.movementSlot == .skill || definition.role == .skillDrill || definition.role == .skillTarget
        else { return false }

        if region == .forearms, definition.contraindicationTags.contains("wrist-sensitive") {
            return true
        }
        if region == .shoulders, definition.contraindicationTags.contains("shoulder-sensitive") {
            return true
        }
        return false
    }

    private static func role(
        for region: BodyRegion,
        primaryRegions: Set<BodyRegion>,
        definition: MovementDefinition?,
        blockKind: TrainingBlockKind?
    ) -> BodyRegionSetRole {
        if blockKind == .skill
            || definition?.movementSlot == .skill
            || definition?.role == .skillTarget
            || definition?.role == .skillDrill {
            return .skillPractice
        }

        if definition?.movementSlot == .mobility || definition?.loggerMode == .mobility {
            return .mobilityControl
        }

        if blockKind == .carry || definition?.movementSlot == .carry {
            return [.forearms, .traps, .lowerBack, .shoulders].contains(region)
                ? .jointTendonStress
                : .secondaryExposure
        }

        return primaryRegions.contains(region) ? .directHardSet : .secondaryExposure
    }

    private static func primaryRegions(
        definition: MovementDefinition?,
        name: String,
        regions: [BodyRegion]
    ) -> [BodyRegion] {
        let normalized = MovementCatalog.normalized(name)
        let present = Set(regions)

        func filtered(_ candidates: [BodyRegion]) -> [BodyRegion] {
            let matches = candidates.filter { present.contains($0) }
            return matches.isEmpty ? regions : matches
        }

        guard let definition else {
            if present.contains(.lowerBack), present.contains(.abs) || present.contains(.obliques) {
                if isLowerBackDominantCoreName(normalized) {
                    return filtered([.lowerBack, .glutes])
                }
                return filtered([.abs, .obliques])
            }
            return regions
        }

        switch definition.movementSlot {
        case .horizontalPush:
            return filtered([.chest])
        case .verticalPush:
            return filtered([.shoulders])
        case .horizontalPull, .verticalPull:
            if normalized.contains("face pull") {
                return filtered([.traps, .shoulders])
            }
            return filtered([.lats, .traps])
        case .squat:
            return filtered([.quads, .glutes])
        case .hinge:
            return filtered([.hamstrings, .glutes, .lowerBack])
        case .arms:
            if normalized.contains("tricep")
                || normalized.contains("skull")
                || normalized.contains("extension")
                || normalized.contains("close grip") {
                return filtered([.triceps])
            }
            if normalized.contains("curl") {
                return filtered([.biceps, .forearms])
            }
            return filtered([.biceps, .triceps, .forearms])
        case .core:
            if isLowerBackDominantCoreName(normalized) {
                return filtered([.lowerBack, .glutes])
            }
            return filtered([.abs, .obliques])
        case .calves:
            return filtered([.calves])
        case .carry:
            return filtered([.forearms, .traps, .lowerBack])
        case .cardio, .mobility, .routine, .skill:
            return regions
        }
    }

    private static func isLowerBackDominantCoreName(_ normalized: String) -> Bool {
        normalized.contains("back extension")
            || normalized.contains("reverse hyper")
            || normalized.contains("superman")
            || normalized.contains("bird dog")
    }

    private static func bodyRegions(
        definition: MovementDefinition?,
        name: String,
        fallbackMuscleGroups: [MuscleGroup]
    ) -> [BodyRegion] {
        if let regions = definition?.bodyRegions, !regions.isEmpty {
            return refined(regions: regions, definition: definition, name: name)
        }
        let regions = bodyRegions(from: fallbackMuscleGroups)
        return Array(Set(regions)).sorted { $0.rawValue < $1.rawValue }
    }

    private static func bodyRegions(from muscleGroups: [MuscleGroup]) -> [BodyRegion] {
        muscleGroups.flatMap { group -> [BodyRegion] in
            switch group {
            case .chest: return [.chest]
            case .back: return [.lats, .traps, .lowerBack]
            case .shoulders: return [.shoulders]
            case .arms: return [.biceps, .triceps, .forearms]
            case .forearms: return [.forearms]
            case .legs: return [.quads, .hamstrings, .glutes, .calves]
            case .glutes: return [.glutes]
            case .core: return [.abs, .obliques, .lowerBack]
            case .traps: return [.traps]
            case .lats: return [.lats]
            case .calves: return [.calves]
            case .neck: return []
            }
        }
    }

    private static func refined(
        regions: [BodyRegion],
        definition: MovementDefinition?,
        name: String
    ) -> [BodyRegion] {
        guard let definition else {
            return Array(Set(regions)).sorted { $0.rawValue < $1.rawValue }
        }

        let normalized = MovementCatalog.normalized(name)
        let filtered: [BodyRegion]
        switch definition.movementSlot {
        case .horizontalPush, .verticalPush:
            filtered = regions.filter { $0 != .biceps }
        case .horizontalPull, .verticalPull:
            filtered = regions.filter { $0 != .triceps }
        case .arms where normalized.contains("curl"):
            filtered = regions.filter { $0 != .triceps }
        case .arms where normalized.contains("tricep")
            || normalized.contains("skull")
            || normalized.contains("extension")
            || normalized.contains("close grip"):
            filtered = regions.filter { $0 != .biceps }
        default:
            filtered = regions
        }

        return Array(Set(filtered)).sorted { $0.rawValue < $1.rawValue }
    }

    private static func sorted(_ rows: [BodyRegion: BodyRegionTrainingLoad]) -> [BodyRegionTrainingLoad] {
        rows.values.sorted { $0.region.rawValue < $1.region.rawValue }
    }
}

extension Notification.Name {
    static let movementProgressUpdated = Notification.Name("unbound.movementProgressUpdated")
    static let overallLevelProgressUpdated = Notification.Name("unbound.overallLevelProgressUpdated")
    static let bodyMapProgressUpdated = Notification.Name("unbound.bodyMapProgressUpdated")
}
