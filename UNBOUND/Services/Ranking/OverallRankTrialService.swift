import Foundation

enum OverallRankTrialStatus: String, Codable, Equatable, Sendable {
    case locked
    case ready
    case attempted
    case passed
    case failed
}

enum OverallRankTrialRequirementKind: String, Codable, Equatable, Sendable {
    case overallLevel
    case rank
    case equipment
}

enum RankTrialFormat: String, Codable, CaseIterable, Equatable, Sendable {
    case daily100
    case operatorScreen
    case finisher
    case fixedDeck
    case tower
    case bossRush
    case raid
    case finalExam

    var displayName: String {
        switch self {
        case .daily100: return "Daily 100"
        case .operatorScreen: return "Operator Screen"
        case .finisher: return "Finisher"
        case .fixedDeck: return "Random Deck"
        case .tower: return "Tower"
        case .bossRush: return "Boss Rush"
        case .raid: return "Raid"
        case .finalExam: return "Final Exam"
        }
    }
}

private struct DeckDrawRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

enum TrialLoadout: String, Codable, CaseIterable, Equatable, Sendable {
    case noGymField
    case homeKit
    case gymHybrid

    var displayName: String {
        switch self {
        case .noGymField: return "No-Gym Field"
        case .homeKit: return "Home Kit"
        case .gymHybrid: return "Gym Hybrid"
        }
    }
}

enum TrialMovementCategory: String, Codable, CaseIterable, Equatable, Sendable {
    case engine
    case lower
    case hingePower
    case push
    case pull
    case carryCore
    case explosive
    case mobilityControl

    var displayName: String {
        switch self {
        case .engine: return "Engine"
        case .lower: return "Lower"
        case .hingePower: return "Hinge / Power"
        case .push: return "Push"
        case .pull: return "Pull"
        case .carryCore: return "Carry / Core"
        case .explosive: return "Explosive"
        case .mobilityControl: return "Mobility / Control"
        }
    }
}

struct OverallRankTrialRequirementLine: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let kind: OverallRankTrialRequirementKind
    let label: String
    let current: String
    let required: String
    let isMet: Bool
}

struct OverallRankTrialPerformanceStandard: Codable, Equatable, Sendable {
    let movementId: String
    let displayName: String
    let metric: TrainingMetricKind
    let minimumValue: Int
    let minimumQualifyingSets: Int
    let plannedSets: Int
    let restSeconds: Int

    init(
        movementId: String,
        displayName: String,
        metric: TrainingMetricKind,
        minimumValue: Int,
        minimumQualifyingSets: Int = 1,
        plannedSets: Int? = nil,
        restSeconds: Int? = nil
    ) {
        let qualifyingSets = max(1, minimumQualifyingSets)
        self.movementId = movementId
        self.displayName = displayName
        self.metric = metric
        self.minimumValue = minimumValue
        self.minimumQualifyingSets = qualifyingSets
        self.plannedSets = max(plannedSets ?? qualifyingSets, qualifyingSets)
        self.restSeconds = restSeconds ?? (metric == .holdSeconds ? 90 : 75)
    }

    var target: TrainingTarget {
        switch metric {
        case .reps: return .reps(minimumValue)
        case .holdSeconds: return .holdSeconds(minimumValue)
        case .durationSeconds: return .timedSeconds(minimumValue)
        case .distanceMeters: return .distanceMeters(minimumValue)
        case .calories: return .calories(minimumValue)
        }
    }

    var blockKind: TrainingBlockKind {
        MovementCatalog.definition(for: movementId)?.blockKind ?? (metric == .holdSeconds ? .skill : .bodyweight)
    }

    var skillId: String? {
        MovementCatalog.definition(for: movementId)?.skillId
    }

    var cardioType: CardioType? {
        MovementCatalog.definition(for: movementId)?.cardioType
    }
}

