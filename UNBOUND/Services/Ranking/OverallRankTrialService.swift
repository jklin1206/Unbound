import Foundation

enum OverallRankTrialStatus: String, Codable, Equatable, Sendable {
    case locked
    case ready
    case attempted
    case passed
    case failed
}

enum OverallRankTrialRequirementKind: String, Codable, Equatable, Sendable {
    case movement
    case skill
    case attributes
    case overallLevel
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
        case .fixedDeck: return "Fixed Deck"
        case .tower: return "Tower"
        case .bossRush: return "Boss Rush"
        case .raid: return "Raid"
        case .finalExam: return "Final Exam"
        }
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

struct OverallRankTrialMovementStandard: Codable, Equatable, Sendable {
    let rankStandardMovementId: String
    let displayName: String
    let minimumAP: Double
}

struct OverallRankTrialSkillStandard: Codable, Equatable, Sendable {
    let skillId: String
    let displayName: String
    let minimumTier: SkillTier
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
    let topAttributeCount: Int
    let topAttributeFloor: Double
    let requiredEquipment: Set<MovementEquipment>
    let movementStandards: [OverallRankTrialMovementStandard]
    let skillStandards: [OverallRankTrialSkillStandard]
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
        topAttributeCount: Int,
        topAttributeFloor: Double,
        requiredEquipment: Set<MovementEquipment>,
        movementStandards: [OverallRankTrialMovementStandard],
        skillStandards: [OverallRankTrialSkillStandard],
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
        self.topAttributeCount = topAttributeCount
        self.topAttributeFloor = topAttributeFloor
        self.requiredEquipment = requiredEquipment
        self.movementStandards = movementStandards
        self.skillStandards = skillStandards
        self.performanceStandards = performanceStandards
        self.loadoutVariants = loadoutVariants
        self.legacyIds = legacyIds
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
        TrainingSessionDraft(
            userId: userId,
            source: .overallRankTrial,
            title: displayName,
            date: date,
            estimatedMinutes: estimatedMinutes,
            programId: id,
            blocks: resolvedTrial.stations.map { station in
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
                    notes: "\(resolvedTrial.selectedLoadout.displayName) official station: \(station.category.displayName)",
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

enum OverallRankTrialDefinitions {
    private static func movementStandard(
        _ movementId: String,
        minimumAP: Double,
        displayName: String? = nil
    ) -> OverallRankTrialMovementStandard {
        OverallRankTrialMovementStandard(
            rankStandardMovementId: movementId,
            displayName: displayName ?? MovementCatalog.definition(for: movementId)?.displayName ?? movementId,
            minimumAP: minimumAP
        )
    }

    private static func skillStandard(
        _ skillId: String,
        minimumTier: SkillTier,
        displayName: String? = nil
    ) -> OverallRankTrialSkillStandard {
        OverallRankTrialSkillStandard(
            skillId: skillId,
            displayName: displayName
                ?? MovementCatalog.definition(for: "skill.\(skillId)")?.displayName
                ?? SkillGraph.shared.node(id: skillId)?.title
                ?? skillId,
            minimumTier: minimumTier
        )
    }

    private static func option(
        _ movementId: String,
        _ displayName: String? = nil,
        requiredEquipment: Set<MovementEquipment>? = nil
    ) -> TrialMovementOption {
        let normalizedRequirement: Set<MovementEquipment>?
        if let requiredEquipment {
            normalizedRequirement = requiredEquipment
        } else {
            switch movementId {
            case "exercise.step-up":
                normalizedRequirement = [.openSpace]
            case "exercise.incline-pushup":
                normalizedRequirement = [.bodyweight]
            default:
                normalizedRequirement = nil
            }
        }

        return TrialMovementOption(
            movementId: movementId,
            displayName: displayName,
            requiredEquipment: normalizedRequirement
        )
    }

    private static func performanceStandard(
        _ movementId: String,
        metric: TrainingMetricKind,
        minimumValue: Int,
        minimumQualifyingSets: Int = 1,
        plannedSets: Int? = nil,
        restSeconds: Int? = nil,
        displayName: String? = nil
    ) -> OverallRankTrialPerformanceStandard {
        OverallRankTrialPerformanceStandard(
            movementId: movementId,
            displayName: displayName ?? MovementCatalog.definition(for: movementId)?.displayName ?? movementId,
            metric: metric,
            minimumValue: minimumValue,
            minimumQualifyingSets: minimumQualifyingSets,
            plannedSets: plannedSets,
            restSeconds: restSeconds
        )
    }

    private static func station(
        _ id: String,
        title: String,
        category: TrialMovementCategory,
        movementId: String,
        displayName: String? = nil,
        metric: TrainingMetricKind,
        minimumValue: Int,
        minimumQualifyingSets: Int = 1,
        plannedSets: Int? = nil,
        restSeconds: Int? = nil,
        capSeconds: Int? = nil,
        loadPercentOfBodyweight: Double? = nil,
        movementOptions: [TrialMovementOption]? = nil,
        restRule: String? = nil
    ) -> TrialStation {
        let standard = performanceStandard(
            movementId,
            metric: metric,
            minimumValue: minimumValue,
            minimumQualifyingSets: minimumQualifyingSets,
            plannedSets: plannedSets,
            restSeconds: restSeconds,
            displayName: displayName
        )
        return TrialStation(
            id: id,
            title: title,
            category: category,
            standard: standard,
            capSeconds: capSeconds,
            loadPercentOfBodyweight: loadPercentOfBodyweight,
            movementOptions: movementOptions ?? [option(movementId, displayName)],
            restRule: restRule ?? "Clean reps only. Pain or form-break flags fail the station.",
            qualityFlags: [.clean]
        )
    }

    private static func variant(
        _ loadout: TrialLoadout,
        promise: String,
        stations: [TrialStation]
    ) -> TrialLoadoutVariant {
        TrialLoadoutVariant(
            loadout: loadout,
            requiredEquipment: [.bodyweight, .openSpace],
            promise: promise,
            stations: stations
        )
    }

    private static func definition(
        id: String,
        targetRank: RankTitle,
        displayName: String,
        subtitle: String,
        estimatedMinutes: Int,
        format: RankTrialFormat,
        minOverallLevel: Int,
        topAttributeCount: Int,
        topAttributeFloor: Double,
        movementStandards: [OverallRankTrialMovementStandard],
        loadoutVariants: [TrialLoadoutVariant],
        legacyIds: Set<String> = []
    ) -> OverallRankTrialDefinition {
        let defaultVariant = loadoutVariants.first { $0.loadout == .homeKit } ?? loadoutVariants[0]
        return OverallRankTrialDefinition(
            id: id,
            targetRank: targetRank,
            displayName: displayName,
            subtitle: subtitle,
            estimatedMinutes: estimatedMinutes,
            format: format,
            minOverallLevel: minOverallLevel,
            topAttributeCount: topAttributeCount,
            topAttributeFloor: topAttributeFloor,
            requiredEquipment: defaultVariant.requiredEquipment,
            movementStandards: movementStandards,
            skillStandards: [],
            performanceStandards: defaultVariant.stations.map(\.standard),
            loadoutVariants: loadoutVariants,
            legacyIds: legacyIds
        )
    }

    private static func loadoutVariants(
        noGym: [TrialStation],
        home: [TrialStation],
        gym: [TrialStation]
    ) -> [TrialLoadoutVariant] {
        [
            variant(
                .noGymField,
                promise: "Apartment and travel-safe official version with no commercial gym requirement.",
                stations: noGym
            ),
            variant(
                .homeKit,
                promise: "Home equipment version with stronger row, hinge, and carry options.",
                stations: home
            ),
            variant(
                .gymHybrid,
                promise: "Gym version with premium variety, never a mandatory sled or box-jump gate.",
                stations: gym
            )
        ]
    }

    private static func engineMovement(
        loadout: TrialLoadout,
        runMeters: Int
    ) -> (id: String, displayName: String, value: Int, equipment: Set<MovementEquipment>) {
        switch loadout {
        case .noGymField, .homeKit:
            return ("cardio.run", "\(runMeters)m run/walk", runMeters, [.openSpace])
        case .gymHybrid:
            return ("cardio.row", "\(Int(Double(runMeters) * 1.15))m row", Int(Double(runMeters) * 1.15), [.cardioMachine])
        }
    }

    private static func engineStation(
        _ id: String,
        title: String,
        loadout: TrialLoadout,
        runMeters: Int,
        minimumQualifyingSets: Int = 1,
        capSeconds: Int? = nil
    ) -> TrialStation {
        let movement = engineMovement(loadout: loadout, runMeters: runMeters)
        return station(
            id,
            title: title,
            category: .engine,
            movementId: movement.id,
            displayName: movement.displayName,
            metric: .distanceMeters,
            minimumValue: movement.value,
            minimumQualifyingSets: minimumQualifyingSets,
            plannedSets: minimumQualifyingSets,
            restSeconds: 45,
            capSeconds: capSeconds,
            movementOptions: [option(movement.id, movement.displayName, requiredEquipment: movement.equipment)]
        )
    }

    private static func movementSet(
        loadout: TrialLoadout,
        noGym: TrialMovementOption,
        home: [TrialMovementOption],
        gym: [TrialMovementOption]
    ) -> [TrialMovementOption] {
        switch loadout {
        case .noGymField: return [noGym]
        case .homeKit: return home
        case .gymHybrid: return gym
        }
    }

    private static func daily100Stations(loadout: TrialLoadout) -> [TrialStation] {
        [
            station(
                "daily-lower",
                title: "Lower Oath",
                category: .lower,
                movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.goblet-squat" : "exercise.bodyweight-squat",
                metric: .reps,
                minimumValue: 20,
                capSeconds: 14 * 60,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.bodyweight-squat"),
                    home: [option("exercise.goblet-squat", requiredEquipment: [.dumbbell]), option("exercise.bodyweight-squat")],
                    gym: [option("exercise.leg-press", requiredEquipment: [.machine]), option("exercise.goblet-squat", requiredEquipment: [.dumbbell])]
                )
            ),
            station(
                "daily-push",
                title: "Push Oath",
                category: .push,
                movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : loadout == .homeKit ? "exercise.pushup" : "exercise.incline-pushup",
                metric: .reps,
                minimumValue: 15,
                capSeconds: 14 * 60,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.incline-pushup"),
                    home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])],
                    gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.pushup")]
                )
            ),
            station(
                "daily-pull",
                title: "Posture Oath",
                category: .pull,
                movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row",
                metric: .reps,
                minimumValue: 20,
                capSeconds: 14 * 60,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.inverted-row"),
                    home: [
                        option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]),
                        option("exercise.band-row", requiredEquipment: [.band]),
                        option("exercise.inverted-row")
                    ],
                    gym: [
                        option("exercise.cable-row-seated", requiredEquipment: [.cable]),
                        option("exercise.machine-row", requiredEquipment: [.machine])
                    ]
                )
            ),
            station(
                "daily-engine",
                title: "Step Oath",
                category: .engine,
                movementId: "exercise.step-up",
                metric: .reps,
                minimumValue: 20,
                capSeconds: 14 * 60,
                movementOptions: [option("exercise.step-up")]
            ),
            station(
                "daily-trunk",
                title: "Trunk Oath",
                category: .carryCore,
                movementId: "exercise.plank",
                metric: .holdSeconds,
                minimumValue: 25,
                capSeconds: 14 * 60,
                movementOptions: [option("exercise.plank")]
            )
        ]
    }

    private static func operatorStations(loadout: TrialLoadout) -> [TrialStation] {
        [
            engineStation("operator-engine", title: "6-Minute Engine Floor", loadout: loadout, runMeters: 700, capSeconds: 6 * 60),
            station(
                "operator-lower",
                title: "2-Minute Lower Floor",
                category: .lower,
                movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.goblet-squat" : "exercise.step-up",
                metric: .reps,
                minimumValue: 30,
                capSeconds: 2 * 60,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.step-up"),
                    home: [option("exercise.goblet-squat", requiredEquipment: [.dumbbell]), option("exercise.step-up")],
                    gym: [option("exercise.leg-press", requiredEquipment: [.machine]), option("exercise.step-up")]
                )
            ),
            station(
                "operator-push",
                title: "2-Minute Push Floor",
                category: .push,
                movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : "exercise.pushup",
                metric: .reps,
                minimumValue: 18,
                capSeconds: 2 * 60,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.pushup"),
                    home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])],
                    gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.pushup")]
                )
            ),
            station(
                "operator-pull",
                title: "2-Minute Pull Floor",
                category: .pull,
                movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row",
                metric: .reps,
                minimumValue: 24,
                capSeconds: 2 * 60,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.inverted-row"),
                    home: [
                        option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]),
                        option("exercise.band-row", requiredEquipment: [.band]),
                        option("exercise.pullup", requiredEquipment: [.pullupBar])
                    ],
                    gym: [
                        option("exercise.cable-row-seated", requiredEquipment: [.cable]),
                        option("exercise.machine-row", requiredEquipment: [.machine]),
                        option("exercise.assisted-pullup-machine", requiredEquipment: [.machine])
                    ]
                )
            ),
            station(
                "operator-carry-core",
                title: "Carry / Core Floor",
                category: .carryCore,
                movementId: loadout == .noGymField ? "exercise.plank" : "carry.suitcase-carry",
                metric: loadout == .noGymField ? .holdSeconds : .distanceMeters,
                minimumValue: loadout == .noGymField ? 60 : 80,
                capSeconds: 3 * 60,
                loadPercentOfBodyweight: loadout == .noGymField ? nil : 0.20,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.plank"),
                    home: [
                        option("carry.suitcase-carry", requiredEquipment: [.dumbbell, .openSpace]),
                        option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])
                    ],
                    gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])]
                )
            )
        ]
    }

    private static func finisherStations(loadout: TrialLoadout) -> [TrialStation] {
        let reps = [21, 15, 9]
        return reps.enumerated().flatMap { index, count in
            let round = index + 1
            return [
                engineStation("finisher-r\(round)-engine", title: "Round \(round) Engine Buy-In", loadout: loadout, runMeters: 300),
                station(
                    "finisher-r\(round)-hinge",
                    title: "Round \(round) Hinge \(count)",
                    category: .hingePower,
                    movementId: loadout == .gymHybrid ? "exercise.cable-pull-through" : loadout == .homeKit ? "exercise.kettlebell-swing" : "exercise.glute-bridge",
                    metric: .reps,
                    minimumValue: count,
                    movementOptions: movementSet(
                        loadout: loadout,
                        noGym: option("exercise.glute-bridge"),
                        home: [option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]), option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])],
                        gym: [option("exercise.cable-pull-through", requiredEquipment: [.cable]), option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell])]
                    )
                ),
                station(
                    "finisher-r\(round)-push",
                    title: "Round \(round) Push \(count)",
                    category: .push,
                    movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : "exercise.pushup",
                    metric: .reps,
                    minimumValue: count,
                    movementOptions: movementSet(
                        loadout: loadout,
                        noGym: option("exercise.pushup"),
                        home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])],
                        gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.pushup")]
                    )
                ),
                station(
                    "finisher-r\(round)-pull",
                    title: "Round \(round) Pull \(max(3, count / 3))",
                    category: .pull,
                    movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row",
                    metric: .reps,
                    minimumValue: max(3, count / 3),
                    movementOptions: movementSet(
                        loadout: loadout,
                        noGym: option("exercise.inverted-row"),
                        home: [option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]), option("exercise.band-row", requiredEquipment: [.band])],
                        gym: [option("exercise.cable-row-seated", requiredEquipment: [.cable]), option("exercise.machine-row", requiredEquipment: [.machine])]
                    )
                ),
                station(
                    "finisher-r\(round)-carry",
                    title: "Round \(round) Carry",
                    category: .carryCore,
                    movementId: loadout == .noGymField ? "carry.loaded-march" : "carry.suitcase-carry",
                    metric: .distanceMeters,
                    minimumValue: 40,
                    movementOptions: movementSet(
                        loadout: loadout,
                        noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]),
                        home: [option("carry.suitcase-carry", requiredEquipment: [.dumbbell, .openSpace]), option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])],
                        gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])]
                    )
                )
            ]
        }
    }

    private static func deckStations(loadout: TrialLoadout) -> [TrialStation] {
        let categories: [TrialMovementCategory] = [
            .push, .lower, .pull, .engine, .push, .lower,
            .pull, .carryCore, .push, .lower, .pull, .engine,
            .push, .lower, .pull, .engine, .push, .lower,
            .pull, .carryCore, .push, .lower, .pull, .engine
        ]
        return categories.enumerated().map { index, category in
            let card = String(format: "%02d", index + 1)
            switch category {
            case .push:
                return station(
                    "deck-card-\(card)",
                    title: "Card \(card) Push",
                    category: .push,
                    movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : "exercise.pushup",
                    metric: .reps,
                    minimumValue: 10,
                    movementOptions: movementSet(
                        loadout: loadout,
                        noGym: option("exercise.pushup"),
                        home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])],
                        gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.pushup")]
                    )
                )
            case .lower:
                return station(
                    "deck-card-\(card)",
                    title: "Card \(card) Lower",
                    category: .lower,
                    movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.goblet-squat" : "exercise.step-up",
                    metric: .reps,
                    minimumValue: 12,
                    movementOptions: movementSet(
                        loadout: loadout,
                        noGym: option("exercise.step-up"),
                        home: [option("exercise.goblet-squat", requiredEquipment: [.dumbbell]), option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell])],
                        gym: [option("exercise.leg-press", requiredEquipment: [.machine]), option("exercise.goblet-squat", requiredEquipment: [.dumbbell])]
                    )
                )
            case .pull:
                return station(
                    "deck-card-\(card)",
                    title: "Card \(card) Pull",
                    category: .pull,
                    movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row",
                    metric: .reps,
                    minimumValue: 10,
                    movementOptions: movementSet(
                        loadout: loadout,
                        noGym: option("exercise.inverted-row"),
                        home: [option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]), option("exercise.band-row", requiredEquipment: [.band])],
                        gym: [option("exercise.cable-row-seated", requiredEquipment: [.cable]), option("exercise.machine-row", requiredEquipment: [.machine])]
                    )
                )
            case .engine:
                return engineStation("deck-card-\(card)", title: "Card \(card) Engine", loadout: loadout, runMeters: 200)
            case .carryCore:
                return station(
                    "deck-card-\(card)",
                    title: "Card \(card) Carry / Core",
                    category: .carryCore,
                    movementId: loadout == .noGymField ? "exercise.plank" : "carry.suitcase-carry",
                    metric: loadout == .noGymField ? .holdSeconds : .distanceMeters,
                    minimumValue: loadout == .noGymField ? 30 : 60,
                    loadPercentOfBodyweight: loadout == .noGymField ? nil : 0.20,
                    movementOptions: movementSet(
                        loadout: loadout,
                        noGym: option("exercise.plank"),
                        home: [option("carry.suitcase-carry", requiredEquipment: [.dumbbell, .openSpace]), option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])],
                        gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])]
                    )
                )
            case .hingePower, .explosive, .mobilityControl:
                return station(
                    "deck-card-\(card)",
                    title: "Card \(card) Control",
                    category: .mobilityControl,
                    movementId: "exercise.plank",
                    metric: .holdSeconds,
                    minimumValue: 30
                )
            }
        }
    }

    private static func towerStations(loadout: TrialLoadout) -> [TrialStation] {
        [
            engineStation("tower-floor-01", title: "Floor 1 Engine", loadout: loadout, runMeters: 300),
            station("tower-floor-02", title: "Floor 2 Lower", category: .lower, movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.dumbbell-step-up" : "exercise.step-up", metric: .reps, minimumValue: 24, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.step-up"), home: [option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell]), option("exercise.goblet-squat", requiredEquipment: [.dumbbell])], gym: [option("exercise.leg-press", requiredEquipment: [.machine]), option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell])])),
            station("tower-floor-03", title: "Floor 3 Push", category: .push, movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : loadout == .homeKit ? "exercise.dumbbell-bench-press" : "exercise.pushup", metric: .reps, minimumValue: 20, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.pushup"), home: [option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell]), option("exercise.pushup")], gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])])),
            station("tower-floor-04", title: "Floor 4 Pull", category: .pull, movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row", metric: .reps, minimumValue: 20, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.inverted-row"), home: [option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]), option("exercise.band-row", requiredEquipment: [.band])], gym: [option("exercise.cable-row-seated", requiredEquipment: [.cable]), option("exercise.machine-row", requiredEquipment: [.machine])])),
            station("tower-floor-05", title: "Floor 5 Hinge / Power", category: .hingePower, movementId: loadout == .gymHybrid ? "exercise.cable-pull-through" : loadout == .homeKit ? "exercise.dumbbell-romanian-deadlift" : "exercise.glute-bridge", metric: .reps, minimumValue: 30, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.glute-bridge"), home: [option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell]), option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell])], gym: [option("exercise.cable-pull-through", requiredEquipment: [.cable]), option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])])),
            station("tower-floor-06", title: "Floor 6 Carry", category: .carryCore, movementId: loadout == .noGymField ? "carry.loaded-march" : "carry.farmer-carry", metric: .distanceMeters, minimumValue: 100, loadPercentOfBodyweight: loadout == .noGymField ? 0.10 : 0.25, movementOptions: movementSet(loadout: loadout, noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]), home: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace]), option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])], gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])])),
            engineStation("tower-floor-07", title: "Floor 7 Long Engine", loadout: loadout, runMeters: 500),
            station("tower-floor-08", title: "Floor 8 Explosive", category: .explosive, movementId: loadout == .gymHybrid ? "exercise.kettlebell-swing" : loadout == .homeKit ? "exercise.kettlebell-swing" : "exercise.step-up", metric: .reps, minimumValue: 20, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.step-up"), home: [option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]), option("exercise.step-up")], gym: [option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]), option("exercise.step-up")])),
            station("tower-floor-09-push", title: "Floor 9 Push Blend", category: .push, movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : "exercise.pushup", metric: .reps, minimumValue: 15, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.pushup"), home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])], gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])])),
            station("tower-floor-09-pull", title: "Floor 9 Pull Blend", category: .pull, movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row", metric: .reps, minimumValue: 15, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.inverted-row"), home: [option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]), option("exercise.band-row", requiredEquipment: [.band])], gym: [option("exercise.cable-row-seated", requiredEquipment: [.cable]), option("exercise.machine-row", requiredEquipment: [.machine])])),
            station("tower-floor-10", title: "Floor 10 Boss Hold", category: .carryCore, movementId: "exercise.plank", metric: .holdSeconds, minimumValue: 90, capSeconds: 5 * 60, movementOptions: [option("exercise.plank")])
        ]
    }

    private static func bossRushStations(loadout: TrialLoadout) -> [TrialStation] {
        [
            engineStation("boss-engine", title: "Engine Boss", loadout: loadout, runMeters: 800, capSeconds: 6 * 60),
            station("boss-lower", title: "Lower Boss", category: .lower, movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.dumbbell-step-up" : "exercise.step-up", metric: .reps, minimumValue: 48, capSeconds: 6 * 60, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.step-up"), home: [option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell]), option("exercise.goblet-squat", requiredEquipment: [.dumbbell])], gym: [option("exercise.leg-press", requiredEquipment: [.machine]), option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell])])),
            station("boss-power", title: "Power Boss", category: .hingePower, movementId: loadout == .gymHybrid ? "exercise.cable-pull-through" : loadout == .homeKit ? "exercise.kettlebell-swing" : "exercise.glute-bridge", metric: .reps, minimumValue: 40, capSeconds: 6 * 60, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.glute-bridge"), home: [option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]), option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])], gym: [option("exercise.cable-pull-through", requiredEquipment: [.cable]), option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell])])),
            station("boss-upper-push", title: "Upper Boss Push", category: .push, movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : "exercise.pushup", metric: .reps, minimumValue: 16, capSeconds: 6 * 60, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.pushup"), home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])], gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])])),
            station("boss-upper-pull", title: "Upper Boss Pull", category: .pull, movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row", metric: .reps, minimumValue: 16, capSeconds: 6 * 60, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.inverted-row"), home: [option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]), option("exercise.band-row", requiredEquipment: [.band])], gym: [option("exercise.cable-row-seated", requiredEquipment: [.cable]), option("exercise.machine-row", requiredEquipment: [.machine])])),
            station("boss-control", title: "Control Boss", category: .mobilityControl, movementId: "exercise.plank", metric: .holdSeconds, minimumValue: 60, minimumQualifyingSets: 2, plannedSets: 2, capSeconds: 6 * 60, movementOptions: [option("exercise.plank")]),
            station("boss-carry", title: "Carry Boss", category: .carryCore, movementId: loadout == .noGymField ? "carry.loaded-march" : "carry.farmer-carry", metric: .distanceMeters, minimumValue: 200, capSeconds: 6 * 60, loadPercentOfBodyweight: loadout == .noGymField ? 0.15 : 0.30, movementOptions: movementSet(loadout: loadout, noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]), home: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace]), option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])], gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])]))
        ]
    }

    private static func raidStations(loadout: TrialLoadout) -> [TrialStation] {
        [
            engineStation("raid-stage-1", title: "Stage 1 Engine Repeats", loadout: loadout, runMeters: 400, minimumQualifyingSets: 3, capSeconds: 18 * 60),
            station("raid-stage-2-hinge", title: "Stage 2 Hinge Raid", category: .hingePower, movementId: loadout == .gymHybrid ? "exercise.cable-pull-through" : loadout == .homeKit ? "exercise.dumbbell-romanian-deadlift" : "exercise.glute-bridge", metric: .reps, minimumValue: 10, minimumQualifyingSets: 4, plannedSets: 4, capSeconds: 32 * 60, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.glute-bridge"), home: [option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell]), option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell])], gym: [option("exercise.cable-pull-through", requiredEquipment: [.cable]), option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])])),
            station("raid-stage-2-upper", title: "Stage 2 Press / Row Raid", category: .pull, movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row", metric: .reps, minimumValue: 10, minimumQualifyingSets: 4, plannedSets: 4, capSeconds: 32 * 60, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.inverted-row"), home: [option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]), option("exercise.band-row", requiredEquipment: [.band])], gym: [option("exercise.cable-row-seated", requiredEquipment: [.cable]), option("exercise.machine-row", requiredEquipment: [.machine])])),
            station("raid-stage-2-carry", title: "Stage 2 Carry Raid", category: .carryCore, movementId: loadout == .noGymField ? "carry.loaded-march" : "carry.farmer-carry", metric: .distanceMeters, minimumValue: 60, minimumQualifyingSets: 4, plannedSets: 4, capSeconds: 32 * 60, loadPercentOfBodyweight: loadout == .noGymField ? 0.15 : 0.30, movementOptions: movementSet(loadout: loadout, noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]), home: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace]), option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])], gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])])),
            station("raid-stage-3-control", title: "Stage 3 Recovery-Control Hold", category: .mobilityControl, movementId: "exercise.plank", metric: .holdSeconds, minimumValue: 120, minimumQualifyingSets: 1, plannedSets: 1, capSeconds: 15 * 60, movementOptions: [option("exercise.plank")])
        ]
    }

    private static func finalExamStations(loadout: TrialLoadout) -> [TrialStation] {
        [
            station("exam-part-a-explosive", title: "Part A Explosive Control", category: .explosive, movementId: loadout == .gymHybrid ? "exercise.kettlebell-swing" : loadout == .homeKit ? "exercise.kettlebell-swing" : "exercise.step-up", metric: .reps, minimumValue: 30, capSeconds: 8 * 60, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.step-up"), home: [option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]), option("exercise.step-up")], gym: [option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]), option("exercise.step-up")])),
            engineStation("exam-part-b-engine", title: "Part B Capacity", loadout: loadout, runMeters: 1200, capSeconds: 12 * 60),
            station("exam-part-c-pull", title: "Part C Pull Volume", category: .pull, movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row", metric: .reps, minimumValue: 60, capSeconds: 30 * 60, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.inverted-row"), home: [option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]), option("exercise.band-row", requiredEquipment: [.band])], gym: [option("exercise.cable-row-seated", requiredEquipment: [.cable]), option("exercise.machine-row", requiredEquipment: [.machine])])),
            station("exam-part-c-push", title: "Part C Push Volume", category: .push, movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : "exercise.pushup", metric: .reps, minimumValue: 60, capSeconds: 30 * 60, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.pushup"), home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])], gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.pushup")])),
            station("exam-part-c-lower", title: "Part C Lower Volume", category: .lower, movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.goblet-squat" : "exercise.step-up", metric: .reps, minimumValue: 80, capSeconds: 30 * 60, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.step-up"), home: [option("exercise.goblet-squat", requiredEquipment: [.dumbbell]), option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell])], gym: [option("exercise.leg-press", requiredEquipment: [.machine]), option("exercise.goblet-squat", requiredEquipment: [.dumbbell])])),
            station("exam-part-c-carry", title: "Part C Carry Finish", category: .carryCore, movementId: loadout == .noGymField ? "carry.loaded-march" : "carry.farmer-carry", metric: .distanceMeters, minimumValue: 240, capSeconds: 30 * 60, loadPercentOfBodyweight: loadout == .noGymField ? 0.20 : 0.35, movementOptions: movementSet(loadout: loadout, noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]), home: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace]), option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])], gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])])),
            station("exam-part-c-trunk", title: "Part C Trunk Finish", category: .mobilityControl, movementId: "exercise.plank", metric: .holdSeconds, minimumValue: 120, capSeconds: 30 * 60, movementOptions: [option("exercise.plank")])
        ]
    }

    static let foundationProof = OverallRankTrialDefinition(
        id: "overall-rank-trial-novice-awakening",
        targetRank: .novice,
        displayName: "Daily 100",
        subtitle: "Initiate to Novice rank gate",
        estimatedMinutes: 14,
        format: .daily100,
        minOverallLevel: 1,
        topAttributeCount: 2,
        topAttributeFloor: 20,
        requiredEquipment: [.bodyweight],
        movementStandards: [
            OverallRankTrialMovementStandard(
                rankStandardMovementId: "exercise.pushup",
                displayName: "Push-Up",
                minimumAP: 50
            ),
            OverallRankTrialMovementStandard(
                rankStandardMovementId: "exercise.bodyweight-squat",
                displayName: "Bodyweight Squat",
                minimumAP: 30
            )
        ],
        skillStandards: [],
        performanceStandards: daily100Stations(loadout: .homeKit).map(\.standard),
        loadoutVariants: loadoutVariants(
            noGym: daily100Stations(loadout: .noGymField),
            home: daily100Stations(loadout: .homeKit),
            gym: daily100Stations(loadout: .gymHybrid)
        ),
        legacyIds: ["overall-rank-trial-novice-foundation-proof"]
    )

    static let calibration = definition(
        id: "overall-rank-trial-apprentice-calibration",
        targetRank: .apprentice,
        displayName: "Operator Screen",
        subtitle: "Novice to Apprentice rank gate",
        estimatedMinutes: 20,
        format: .operatorScreen,
        minOverallLevel: 8,
        topAttributeCount: 0,
        topAttributeFloor: 0,
        movementStandards: [
            movementStandard("exercise.pushup", minimumAP: 90, displayName: "Push-Up"),
            movementStandard("exercise.inverted-row", minimumAP: 60)
        ],
        loadoutVariants: loadoutVariants(
            noGym: operatorStations(loadout: .noGymField),
            home: operatorStations(loadout: .homeKit),
            gym: operatorStations(loadout: .gymHybrid)
        )
    )

    static let forge = definition(
        id: "overall-rank-trial-forged-forge",
        targetRank: .forged,
        displayName: "The Finisher",
        subtitle: "Apprentice to Forged rank gate",
        estimatedMinutes: 30,
        format: .finisher,
        minOverallLevel: 15,
        topAttributeCount: 1,
        topAttributeFloor: 58,
        movementStandards: [
            movementStandard("exercise.pushup", minimumAP: 120, displayName: "Push-Up"),
            movementStandard("exercise.inverted-row", minimumAP: 100),
            movementStandard("exercise.dumbbell-romanian-deadlift", minimumAP: 120)
        ],
        loadoutVariants: loadoutVariants(
            noGym: finisherStations(loadout: .noGymField),
            home: finisherStations(loadout: .homeKit),
            gym: finisherStations(loadout: .gymHybrid)
        ),
        legacyIds: ["overall-rank-trial-honed-forge", "overall-rank-trial-master-forge"]
    )

    static let reckoning = definition(
        id: "overall-rank-trial-veteran-reckoning",
        targetRank: .veteran,
        displayName: "Deck of Proof",
        subtitle: "Forged to Veteran rank gate",
        estimatedMinutes: 42,
        format: .fixedDeck,
        minOverallLevel: 22,
        topAttributeCount: 2,
        topAttributeFloor: 68,
        movementStandards: [
            movementStandard("exercise.step-up", minimumAP: 160),
            movementStandard("exercise.inverted-row", minimumAP: 160),
            movementStandard("carry.loaded-march", minimumAP: 160, displayName: "Loaded March")
        ],
        loadoutVariants: loadoutVariants(
            noGym: deckStations(loadout: .noGymField),
            home: deckStations(loadout: .homeKit),
            gym: deckStations(loadout: .gymHybrid)
        ),
        legacyIds: ["overall-rank-trial-forged-reckoning"]
    )

    static let gauntlet = definition(
        id: "overall-rank-trial-master-gauntlet",
        targetRank: .master,
        displayName: "The Tower",
        subtitle: "Veteran to Master rank gate",
        estimatedMinutes: 50,
        format: .tower,
        minOverallLevel: 40,
        topAttributeCount: 3,
        topAttributeFloor: 78,
        movementStandards: [
            movementStandard("cardio.run", minimumAP: 240, displayName: "Run"),
            movementStandard("exercise.dumbbell-row", minimumAP: 220),
            movementStandard("carry.loaded-march", minimumAP: 220, displayName: "Loaded March")
        ],
        loadoutVariants: loadoutVariants(
            noGym: towerStations(loadout: .noGymField),
            home: towerStations(loadout: .homeKit),
            gym: towerStations(loadout: .gymHybrid)
        ),
        legacyIds: ["overall-rank-trial-veteran-gauntlet"]
    )

    static let crucible = definition(
        id: "overall-rank-trial-vessel-ten-hundred",
        targetRank: .vessel,
        displayName: "Boss Rush",
        subtitle: "Master to Vessel rank gate",
        estimatedMinutes: 58,
        format: .bossRush,
        minOverallLevel: 55,
        topAttributeCount: 4,
        topAttributeFloor: 84,
        movementStandards: [
            movementStandard("cardio.run", minimumAP: 320, displayName: "Run"),
            movementStandard("exercise.dumbbell-romanian-deadlift", minimumAP: 300),
            movementStandard("exercise.dumbbell-row", minimumAP: 280),
            movementStandard("carry.farmer-carry", minimumAP: 280)
        ],
        loadoutVariants: loadoutVariants(
            noGym: bossRushStations(loadout: .noGymField),
            home: bossRushStations(loadout: .homeKit),
            gym: bossRushStations(loadout: .gymHybrid)
        ),
        legacyIds: ["overall-rank-trial-vessel-crucible"]
    )

    static let threshold = definition(
        id: "overall-rank-trial-unbound-threshold",
        targetRank: .unbound,
        displayName: "Threshold Raid",
        subtitle: "Vessel to Unbound rank gate",
        estimatedMinutes: 65,
        format: .raid,
        minOverallLevel: 72,
        topAttributeCount: 5,
        topAttributeFloor: 90,
        movementStandards: [
            movementStandard("cardio.run", minimumAP: 420, displayName: "Run"),
            movementStandard("exercise.dumbbell-romanian-deadlift", minimumAP: 360),
            movementStandard("exercise.dumbbell-row", minimumAP: 340),
            movementStandard("carry.farmer-carry", minimumAP: 340)
        ],
        loadoutVariants: loadoutVariants(
            noGym: raidStations(loadout: .noGymField),
            home: raidStations(loadout: .homeKit),
            gym: raidStations(loadout: .gymHybrid)
        )
    )

    static let ascension = definition(
        id: "overall-rank-trial-ascendant-ascension",
        targetRank: .ascendant,
        displayName: "Final Exam",
        subtitle: "Unbound to Ascendant rank gate",
        estimatedMinutes: 75,
        format: .finalExam,
        minOverallLevel: 90,
        topAttributeCount: 6,
        topAttributeFloor: 95,
        movementStandards: [
            movementStandard("cardio.run", minimumAP: 500, displayName: "Run"),
            movementStandard("exercise.dumbbell-row", minimumAP: 440),
            movementStandard("exercise.pushup", minimumAP: 400, displayName: "Push-Up"),
            movementStandard("carry.farmer-carry", minimumAP: 420)
        ],
        loadoutVariants: loadoutVariants(
            noGym: finalExamStations(loadout: .noGymField),
            home: finalExamStations(loadout: .homeKit),
            gym: finalExamStations(loadout: .gymHybrid)
        )
    )

    static let all: [OverallRankTrialDefinition] = [
        foundationProof,
        calibration,
        forge,
        reckoning,
        gauntlet,
        crucible,
        threshold,
        ascension
    ]

    static func definition(id: String) -> OverallRankTrialDefinition? {
        if let definition = all.first(where: { $0.id == id || $0.legacyIds.contains(id) }) {
            return definition
        }
        return nil
    }

    static func nextTrial(after rank: RankTitle) -> OverallRankTrialDefinition? {
        switch rank {
        case .initiate:
            return foundationProof
        case .novice:
            return calibration
        case .apprentice:
            return forge
        case .forged:
            return reckoning
        case .veteran:
            return gauntlet
        case .master:
            return crucible
        case .vessel:
            return threshold
        case .unbound:
            return ascension
        default:
            return nil
        }
    }
}

private extension RankTitle {
    var overallRankTrialOrder: Int {
        switch self {
        case .initiate: return 0
        case .novice: return 1
        case .apprentice: return 2
        case .forged: return 3
        case .veteran: return 4
        case .master: return 5
        case .vessel: return 6
        case .unbound: return 7
        case .ascendant: return 8
        }
    }
}

final class RankTrialLoadoutResolver {
    static let shared = RankTrialLoadoutResolver()

    private init() {}

    func resolve(
        definition: OverallRankTrialDefinition,
        userId: String,
        equipment rawEquipment: Set<MovementEquipment>,
        generatedAt: Date = Date()
    ) -> RankTrialResolution {
        let equipment = normalizedEquipment(rawEquipment)
        let variants = definition.loadoutVariants.isEmpty
            ? [fallbackVariant(for: definition)]
            : definition.loadoutVariants
        let preferred = preferredLoadouts(for: equipment)
        let preferredVariants = preferred.compactMap { loadout in variants.first { $0.loadout == loadout } }
        let exactVariant = preferredVariants.first { variant in
            variant.requiredEquipment.isSubset(of: equipment) && stationEquipmentGaps(for: variant, equipment: equipment).isEmpty
        }
        let chosenVariant = exactVariant
            ?? preferredVariants.first { $0.requiredEquipment.isSubset(of: equipment) }
            ?? variants.first

        guard let chosenVariant else {
            return RankTrialResolution(
                definition: definition,
                resolvedTrial: nil,
                blockers: [
                    RankTrialResolutionBlocker(
                        id: "no-loadout",
                        title: "No official loadout",
                        message: "This rank gate needs an official protocol before it can start.",
                        missingEquipment: []
                    )
                ]
            )
        }

        var blockers: [RankTrialResolutionBlocker] = []
        let missingLoadoutEquipment = chosenVariant.requiredEquipment.subtracting(equipment)
        if !missingLoadoutEquipment.isEmpty {
            blockers.append(
                RankTrialResolutionBlocker(
                    id: "loadout-equipment",
                    title: "Missing loadout gear",
                    message: missingLoadoutEquipment.map(\.displayName).sorted().joined(separator: ", "),
                    missingEquipment: missingLoadoutEquipment
                )
            )
        }

        if requiresPullSolution(definition), !hasPullSolution(equipment) {
            blockers.append(
                RankTrialResolutionBlocker(
                    id: "pull-solution",
                    title: "Pull station blocked",
                    message: "Add a safe row or pull option before this gate can clear Overall Rank.",
                    missingEquipment: [.pullupBar, .band, .dumbbell, .cable, .machine, .rings]
                )
            )
        }

        var resolvedStations: [ResolvedTrialStation] = []
        var missingResolvedStationEquipment: Set<MovementEquipment> = []

        for station in chosenVariant.stations {
            let selected = station.movementOptions.first { option in
                option.requiredEquipment.isSubset(of: equipment)
            } ?? station.primaryMovement
            missingResolvedStationEquipment.formUnion(selected.requiredEquipment.subtracting(equipment))
            resolvedStations.append(
                ResolvedTrialStation(
                    id: station.id,
                    station: station,
                    selectedMovement: selected
                )
            )
        }

        if !missingResolvedStationEquipment.isEmpty {
            blockers.append(
                RankTrialResolutionBlocker(
                    id: "station-equipment",
                    title: "Missing station gear",
                    message: missingResolvedStationEquipment.map(\.displayName).sorted().joined(separator: ", "),
                    missingEquipment: missingResolvedStationEquipment
                )
            )
        }

        let resolvedTrial = ResolvedRankTrial(
            id: "\(definition.id):\(chosenVariant.loadout.rawValue):v1",
            definitionId: definition.id,
            userId: userId,
            selectedLoadout: chosenVariant.loadout,
            stations: resolvedStations,
            generatedAt: generatedAt,
            version: 1
        )

        return RankTrialResolution(
            definition: definition,
            resolvedTrial: resolvedTrial,
            blockers: blockers
        )
    }