struct TrialMovementOption: Codable, Equatable, Sendable {
    let movementId: String
    let displayName: String
    let requiredEquipment: Set<MovementEquipment>

    init(
        movementId: String,
        displayName: String? = nil,
        requiredEquipment: Set<MovementEquipment>? = nil
    ) {
        let definition = MovementCatalog.definition(for: movementId)
        self.movementId = movementId
        self.displayName = displayName ?? definition?.displayName ?? movementId
        self.requiredEquipment = requiredEquipment ?? Set(definition?.equipment ?? [.bodyweight])
    }
}

struct TrialStation: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let title: String
    let category: TrialMovementCategory
    let standard: OverallRankTrialPerformanceStandard
    let capSeconds: Int?
    let loadPercentOfBodyweight: Double?
    let movementOptions: [TrialMovementOption]
    let restRule: String
    let qualityFlags: Set<PerformanceQualityFlag>

    var allowedMovementIds: Set<String> {
        Set(movementOptions.map(\.movementId) + [standard.movementId])
    }

    var primaryMovement: TrialMovementOption {
        movementOptions.first ?? TrialMovementOption(movementId: standard.movementId, displayName: standard.displayName)
    }
}

struct TrialLoadoutVariant: Identifiable, Codable, Equatable, Sendable {
    var id: TrialLoadout { loadout }

    let loadout: TrialLoadout
    let requiredEquipment: Set<MovementEquipment>
    let promise: String
    let stations: [TrialStation]
}

struct ResolvedTrialStation: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let station: TrialStation
    let selectedMovement: TrialMovementOption

    var category: TrialMovementCategory { station.category }
    var standard: OverallRankTrialPerformanceStandard { station.standard }
}

struct RankTrialResolutionBlocker: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let title: String
    let message: String
    let missingEquipment: Set<MovementEquipment>
}

struct ResolvedRankTrial: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let definitionId: String
    let userId: String
    let selectedLoadout: TrialLoadout
    let stations: [ResolvedTrialStation]
    let generatedAt: Date
    let version: Int

    var categoriesTested: [TrialMovementCategory] {
        var seen: Set<TrialMovementCategory> = []
        return stations.compactMap { station in
            guard seen.insert(station.category).inserted else { return nil }
            return station.category
        }
    }

    var requiredEquipment: Set<MovementEquipment> {
        stations.reduce(into: Set<MovementEquipment>()) { result, station in
            result.formUnion(station.selectedMovement.requiredEquipment)
        }
    }

    var nextPrepAction: String {
        guard let first = stations.first else { return "Keep the next rank gate in view." }
        return "Prep \(first.category.displayName.lowercased()) with \(first.selectedMovement.displayName)."
    }
}

struct RankTrialResolution: Equatable, Sendable {
    let definition: OverallRankTrialDefinition
    let resolvedTrial: ResolvedRankTrial?
    let blockers: [RankTrialResolutionBlocker]

    var isReady: Bool {
        resolvedTrial != nil && blockers.isEmpty
    }

    var blockerSummary: String? {
        blockers.first.map { "\($0.title): \($0.message)" }
    }
}

enum OverallRankTrialStationStatus: String, Codable, Equatable, Sendable {
    case passed
    case failed
    case missing
}

struct OverallRankTrialStationResult: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let title: String
    let category: TrialMovementCategory
    let movementId: String
    let required: Int
    let qualifyingSetsRequired: Int
    let qualifyingSetsCompleted: Int
    let totalValue: Int
    let failedQualityFlags: Set<PerformanceQualityFlag>
    let status: OverallRankTrialStationStatus
    let failureReason: String?
}

struct OverallRankTrialEvaluation: Codable, Equatable, Sendable {
    let definitionId: String
    let passed: Bool
    let stationResults: [OverallRankTrialStationResult]

    var failedStation: OverallRankTrialStationResult? {
        stationResults.first { $0.status != .passed }
    }
}