    private func normalizedEquipment(_ equipment: Set<MovementEquipment>) -> Set<MovementEquipment> {
        var normalized = equipment
        normalized.insert(.bodyweight)
        normalized.insert(.openSpace)
        if normalized.contains(.machine) || normalized.contains(.cable) || normalized.contains(.cardioMachine) {
            normalized.formUnion([.machine, .cable, .cardioMachine])
        }
        return normalized
    }

    private func preferredLoadouts(for equipment: Set<MovementEquipment>) -> [TrialLoadout] {
        if equipment.contains(.machine) || equipment.contains(.cable) || equipment.contains(.cardioMachine) || equipment.contains(.barbell) {
            return [.gymHybrid, .homeKit, .noGymField]
        }
        if equipment.contains(.dumbbell) || equipment.contains(.kettlebell) || equipment.contains(.band) || equipment.contains(.pullupBar) {
            return [.homeKit, .noGymField, .gymHybrid]
        }
        return [.noGymField, .homeKit, .gymHybrid]
    }

    private func stationEquipmentGaps(
        for variant: TrialLoadoutVariant,
        equipment: Set<MovementEquipment>
    ) -> Set<MovementEquipment> {
        variant.stations.reduce(into: Set<MovementEquipment>()) { result, station in
            if station.movementOptions.contains(where: { $0.requiredEquipment.isSubset(of: equipment) }) {
                return
            }
            result.formUnion(station.primaryMovement.requiredEquipment.subtracting(equipment))
        }
    }

    private func requiresPullSolution(_ definition: OverallRankTrialDefinition) -> Bool {
        definition.targetRank.overallRankTrialOrder >= RankTitle.apprentice.overallRankTrialOrder
    }

    private func hasPullSolution(_ equipment: Set<MovementEquipment>) -> Bool {
        !equipment.intersection([.pullupBar, .band, .dumbbell, .kettlebell, .cable, .machine, .rings]).isEmpty
    }

    private func fallbackVariant(for definition: OverallRankTrialDefinition) -> TrialLoadoutVariant {
        TrialLoadoutVariant(
            loadout: .homeKit,
            requiredEquipment: definition.requiredEquipment,
            promise: "Legacy rank gate compatibility.",
            stations: definition.performanceStandards.enumerated().map { index, standard in
                TrialStation(
                    id: "legacy-\(index + 1)",
                    title: standard.displayName,
                    category: category(for: standard),
                    standard: standard,
                    capSeconds: nil,
                    loadPercentOfBodyweight: nil,
                    movementOptions: [TrialMovementOption(movementId: standard.movementId, displayName: standard.displayName)],
                    restRule: "Rest \(standard.restSeconds)s.",
                    qualityFlags: [.clean]
                )
            }
        )
    }

    private func category(for standard: OverallRankTrialPerformanceStandard) -> TrialMovementCategory {
        switch standard.blockKind {
        case .cardio:
            return .engine
        case .carry:
            return .carryCore
        case .skill:
            return .mobilityControl
        case .bodyweight:
            if standard.movementId.contains("pull") || standard.movementId.contains("row") {
                return .pull
            }
            if standard.movementId.contains("squat") || standard.movementId.contains("lunge") || standard.movementId.contains("step") {
                return .lower
            }
            return .push
        case .strength:
            if standard.movementId.contains("row") || standard.movementId.contains("pulldown") {
                return .pull
            }
            if standard.movementId.contains("deadlift") || standard.movementId.contains("swing") || standard.movementId.contains("hinge") {
                return .hingePower
            }
            return .lower
        case .routine, .custom:
            return .mobilityControl
        }
    }
}