struct OverallRankTrialDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let targetRank: RankTitle
    let displayName: String
    let subtitle: String
    let estimatedMinutes: Int
    let format: RankTrialFormat
    let minOverallLevel: Int
    let requiredEquipment: Set<MovementEquipment>
    let performanceStandards: [OverallRankTrialPerformanceStandard]
    let loadoutVariants: [TrialLoadoutVariant]
    let legacyIds: Set<String>

    init(
        id: String,
        targetRank: RankTitle,
        displayName: String,
        subtitle: String,
        estimatedMinutes: Int,
        format: RankTrialFormat = .finisher,
        minOverallLevel: Int,
        requiredEquipment: Set<MovementEquipment>,
        performanceStandards: [OverallRankTrialPerformanceStandard],
        loadoutVariants: [TrialLoadoutVariant] = [],
        legacyIds: Set<String> = []
    ) {
        self.id = id
        self.targetRank = targetRank
        self.displayName = displayName
        self.subtitle = subtitle
        self.estimatedMinutes = estimatedMinutes
        self.format = format
        self.minOverallLevel = minOverallLevel
        self.requiredEquipment = requiredEquipment
        self.performanceStandards = performanceStandards
        self.loadoutVariants = loadoutVariants
        self.legacyIds = legacyIds
    }

    enum CodingKeys: String, CodingKey {
        case id, targetRank, displayName, subtitle, estimatedMinutes, format
        case minOverallLevel, requiredEquipment
        case performanceStandards
        case loadoutVariants, legacyIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        targetRank = try c.decode(RankTitle.self, forKey: .targetRank)
        displayName = try c.decode(String.self, forKey: .displayName)
        subtitle = try c.decode(String.self, forKey: .subtitle)
        estimatedMinutes = try c.decode(Int.self, forKey: .estimatedMinutes)
        format = try c.decode(RankTrialFormat.self, forKey: .format)
        minOverallLevel = try c.decode(Int.self, forKey: .minOverallLevel)
        requiredEquipment = try c.decode(Set<MovementEquipment>.self, forKey: .requiredEquipment)
        performanceStandards = try c.decode([OverallRankTrialPerformanceStandard].self, forKey: .performanceStandards)
        loadoutVariants = try c.decodeIfPresent([TrialLoadoutVariant].self, forKey: .loadoutVariants) ?? []
        legacyIds = try c.decodeIfPresent(Set<String>.self, forKey: .legacyIds) ?? []
    }

    func makeDraft(
        userId: String,
        date: Date = Date(),
        resolvedTrial: ResolvedRankTrial? = nil,
        bodyweightKg: Double? = nil
    ) -> TrainingSessionDraft {
        if let resolvedTrial {
            return makeStructuredDraft(userId: userId, date: date, resolvedTrial: resolvedTrial, bodyweightKg: bodyweightKg)
        }

        var groupedPrescriptions: [(TrainingBlockKind, [(OverallRankTrialPerformanceStandard, TrainingBlockPrescription)])] = []
        for standard in performanceStandards {
            let movement = MovementCatalog.definition(for: standard.movementId)
            let prescription = TrainingBlockPrescription(
                exerciseName: standard.displayName,
                movementId: standard.movementId,
                rankStandardMovementId: movement?.rankStandardMovementId ?? standard.movementId,
                sets: standard.plannedSets,
                target: standard.target,
                restSeconds: standard.restSeconds,
                muscleGroups: movement?.muscleGroups ?? [],
                rpe: 8,
                notes: "Overall Rank trial standard"
            )
            let kind = standard.blockKind
            if let index = groupedPrescriptions.firstIndex(where: { $0.0 == kind }) {
                groupedPrescriptions[index].1.append((standard, prescription))
            } else {
                groupedPrescriptions.append((kind, [(standard, prescription)]))
            }
        }

        return TrainingSessionDraft(
            userId: userId,
            source: .overallRankTrial,
            title: displayName,
            date: date,
            estimatedMinutes: estimatedMinutes,
            programId: id,
            blocks: groupedPrescriptions.map { kind, items in
                TrainingBlock(
                    kind: kind,
                    title: blockTitle(for: kind),
                    subtitle: blockSubtitle(for: kind),
                    skillId: kind == .skill ? items.compactMap { $0.0.skillId }.first : nil,
                    cardioType: kind == .cardio ? items.compactMap { $0.0.cardioType }.first : nil,
                    prescriptions: items.map { $0.1 }
                )
            }
        )
    }

    private func makeStructuredDraft(
        userId: String,
        date: Date,
        resolvedTrial: ResolvedRankTrial,
        bodyweightKg: Double?
    ) -> TrainingSessionDraft {
        let draftId = UUID().uuidString
        let stations = stationsForDraft(resolvedTrial.stations, draftId: draftId, userId: userId, date: date)

        return TrainingSessionDraft(
            id: draftId,
            userId: userId,
            source: .overallRankTrial,
            title: displayName,
            date: date,
            estimatedMinutes: estimatedMinutes,
            programId: id,
            blocks: stations.map { station in
                let selected = station.selectedMovement
                let standard = station.standard
                let movement = MovementCatalog.definition(for: selected.movementId)
                let loadPercentOfBodyweight = station.station.loadPercentOfBodyweight
                let suggestedWeightKg = loadPercentOfBodyweight.flatMap { percent in
                    bodyweightKg.map { $0 * percent }
                }
                let prescription = TrainingBlockPrescription(
                    exerciseName: selected.displayName,
                    movementId: selected.movementId,
                    rankStandardMovementId: movement?.rankStandardMovementId ?? selected.movementId,
                    sets: standard.plannedSets,
                    target: standard.target,
                    restSeconds: standard.restSeconds,
                    muscleGroups: movement?.muscleGroups ?? [],
                    rpe: 8,
                    notes: "\(resolvedTrial.selectedLoadout.displayName) rank trial station: \(station.category.displayName)",
                    loadPercentOfBodyweight: loadPercentOfBodyweight,
                    suggestedWeightKg: suggestedWeightKg
                )

                return TrainingBlock(
                    kind: standard.blockKind,
                    title: station.station.title,
                    subtitle: "\(station.category.displayName) · \(selected.displayName) · \(prescription.displayTargetText)",
                    skillId: standard.blockKind == .skill ? movement?.skillId : nil,
                    cardioType: standard.blockKind == .cardio ? movement?.cardioType : nil,
                    prescriptions: [prescription],
                    notes: station.station.restRule
                )
            }
        )
    }

    private func stationsForDraft(
        _ stations: [ResolvedTrialStation],
        draftId: String,
        userId: String,
        date: Date
    ) -> [ResolvedTrialStation] {
        guard format == .fixedDeck, stations.count > 1 else { return stations }

        var generator = DeckDrawRandomNumberGenerator(seed: deckDrawSeed(draftId: draftId, userId: userId, date: date))
        var dealt = stations.shuffled(using: &generator)
        if dealt.map(\.id) == stations.map(\.id) {
            dealt.append(dealt.removeFirst())
        }
        return dealt
    }

    private func deckDrawSeed(draftId: String, userId: String, date: Date) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(id)
        hasher.combine(draftId)
        hasher.combine(userId)
        hasher.combine(date.timeIntervalSince1970.bitPattern)
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }

    private func blockTitle(for kind: TrainingBlockKind) -> String {
        switch kind {
        case .cardio: return "Engine Standard"
        case .carry: return "Carry Standard"
        case .skill: return "Skill Standard"
        default: return "Rank Gate"
        }
    }

    private func blockSubtitle(for kind: TrainingBlockKind) -> String {
        switch kind {
        case .cardio: return "Conditioning proof"
        case .carry: return "Loaded control proof"
        case .skill: return "Clean hold proof"
        default: return subtitle
        }
    }
}