struct OverallRankTrialProgress: Codable, Equatable, Sendable {
    var highestPassedRank: RankTitle
    var attempts: [OverallRankTrialAttempt]

    static let empty = OverallRankTrialProgress(highestPassedRank: .initiate, attempts: [])

    var currentRank: RankTitle { highestPassedRank }

    func latestAttempt(definitionId: String) -> OverallRankTrialAttempt? {
        attempts
            .filter { $0.definitionId == definitionId }
            .sorted { $0.completedAt > $1.completedAt }
            .first
    }
}

struct OverallRankTrialAttempt: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let userId: String
    let definitionId: String
    let targetRank: RankTitle
    let startedAt: Date
    let completedAt: Date
    let performanceLogId: String
    let passed: Bool
    let movementAPGained: Double
    let overallLevelXPGained: Double
    let resolvedTrialId: String?
    let loadout: TrialLoadout?
    let evaluation: OverallRankTrialEvaluation?

    init(
        id: String,
        userId: String,
        definitionId: String,
        targetRank: RankTitle,
        startedAt: Date,
        completedAt: Date,
        performanceLogId: String,
        passed: Bool,
        movementAPGained: Double,
        overallLevelXPGained: Double,
        resolvedTrialId: String? = nil,
        loadout: TrialLoadout? = nil,
        evaluation: OverallRankTrialEvaluation? = nil
    ) {
        self.id = id
        self.userId = userId
        self.definitionId = definitionId
        self.targetRank = targetRank
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.performanceLogId = performanceLogId
        self.passed = passed
        self.movementAPGained = movementAPGained
        self.overallLevelXPGained = overallLevelXPGained
        self.resolvedTrialId = resolvedTrialId
        self.loadout = loadout
        self.evaluation = evaluation
    }
}

final class OverallRankTrialStore {
    static let shared = OverallRankTrialStore()

    private let defaults: UserDefaults
    private let keyPrefix = "unbound.overallRankTrials."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(userId: String) -> OverallRankTrialProgress {
        guard let data = defaults.data(forKey: keyPrefix + userId),
              let progress = try? JSONDecoder().decode(OverallRankTrialProgress.self, from: data)
        else {
            return .empty
        }
        return progress
    }

    func save(_ progress: OverallRankTrialProgress, userId: String) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: keyPrefix + userId)
    }

    func record(_ attempt: OverallRankTrialAttempt, userId: String) -> OverallRankTrialRecordResult {
        var progress = load(userId: userId)
        if let existing = progress.attempts.first(where: { $0.id == attempt.id || $0.performanceLogId == attempt.performanceLogId }) {
            return OverallRankTrialRecordResult(
                progress: progress,
                attempt: existing,
                didAdvanceRank: false,
                wasDuplicate: true
            )
        }

        let previousRank = progress.highestPassedRank
        progress.attempts.append(attempt)
        progress.attempts = Array(progress.attempts.suffix(50))

        var didAdvanceRank = false
        if attempt.passed, attempt.targetRank.overallRankTrialOrder > progress.highestPassedRank.overallRankTrialOrder {
            progress.highestPassedRank = attempt.targetRank
            didAdvanceRank = progress.highestPassedRank.overallRankTrialOrder > previousRank.overallRankTrialOrder
        }

        save(progress, userId: userId)
        return OverallRankTrialRecordResult(
            progress: progress,
            attempt: attempt,
            didAdvanceRank: didAdvanceRank,
            wasDuplicate: false
        )
    }
}

struct OverallRankTrialRecordResult: Equatable, Sendable {
    let progress: OverallRankTrialProgress
    let attempt: OverallRankTrialAttempt
    let didAdvanceRank: Bool
    let wasDuplicate: Bool
}

enum OverallRankTrialRunCalloutKind: String, Codable, Equatable, Sendable {
    case duplicateAttempt
    case comebackPass
}

struct OverallRankTrialRunCallout: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let kind: OverallRankTrialRunCalloutKind
    let title: String
    let message: String

    init(kind: OverallRankTrialRunCalloutKind, title: String, message: String) {
        self.id = kind.rawValue
        self.kind = kind
        self.title = title
        self.message = message
    }
}

struct OverallRankTrialReadinessInput: Equatable, Sendable {
    let userId: String
    let currentRank: RankTitle
    let overallLevel: Int
    let movementProgress: [String: MovementProgressState]
    let skillTiers: [String: SkillTier]
    let attributeProfile: AttributeProfile
    let equipment: Set<MovementEquipment>
    let attempts: [OverallRankTrialAttempt]

    init(
        userId: String,
        currentRank: RankTitle,
        overallLevel: Int,
        movementProgress: [String: MovementProgressState],
        skillTiers: [String: SkillTier],
        attributeProfile: AttributeProfile,
        equipment: Set<MovementEquipment> = [.bodyweight],
        attempts: [OverallRankTrialAttempt] = []
    ) {
        self.userId = userId
        self.currentRank = currentRank
        self.overallLevel = overallLevel
        self.movementProgress = movementProgress
        self.skillTiers = skillTiers
        self.attributeProfile = attributeProfile
        self.equipment = equipment
        self.attempts = attempts
    }
}

struct OverallRankTrialReadiness: Equatable, Sendable {
    let status: OverallRankTrialStatus
    let currentRank: RankTitle
    let targetRank: RankTitle?
    let definition: OverallRankTrialDefinition?
    let resolvedTrial: ResolvedRankTrial?
    let blockerSummary: String?
    let requirements: [OverallRankTrialRequirementLine]
    let latestAttempt: OverallRankTrialAttempt?

    var missingRequirements: [OverallRankTrialRequirementLine] {
        requirements.filter { !$0.isMet }
    }

    var isReady: Bool {
        status == .ready || status == .failed
    }
}

@MainActor
final class TrialReadinessService {
    static let shared = TrialReadinessService()

    private init() {}

    func evaluate(_ input: OverallRankTrialReadinessInput) -> OverallRankTrialReadiness {
        guard let definition = OverallRankTrialDefinitions.nextTrial(after: input.currentRank) else {
            return OverallRankTrialReadiness(
                status: .passed,
                currentRank: input.currentRank,
                targetRank: nil,
                definition: nil,
                resolvedTrial: nil,
                blockerSummary: nil,
                requirements: [],
                latestAttempt: input.attempts.sorted { $0.completedAt > $1.completedAt }.first
            )
        }

        let resolution = RankTrialLoadoutResolver.shared.resolve(
            definition: definition,
            userId: input.userId,
            equipment: input.equipment
        )
        let requirements = requirementLines(for: definition, resolution: resolution, input: input)
        let latestAttempt = input.attempts
            .filter { $0.definitionId == definition.id }
            .sorted { $0.completedAt > $1.completedAt }
            .first
        let allMet = requirements.allSatisfy(\.isMet)

        let status: OverallRankTrialStatus
        if latestAttempt?.passed == true {
            status = .passed
        } else if latestAttempt != nil, allMet {
            status = .failed
        } else if latestAttempt != nil {
            status = .attempted
        } else if allMet {
            status = .ready
        } else {
            status = .locked
        }

        return OverallRankTrialReadiness(
            status: status,
            currentRank: input.currentRank,
            targetRank: definition.targetRank,
            definition: definition,
            resolvedTrial: resolution.resolvedTrial,
            blockerSummary: resolution.blockerSummary,
            requirements: requirements,
            latestAttempt: latestAttempt
        )
    }

    func readiness(
        userId: String,
        services: ServiceContainer,
        store: OverallRankTrialStore = .shared
    ) async -> OverallRankTrialReadiness {
        let progress = store.load(userId: userId)
        let overallProgress: OverallLevelProgress? = try? await services.database.read(
            collection: "overall_level_progress",
            documentId: userId
        )
        var movementById: [String: MovementProgressState] = [:]
        for definition in OverallRankTrialDefinitions.all {
            for standard in definition.movementStandards {
                guard movementById[standard.rankStandardMovementId] == nil,
                      let state: MovementProgressState = try? await services.database.read(
                        collection: "movement_progress",
                        documentId: "\(userId):\(standard.rankStandardMovementId)"
                      )
                else { continue }
                movementById[standard.rankStandardMovementId] = state
            }
        }

        let skillState = services.rank.state(userId: userId)
        let profile = services.attribute.profile(userId: userId)
        let userProfile = try? await services.user.fetchProfile(userId: userId)
        let equipment = movementEquipment(from: userProfile?.equipment ?? [.bodyweight])

        return evaluate(
            OverallRankTrialReadinessInput(
                userId: userId,
                currentRank: progress.currentRank,
                overallLevel: overallProgress?.level ?? 0,
                movementProgress: movementById,
                skillTiers: skillState.perSkill,
                attributeProfile: profile,
                equipment: equipment,
                attempts: progress.attempts
            )
        )
    }

    private func movementEquipment(from equipment: [Equipment]) -> Set<MovementEquipment> {
        var result: Set<MovementEquipment> = [.bodyweight, .openSpace]
        for item in equipment {
            switch item {
            case .fullGym:
                result.formUnion([
                    .barbell,
                    .dumbbell,
                    .kettlebell,
                    .cable,
                    .machine,
                    .bench,
                    .box,
                    .sled,
                    .cardioMachine,
                    .pullupBar,
                    .bodyweight,
                    .openSpace
                ])
            case .machines:
                result.formUnion([.cable, .machine, .cardioMachine, .bodyweight, .openSpace])
            case .barbell:
                result.formUnion([.barbell, .bodyweight, .openSpace])
            case .dumbbells, .homeWeights:
                result.formUnion([.dumbbell, .kettlebell, .bodyweight, .openSpace])
            case .bench:
                result.formUnion([.bench, .bodyweight])
            case .pullupBar:
                result.formUnion([.pullupBar, .bodyweight])
            case .bodyweight:
                result.insert(.bodyweight)
            case .bands:
                result.formUnion([.band, .bodyweight])
            }
        }
        return result
    }

    private func requirementLines(
        for definition: OverallRankTrialDefinition,
        resolution: RankTrialResolution,
        input: OverallRankTrialReadinessInput
    ) -> [OverallRankTrialRequirementLine] {
        var lines: [OverallRankTrialRequirementLine] = []

        lines.append(
            OverallRankTrialRequirementLine(
                id: "overall-level",
                kind: .overallLevel,
                label: "Overall LVL",
                current: "LVL \(input.overallLevel)",
                required: "LVL \(definition.minOverallLevel)",
                isMet: input.overallLevel >= definition.minOverallLevel
            )
        )

        if definition.topAttributeCount > 0 {
            // Gate on PEAK, not current: a rank trial unlocks on proven ceiling,
            // so taking a break (which drifts `current` down — see AttributeDrift
            // and the honest-staleness signal) never re-locks an earned trial.
            let qualifiedAttributes = AttributeKey.allCases
                .map { input.attributeProfile.value(for: $0).peak }
                .filter { $0 >= definition.topAttributeFloor }
                .count
            lines.append(
                OverallRankTrialRequirementLine(
                    id: "top-attributes",
                    kind: .attributes,
                    label: "Top attributes",
                    current: "\(qualifiedAttributes)/\(definition.topAttributeCount)",
                    required: "\(definition.topAttributeCount) at \(Int(definition.topAttributeFloor))+",
                    isMet: qualifiedAttributes >= definition.topAttributeCount
                )
            )
        }

        for standard in definition.movementStandards {
            let currentAP = input.movementProgress[standard.rankStandardMovementId]?.totalAP ?? 0
            lines.append(
                OverallRankTrialRequirementLine(
                    id: "movement-\(standard.rankStandardMovementId)",
                    kind: .movement,
                    label: standard.displayName,
                    current: "\(Int(currentAP.rounded())) AP",
                    required: "\(Int(standard.minimumAP.rounded())) AP",
                    isMet: currentAP >= standard.minimumAP
                )
            )
        }

        for standard in definition.skillStandards {
            let currentTier = input.skillTiers[standard.skillId] ?? .initiate
            lines.append(
                OverallRankTrialRequirementLine(
                    id: "skill-\(standard.skillId)",
                    kind: .skill,
                    label: standard.displayName,
                    current: currentTier.displayName,
                    required: standard.minimumTier.displayName,
                    isMet: currentTier >= standard.minimumTier
                )
            )
        }

        let requiredEquipment = resolution.resolvedTrial?.requiredEquipment ?? definition.requiredEquipment
        let missingEquipment = resolution.blockers.reduce(into: Set<MovementEquipment>()) { result, blocker in
            result.formUnion(blocker.missingEquipment)
        }
        lines.append(
            OverallRankTrialRequirementLine(
                id: "equipment",
                kind: .equipment,
                label: resolution.resolvedTrial?.selectedLoadout.displayName ?? "Equipment",
                current: input.equipment.map(\.displayName).sorted().joined(separator: ", "),
                required: missingEquipment.isEmpty
                    ? requiredEquipment.map(\.displayName).sorted().joined(separator: ", ")
                    : missingEquipment.map(\.displayName).sorted().joined(separator: ", "),
                isMet: resolution.isReady
            )
        )

        return lines
    }
}

struct OverallRankTrialRunResult: Sendable {
    let definition: OverallRankTrialDefinition
    let attempt: OverallRankTrialAttempt
    let evaluation: OverallRankTrialEvaluation
    let progress: OverallRankTrialProgress
    let completionResult: TrainingCompletionResult?
    let didAdvanceRank: Bool
    let wasDuplicate: Bool
    let callouts: [OverallRankTrialRunCallout]

    init(
        definition: OverallRankTrialDefinition,
        attempt: OverallRankTrialAttempt,
        evaluation: OverallRankTrialEvaluation,
        progress: OverallRankTrialProgress,
        completionResult: TrainingCompletionResult?,
        didAdvanceRank: Bool,
        wasDuplicate: Bool,
        callouts: [OverallRankTrialRunCallout]
    ) {
        self.definition = definition
        self.attempt = attempt
        self.evaluation = evaluation
        self.progress = progress
        self.completionResult = completionResult
        self.didAdvanceRank = didAdvanceRank
        self.wasDuplicate = wasDuplicate
        self.callouts = callouts
    }

    var rankUp: RankUp? {
        guard didAdvanceRank else { return nil }
        return RankUp(
            skillId: "overall-rank",
            skillTitle: "Overall Rank",
            fromTier: nil,
            toTier: attempt.targetRank
        )
    }
}

@MainActor
final class OverallRankTrialRunner {
    static let shared = OverallRankTrialRunner()

    private init() {}

    func draft(
        for definition: OverallRankTrialDefinition,
        userId: String,
        date: Date = Date(),
        resolvedTrial: ResolvedRankTrial? = nil,
        bodyweightKg: Double? = nil
    ) -> TrainingSessionDraft {
        let resolved = resolvedTrial ?? RankTrialLoadoutResolver.shared.resolve(
            definition: definition,
            userId: userId,
            equipment: definition.requiredEquipment,
            generatedAt: date
        ).resolvedTrial
        return definition.makeDraft(userId: userId, date: date, resolvedTrial: resolved, bodyweightKg: bodyweightKg)
    }

    @discardableResult
    func complete(
        performanceLog: PerformanceLog,
        services: ServiceContainer,
        store: OverallRankTrialStore = .shared
    ) async throws -> OverallRankTrialRunResult? {
        guard let definition = definition(for: performanceLog) else { return nil }
        let existing = store.load(userId: performanceLog.userId)
        if let duplicate = existing.attempts.first(where: { $0.id == performanceLog.id }) {
            let evaluation = duplicate.evaluation ?? evaluateDetailed(performanceLog, against: definition)
            return OverallRankTrialRunResult(
                definition: definition,
                attempt: duplicate,
                evaluation: evaluation,
                progress: existing,
                completionResult: nil,
                didAdvanceRank: false,
                wasDuplicate: true,
                callouts: callouts(
                    for: duplicate,
                    definition: definition,
                    previousProgress: existing,
                    didAdvanceRank: false,
                    wasDuplicate: true
                )
            )
        }

        let completionResult = try await TrainingCompletionService.shared.complete(performanceLog, services: services)
        let profile = try? await services.user.fetchProfile(userId: performanceLog.userId)
        return recordCompletedAttempt(
            performanceLog: performanceLog,
            completionResult: completionResult,
            store: store,
            bodyweightKg: profile?.weightKg
        )
    }

    @discardableResult
    func recordCompletedAttempt(
        performanceLog: PerformanceLog,
        completionResult: TrainingCompletionResult,
        store: OverallRankTrialStore = .shared,
        bodyweightKg: Double? = nil
    ) -> OverallRankTrialRunResult? {
        guard let definition = definition(for: performanceLog) else { return nil }
        let previousProgress = store.load(userId: performanceLog.userId)
        let evaluation = evaluateDetailed(
            performanceLog,
            against: definition,
            bodyweightKg: bodyweightKg,
            enforceLoadPercent: true
        )
        let selectedLoadout = selectedLoadout(in: performanceLog)
        let attempt = OverallRankTrialAttempt(
            id: performanceLog.id,
            userId: performanceLog.userId,
            definitionId: definition.id,
            targetRank: definition.targetRank,
            startedAt: performanceLog.startedAt,
            completedAt: performanceLog.completedAt,
            performanceLogId: performanceLog.id,
            passed: evaluation.passed,
            movementAPGained: completionResult.totalMovementAP,
            overallLevelXPGained: completionResult.overallLevelXPGained,
            resolvedTrialId: selectedLoadout.map { "\(definition.id).\($0.rawValue)" },
            loadout: selectedLoadout,
            evaluation: evaluation
        )
        let record = store.record(attempt, userId: performanceLog.userId)

        if record.didAdvanceRank {
            NotificationCenter.default.post(
                name: .overallRankTrialCompleted,
                object: record.attempt,
                userInfo: [
                    "targetRank": definition.targetRank.rawValue,
                    "definitionId": definition.id
                ]
            )
        }

        return OverallRankTrialRunResult(
            definition: definition,
            attempt: record.attempt,
            evaluation: record.attempt.evaluation ?? evaluation,
            progress: record.progress,
            completionResult: completionResult,
            didAdvanceRank: record.didAdvanceRank,
            wasDuplicate: record.wasDuplicate,
            callouts: callouts(
                for: record.attempt,
                definition: definition,
                previousProgress: previousProgress,
                didAdvanceRank: record.didAdvanceRank,
                wasDuplicate: record.wasDuplicate
            )
        )
    }

    private func callouts(
        for attempt: OverallRankTrialAttempt,
        definition: OverallRankTrialDefinition,
        previousProgress: OverallRankTrialProgress,
        didAdvanceRank: Bool,
        wasDuplicate: Bool
    ) -> [OverallRankTrialRunCallout] {
        if wasDuplicate {
            return [
                OverallRankTrialRunCallout(
                    kind: .duplicateAttempt,
                    title: "Attempt already counted",
                    message: "\(definition.displayName) was already recorded, so rank progress stayed at \(previousProgress.currentRank.displayName)."
                )
            ]
        }

        guard attempt.passed, didAdvanceRank else { return [] }

        let priorAttempts = previousProgress.attempts.filter { $0.definitionId == definition.id }
        let priorFailureCount = priorAttempts.filter { !$0.passed }.count
        let hadPriorPass = priorAttempts.contains { $0.passed }
        guard priorFailureCount > 0, !hadPriorPass else { return [] }

        let attemptNoun = priorFailureCount == 1 ? "attempt" : "attempts"
        return [
            OverallRankTrialRunCallout(
                kind: .comebackPass,
                title: "Comeback clear",
                message: "Cleared \(definition.displayName) after \(priorFailureCount) failed \(attemptNoun)."
            )
        ]
    }

    func evaluatePerformance(
        _ performanceLog: PerformanceLog,
        against definition: OverallRankTrialDefinition
    ) -> Bool {
        evaluateDetailed(performanceLog, against: definition).passed
    }

    func evaluateDetailed(
        _ performanceLog: PerformanceLog,
        against definition: OverallRankTrialDefinition,
        bodyweightKg: Double? = nil,
        enforceLoadPercent: Bool = false
    ) -> OverallRankTrialEvaluation {
        let exerciseMovementIds = movementIds(in: performanceLog)
        let selectedLoadout = selectedLoadout(in: performanceLog)
        let stationGroups = stationCandidates(for: definition, selectedLoadout: selectedLoadout)
        var stationResults = stationGroups.map { candidates -> OverallRankTrialStationResult in
            let station = candidates.first { candidate in
                let titledMovementIds = movementIds(in: performanceLog.blocks.filter { $0.title == candidate.title })
                return !candidate.allowedMovementIds.intersection(titledMovementIds).isEmpty
            } ?? candidates.first { candidate in
                !candidate.allowedMovementIds.intersection(exerciseMovementIds).isEmpty
            } ?? candidates[0]
            let stationBlocks = performanceLog.blocks.filter { $0.title == station.title }
            return evaluateStation(
                station,
                blocks: stationBlocks,
                bodyweightKg: bodyweightKg,
                enforceLoadPercent: enforceLoadPercent
            )
        }
        if let timeCapFailure = totalTimeCapFailure(for: definition, performanceLog: performanceLog) {
            stationResults.insert(timeCapFailure, at: 0)
        }

        return OverallRankTrialEvaluation(
            definitionId: definition.id,
            passed: stationResults.allSatisfy { $0.status == .passed },
            stationResults: stationResults
        )
    }

    private func stationCandidates(
        for definition: OverallRankTrialDefinition,
        selectedLoadout: TrialLoadout? = nil
    ) -> [[TrialStation]] {
        if definition.loadoutVariants.isEmpty {
            return definition.performanceStandards.enumerated().map { index, standard in
                [
                    TrialStation(
                        id: "legacy-\(index + 1)",
                        title: standard.displayName,
                        category: .mobilityControl,
                        standard: standard,
                        capSeconds: nil,
                        loadPercentOfBodyweight: nil,
                        movementOptions: [TrialMovementOption(movementId: standard.movementId, displayName: standard.displayName)],
                        restRule: "Legacy rank gate.",
                        qualityFlags: [.clean]
                    )
                ]
            }
        }

        if let selectedLoadout,
           let variant = definition.loadoutVariants.first(where: { $0.loadout == selectedLoadout }) {
            return variant.stations.map { [$0] }
        }

        var orderedIds: [String] = []
        var grouped: [String: [TrialStation]] = [:]
        for station in definition.loadoutVariants.flatMap(\.stations) {
            if grouped[station.id] == nil {
                orderedIds.append(station.id)
                grouped[station.id] = []
            }
            grouped[station.id]?.append(station)
        }
        return orderedIds.compactMap { grouped[$0] }
    }

    private func selectedLoadout(in performanceLog: PerformanceLog) -> TrialLoadout? {
        let marker = " official station:"
        let notes = ([performanceLog.notes] + performanceLog.blocks.flatMap { block in
            [block.notes] + block.exercises.map(\.notes)
        }).compactMap { $0 }

        for note in notes where note.contains(marker) {
            let label = note
                .components(separatedBy: marker)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let loadout = TrialLoadout.allCases.first(where: { $0.displayName == label }) {
                return loadout
            }
        }
        return nil
    }

    private func totalTimeCapFailure(
        for definition: OverallRankTrialDefinition,
        performanceLog: PerformanceLog
    ) -> OverallRankTrialStationResult? {
        let capSeconds = definition.estimatedMinutes * 60
        let elapsed = max(0, Int(performanceLog.completedAt.timeIntervalSince(performanceLog.startedAt).rounded()))
        guard elapsed > capSeconds else { return nil }
        return OverallRankTrialStationResult(
            id: "trial-time-cap",
            title: "Trial Time Cap",
            category: .engine,
            movementId: "trial.time-cap",
            required: capSeconds,
            qualifyingSetsRequired: 1,
            qualifyingSetsCompleted: 0,
            totalValue: elapsed,
            failedQualityFlags: [],
            status: .failed,
            failureReason: "Trial exceeded the official time cap."
        )
    }

    private func movementIds(in performanceLog: PerformanceLog) -> Set<String> {
        movementIds(in: performanceLog.blocks)
    }

    private func movementIds(in blocks: [PerformanceBlock]) -> Set<String> {
        Set(
            blocks.flatMap(\.exercises)
                .flatMap { exercise in
                    [
                        exercise.movementId,
                        exercise.rankStandardMovementId,
                        MovementResolver.resolve(exercise.name).movementId
                    ].compactMap { $0 }
                }
        )
    }

    private func evaluateStation(
        _ station: TrialStation,
        blocks: [PerformanceBlock],
        bodyweightKg: Double?,
        enforceLoadPercent: Bool
    ) -> OverallRankTrialStationResult {
        let standard = station.standard
        let matchingSets = blocks.flatMap(\.exercises)
            .filter { exercise in
                station.allowedMovementIds.contains(exercise.movementId ?? "")
                    || station.allowedMovementIds.contains(exercise.rankStandardMovementId ?? "")
                    || station.allowedMovementIds.contains(MovementResolver.resolve(exercise.name).movementId)
            }
            .flatMap(\.sets)
            .filter { !$0.isWarmup }

        let failedQualityFlags = Set(
            matchingSets
                .flatMap(\.qualityFlags)
                .filter { $0 == .formBreak || $0 == .pain }
        )
        if !failedQualityFlags.isEmpty {
            return stationResult(
                station,
                qualifyingSetsCompleted: 0,
                totalValue: 0,
                failedQualityFlags: failedQualityFlags,
                status: .failed,
                failureReason: "Pain or form-break flag recorded."
            )
        }

        let cleanSets = matchingSets.filter { set in
            !set.qualityFlags.contains(.formBreak) && !set.qualityFlags.contains(.pain)
        }
        let values = cleanSets.map { set in
            value(for: set, metric: standard.metric)
        }

        guard !values.isEmpty else {
            return stationResult(
                station,
                qualifyingSetsCompleted: 0,
                totalValue: 0,
                failedQualityFlags: [],
                status: .missing,
                failureReason: "No logged set for this station."
            )
        }

        if let capSeconds = station.capSeconds {
            let blockSeconds = blocks.compactMap(\.durationSeconds).reduce(0, +)
            if blockSeconds > capSeconds {
                return stationResult(
                    station,
                    qualifyingSetsCompleted: 0,
                    totalValue: values.reduce(0, +),
                    failedQualityFlags: [],
                    status: .failed,
                    failureReason: "Station exceeded the official time cap."
                )
            }
        }

        if enforceLoadPercent, let loadPercent = station.loadPercentOfBodyweight {
            guard let bodyweightKg else {
                return stationResult(
                    station,
                    qualifyingSetsCompleted: 0,
                    totalValue: values.reduce(0, +),
                    failedQualityFlags: [],
                    status: .failed,
                    failureReason: "Bodyweight is required for the load standard."
                )
            }
            let minimumLoad = bodyweightKg * loadPercent
            let loadedSetExists = cleanSets.contains { ($0.weightKg ?? 0) >= minimumLoad }
            if !loadedSetExists {
                return stationResult(
                    station,
                    qualifyingSetsCompleted: 0,
                    totalValue: values.reduce(0, +),
                    failedQualityFlags: [],
                    status: .failed,
                    failureReason: "Logged load missed the bodyweight percentage standard."
                )
            }
        }

        let qualifyingSetCount = values.filter { $0 >= standard.minimumValue }.count
        let status: OverallRankTrialStationStatus = qualifyingSetCount >= standard.minimumQualifyingSets ? .passed : .failed
        return stationResult(
            station,
            qualifyingSetsCompleted: qualifyingSetCount,
            totalValue: values.reduce(0, +),
            failedQualityFlags: [],
            status: status,
            failureReason: status == .passed ? nil : "Station floor was not cleared."
        )
    }

    private func stationResult(
        _ station: TrialStation,
        qualifyingSetsCompleted: Int,
        totalValue: Int,
        failedQualityFlags: Set<PerformanceQualityFlag>,
        status: OverallRankTrialStationStatus,
        failureReason: String?
    ) -> OverallRankTrialStationResult {
        OverallRankTrialStationResult(
            id: station.id,
            title: station.title,
            category: station.category,
            movementId: station.standard.movementId,
            required: station.standard.minimumValue,
            qualifyingSetsRequired: station.standard.minimumQualifyingSets,
            qualifyingSetsCompleted: qualifyingSetsCompleted,
            totalValue: totalValue,
            failedQualityFlags: failedQualityFlags,
            status: status,
            failureReason: failureReason
        )
    }

    private func value(for set: PerformanceSet, metric: TrainingMetricKind) -> Int {
        switch metric {
        case .reps:
            return set.reps ?? 0
        case .holdSeconds:
            return set.holdSeconds ?? 0
        case .durationSeconds:
            return set.durationSeconds ?? 0
        case .distanceMeters:
            return set.distanceMeters ?? 0
        case .calories:
            return set.calories ?? 0
        }
    }

    func performanceLog(
        from draft: TrainingSessionDraft,
        userId: String,
        startedAt: Date,
        completedAt: Date,
        passing: Bool
    ) -> PerformanceLog {
        let definition = draft.programId.flatMap(OverallRankTrialDefinitions.definition)
        let selectedLoadout = selectedLoadout(inDraft: draft)

        return PerformanceLog(
            id: draft.id,
            userId: userId,
            draftId: draft.id,
            source: draft.source,
            title: draft.title,
            startedAt: startedAt,
            completedAt: completedAt,
            programId: draft.programId,
            dayNumber: draft.dayNumber,
            blocks: draft.blocks.map { block in
                PerformanceBlock(
                    id: block.id,
                    kind: block.kind,
                    title: block.title,
                    skillId: block.skillId,
                    routineId: block.routineId,
                    cardioType: block.cardioType,
                    exercises: block.prescriptions.map { prescription in
                        let metric = prescription.target.metricKind
                        let target = prescription.target.metricLowerBound ?? 1
                        let loadoutStations = selectedLoadout
                            .flatMap { selected in
                                definition?.loadoutVariants.first(where: { $0.loadout == selected })?.stations
                            } ?? definition?.loadoutVariants.flatMap(\.stations) ?? []
                        let station = loadoutStations
                            .first { station in
                                station.allowedMovementIds.contains(prescription.movementId ?? "")
                                    || station.allowedMovementIds.contains(prescription.rankStandardMovementId ?? "")
                                    || station.allowedMovementIds.contains(MovementResolver.resolve(prescription.exerciseName).movementId)
                            }
                        let standard = definition?.performanceStandards.first { standard in
                            prescription.movementId == standard.movementId
                                || prescription.rankStandardMovementId == standard.movementId
                                || MovementResolver.resolve(prescription.exerciseName).movementId == standard.movementId
                        } ?? station?.standard
                        let setCount = max(1, standard?.minimumQualifyingSets ?? prescription.sets)
                        let achieved = passing ? target : max(0, target - 1)
                        let loadKg = station?.loadPercentOfBodyweight == nil ? nil : 50.0
                        return PerformanceExercise(
                            id: prescription.id,
                            name: prescription.exerciseName,
                            movementId: prescription.movementId,
                            rankStandardMovementId: prescription.rankStandardMovementId,
                            plannedSets: prescription.sets,
                                    plannedTarget: prescription.displayTargetText,
                            sets: (1...setCount).map { setNumber in
                                PerformanceSet(
                                    setNumber: setNumber,
                                    reps: metric == .reps ? achieved : nil,
                                    weightKg: loadKg,
                                    holdSeconds: metric == .holdSeconds ? achieved : nil,
                                    durationSeconds: metric == .durationSeconds ? achieved : nil,
                                    distanceMeters: metric == .distanceMeters ? achieved : nil,
                                    calories: metric == .calories ? achieved : nil,
                                    rpe: passing ? 8 : 7,
                                    qualityFlags: passing ? [.clean] : []
                                )
                            },
                            notes: prescription.notes
                        )
                    },
                    notes: block.notes
                )
            }
        )
    }

    private func selectedLoadout(inDraft draft: TrainingSessionDraft) -> TrialLoadout? {
        let marker = " official station:"
        let notes = draft.blocks.flatMap { block in
            [block.notes] + block.prescriptions.map(\.notes)
        }.compactMap { $0 }

        for note in notes where note.contains(marker) {
            let label = note
                .components(separatedBy: marker)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let loadout = TrialLoadout.allCases.first(where: { $0.displayName == label }) {
                return loadout
            }
        }
        return nil
    }

    private func definition(for performanceLog: PerformanceLog) -> OverallRankTrialDefinition? {
        guard performanceLog.source == .overallRankTrial,
              let definitionId = performanceLog.programId
        else { return nil }
        return OverallRankTrialDefinitions.definition(id: definitionId)
    }
}

extension Notification.Name {
    static let overallRankTrialCompleted = Notification.Name("unbound.overallRankTrialCompleted")
}
