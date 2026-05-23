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
        self.plannedSets = max(plannedSets ?? (metric == .holdSeconds ? 1 : 2), qualifyingSets)
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

struct OverallRankTrialDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let targetRank: RankTitle
    let displayName: String
    let subtitle: String
    let estimatedMinutes: Int
    let minOverallLevel: Int
    let topAttributeCount: Int
    let topAttributeFloor: Double
    let requiredEquipment: Set<MovementEquipment>
    let movementStandards: [OverallRankTrialMovementStandard]
    let skillStandards: [OverallRankTrialSkillStandard]
    let performanceStandards: [OverallRankTrialPerformanceStandard]

    func makeDraft(userId: String, date: Date = Date()) -> TrainingSessionDraft {
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

    static let foundationProof = OverallRankTrialDefinition(
        id: "overall-rank-trial-novice-foundation-proof",
        targetRank: .novice,
        displayName: "Foundation Proof",
        subtitle: "Initiate to Novice rank gate",
        estimatedMinutes: 14,
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
        skillStandards: [
            OverallRankTrialSkillStandard(
                skillId: "cal.pushup",
                displayName: "Push-Up",
                minimumTier: .novice
            )
        ],
        performanceStandards: [
            OverallRankTrialPerformanceStandard(
                movementId: "exercise.pushup",
                displayName: "Push-Up",
                metric: .reps,
                minimumValue: 8
            ),
            OverallRankTrialPerformanceStandard(
                movementId: "exercise.bodyweight-squat",
                displayName: "Bodyweight Squat",
                metric: .reps,
                minimumValue: 12
            ),
            OverallRankTrialPerformanceStandard(
                movementId: "skill-drill.wall-handstand",
                displayName: "Wall Handstand",
                metric: .holdSeconds,
                minimumValue: 20
            )
        ]
    )

    static let calibration = OverallRankTrialDefinition(
        id: "overall-rank-trial-apprentice-calibration",
        targetRank: .apprentice,
        displayName: "The Calibration",
        subtitle: "Novice to Apprentice rank gate",
        estimatedMinutes: 20,
        minOverallLevel: 8,
        topAttributeCount: 0,
        topAttributeFloor: 0,
        requiredEquipment: [.bodyweight, .pullupBar],
        movementStandards: [
            OverallRankTrialMovementStandard(
                rankStandardMovementId: "exercise.pullup",
                displayName: "Pull-Up",
                minimumAP: 60
            ),
            OverallRankTrialMovementStandard(
                rankStandardMovementId: "exercise.pushup",
                displayName: "Push-Up",
                minimumAP: 100
            )
        ],
        skillStandards: [
            OverallRankTrialSkillStandard(
                skillId: "pp.pullup",
                displayName: "Pull-Up",
                minimumTier: .apprentice
            )
        ],
        performanceStandards: [
            OverallRankTrialPerformanceStandard(
                movementId: "exercise.pullup",
                displayName: "Pull-Up",
                metric: .reps,
                minimumValue: 5,
                minimumQualifyingSets: 14,
                plannedSets: 14,
                restSeconds: 20
            ),
            OverallRankTrialPerformanceStandard(
                movementId: "exercise.pushup",
                displayName: "Push-Up",
                metric: .reps,
                minimumValue: 10,
                minimumQualifyingSets: 14,
                plannedSets: 14,
                restSeconds: 20
            ),
            OverallRankTrialPerformanceStandard(
                movementId: "exercise.bodyweight-squat",
                displayName: "Bodyweight Squat",
                metric: .reps,
                minimumValue: 15,
                minimumQualifyingSets: 14,
                plannedSets: 14,
                restSeconds: 20
            )
        ]
    )

    static let forge = OverallRankTrialDefinition(
        id: "overall-rank-trial-honed-forge",
        targetRank: .honed,
        displayName: "The Forge",
        subtitle: "Apprentice to Honed rank gate",
        estimatedMinutes: 35,
        minOverallLevel: 15,
        topAttributeCount: 1,
        topAttributeFloor: 58,
        requiredEquipment: [.bodyweight, .kettlebell, .openSpace, .pullupBar],
        movementStandards: [
            movementStandard("exercise.pullup", minimumAP: 160, displayName: "Pull-Up"),
            movementStandard("exercise.kettlebell-swing", minimumAP: 140)
        ],
        skillStandards: [
            skillStandard("pp.pullup", minimumTier: .honed)
        ],
        performanceStandards: [
            performanceStandard(
                "cardio.run",
                metric: .distanceMeters,
                minimumValue: 400,
                minimumQualifyingSets: 3,
                plannedSets: 3,
                restSeconds: 45,
                displayName: "400m Run"
            ),
            performanceStandard(
                "exercise.kettlebell-swing",
                metric: .reps,
                minimumValue: 21,
                minimumQualifyingSets: 3,
                plannedSets: 3,
                restSeconds: 45
            ),
            performanceStandard(
                "exercise.pushup",
                metric: .reps,
                minimumValue: 21,
                minimumQualifyingSets: 3,
                plannedSets: 3,
                restSeconds: 45,
                displayName: "Push-Up"
            ),
            performanceStandard(
                "exercise.pullup",
                metric: .reps,
                minimumValue: 8,
                minimumQualifyingSets: 3,
                plannedSets: 3,
                restSeconds: 60,
                displayName: "Pull-Up"
            )
        ]
    )

    static let reckoning = OverallRankTrialDefinition(
        id: "overall-rank-trial-forged-reckoning",
        targetRank: .forged,
        displayName: "The Reckoning",
        subtitle: "Honed to Forged rank gate",
        estimatedMinutes: 42,
        minOverallLevel: 22,
        topAttributeCount: 2,
        topAttributeFloor: 68,
        requiredEquipment: [.bodyweight, .kettlebell, .openSpace, .pullupBar],
        movementStandards: [
            movementStandard("exercise.pullup", minimumAP: 240, displayName: "Pull-Up"),
            movementStandard("exercise.kettlebell-swing", minimumAP: 220),
            movementStandard("carry.farmer-carry", minimumAP: 180)
        ],
        skillStandards: [
            skillStandard("pp.pullup", minimumTier: .forged),
            skillStandard("co.bw-farmer-carry", minimumTier: .forged, displayName: "Farmer Carry")
        ],
        performanceStandards: [
            performanceStandard(
                "cardio.run",
                metric: .distanceMeters,
                minimumValue: 800,
                plannedSets: 1,
                restSeconds: 60,
                displayName: "800m Run"
            ),
            performanceStandard(
                "exercise.kettlebell-swing",
                metric: .reps,
                minimumValue: 30,
                minimumQualifyingSets: 2,
                plannedSets: 2,
                restSeconds: 60
            ),
            performanceStandard(
                "exercise.pullup",
                metric: .reps,
                minimumValue: 10,
                minimumQualifyingSets: 2,
                plannedSets: 2,
                restSeconds: 75,
                displayName: "Pull-Up"
            ),
            performanceStandard(
                "exercise.pushup",
                metric: .reps,
                minimumValue: 30,
                minimumQualifyingSets: 2,
                plannedSets: 2,
                restSeconds: 60,
                displayName: "Push-Up"
            ),
            performanceStandard(
                "carry.farmer-carry",
                metric: .distanceMeters,
                minimumValue: 60,
                minimumQualifyingSets: 2,
                plannedSets: 2,
                restSeconds: 60,
                displayName: "Farmer Carry"
            )
        ]
    )

    static let gauntlet = OverallRankTrialDefinition(
        id: "overall-rank-trial-veteran-gauntlet",
        targetRank: .veteran,
        displayName: "The Gauntlet",
        subtitle: "Forged to Veteran rank gate",
        estimatedMinutes: 50,
        minOverallLevel: 40,
        topAttributeCount: 3,
        topAttributeFloor: 78,
        requiredEquipment: [
            .bodyweight,
            .dumbbell,
            .kettlebell,
            .openSpace,
            .sled,
            .box
        ],
        movementStandards: [
            movementStandard("cardio.run", minimumAP: 300, displayName: "Run"),
            movementStandard("carry.farmer-carry", minimumAP: 260),
            movementStandard("carry.sled-push", minimumAP: 220)
        ],
        skillStandards: [
            skillStandard("co.bw-farmer-carry", minimumTier: .veteran, displayName: "Farmer Carry"),
            skillStandard("ld.box-jump", minimumTier: .veteran)
        ],
        performanceStandards: [
            performanceStandard(
                "cardio.run",
                metric: .distanceMeters,
                minimumValue: 1_000,
                plannedSets: 1,
                restSeconds: 30,
                displayName: "1km Run"
            ),
            performanceStandard(
                "carry.sled-push",
                metric: .distanceMeters,
                minimumValue: 50,
                plannedSets: 1,
                restSeconds: 45,
                displayName: "Sled Push"
            ),
            performanceStandard(
                "exercise.kettlebell-swing",
                metric: .reps,
                minimumValue: 30,
                plannedSets: 1,
                restSeconds: 45
            ),
            performanceStandard(
                "carry.sandbag-carry",
                metric: .distanceMeters,
                minimumValue: 50,
                plannedSets: 1,
                restSeconds: 45,
                displayName: "Sandbag Carry"
            ),
            performanceStandard(
                "exercise.walking-lunge",
                metric: .reps,
                minimumValue: 40,
                plannedSets: 1,
                restSeconds: 45
            ),
            performanceStandard(
                "carry.farmer-carry",
                metric: .distanceMeters,
                minimumValue: 50,
                plannedSets: 1,
                restSeconds: 45
            ),
            performanceStandard(
                "exercise.step-up",
                metric: .reps,
                minimumValue: 20,
                plannedSets: 1,
                restSeconds: 45,
                displayName: "Box Step-Up"
            ),
            performanceStandard(
                "skill.ld.box-jump",
                metric: .reps,
                minimumValue: 30,
                plannedSets: 1,
                restSeconds: 60,
                displayName: "Box Jump"
            )
        ]
    )

    static let crucible = OverallRankTrialDefinition(
        id: "overall-rank-trial-vessel-crucible",
        targetRank: .vessel,
        displayName: "The Crucible",
        subtitle: "Veteran to Vessel rank gate",
        estimatedMinutes: 58,
        minOverallLevel: 55,
        topAttributeCount: 4,
        topAttributeFloor: 84,
        requiredEquipment: [
            .bodyweight,
            .pullupBar,
            .dumbbell,
            .kettlebell,
            .openSpace,
            .box,
            .cardioMachine
        ],
        movementStandards: [
            movementStandard("cardio.row", minimumAP: 360, displayName: "Row"),
            movementStandard("exercise.weighted-pullup", minimumAP: 340, displayName: "Weighted Pull-Up"),
            movementStandard("exercise.pistol-squat", minimumAP: 300),
            movementStandard("carry.farmer-carry", minimumAP: 340)
        ],
        skillStandards: [
            skillStandard("pp.weighted-pullup", minimumTier: .vessel),
            skillStandard("ld.pistol-squat", minimumTier: .vessel),
            skillStandard("hs.freestanding-hs-30", minimumTier: .vessel),
            skillStandard("co.1.5x-farmer-carry", minimumTier: .vessel, displayName: "1.5x Farmer Carry")
        ],
        performanceStandards: [
            performanceStandard(
                "cardio.row",
                metric: .distanceMeters,
                minimumValue: 500,
                minimumQualifyingSets: 2,
                plannedSets: 2,
                restSeconds: 60,
                displayName: "500m Row"
            ),
            performanceStandard(
                "exercise.weighted-pullup",
                metric: .reps,
                minimumValue: 5,
                minimumQualifyingSets: 2,
                plannedSets: 2,
                restSeconds: 120,
                displayName: "Weighted Pull-Up"
            ),
            performanceStandard(
                "exercise.pistol-squat",
                metric: .reps,
                minimumValue: 6,
                minimumQualifyingSets: 2,
                plannedSets: 2,
                restSeconds: 90,
                displayName: "Pistol Squat"
            ),
            performanceStandard(
                "carry.farmer-carry",
                metric: .distanceMeters,
                minimumValue: 80,
                minimumQualifyingSets: 2,
                plannedSets: 2,
                restSeconds: 75,
                displayName: "Farmer Carry"
            ),
            performanceStandard(
                "skill.hs.freestanding-hs-30",
                metric: .holdSeconds,
                minimumValue: 30,
                plannedSets: 1,
                restSeconds: 120,
                displayName: "Freestanding Handstand"
            )
        ]
    )

    static let threshold = OverallRankTrialDefinition(
        id: "overall-rank-trial-unbound-threshold",
        targetRank: .unbound,
        displayName: "The Threshold",
        subtitle: "Vessel to Unbound rank gate",
        estimatedMinutes: 65,
        minOverallLevel: 72,
        topAttributeCount: 5,
        topAttributeFloor: 90,
        requiredEquipment: [
            .bodyweight,
            .pullupBar,
            .openSpace,
            .sled,
            .cardioMachine,
            .box
        ],
        movementStandards: [
            movementStandard("cardio.run", minimumAP: 460, displayName: "Run"),
            movementStandard("exercise.muscle-up", minimumAP: 420, displayName: "Muscle-Up"),
            movementStandard("carry.sled-push", minimumAP: 400),
            movementStandard("skill.cl.straddle-front-lever", minimumAP: 360, displayName: "Straddle Front Lever"),
            movementStandard("exercise.nordic-curl", minimumAP: 360, displayName: "Nordic Curl")
        ],
        skillStandards: [
            skillStandard("pp.muscle-up", minimumTier: .unbound),
            skillStandard("cl.straddle-front-lever", minimumTier: .unbound),
            skillStandard("ld.nordic-curl", minimumTier: .unbound),
            skillStandard("co.sled-push", minimumTier: .unbound, displayName: "Sled Push")
        ],
        performanceStandards: [
            performanceStandard(
                "cardio.run",
                metric: .distanceMeters,
                minimumValue: 1_600,
                plannedSets: 1,
                restSeconds: 60,
                displayName: "1 Mile Run"
            ),
            performanceStandard(
                "exercise.muscle-up",
                metric: .reps,
                minimumValue: 5,
                minimumQualifyingSets: 2,
                plannedSets: 2,
                restSeconds: 150,
                displayName: "Muscle-Up"
            ),
            performanceStandard(
                "carry.sled-push",
                metric: .distanceMeters,
                minimumValue: 60,
                minimumQualifyingSets: 2,
                plannedSets: 2,
                restSeconds: 90,
                displayName: "Sled Push"
            ),
            performanceStandard(
                "skill.cl.straddle-front-lever",
                metric: .holdSeconds,
                minimumValue: 8,
                minimumQualifyingSets: 2,
                plannedSets: 2,
                restSeconds: 120,
                displayName: "Straddle Front Lever"
            ),
            performanceStandard(
                "exercise.nordic-curl",
                metric: .reps,
                minimumValue: 5,
                minimumQualifyingSets: 2,
                plannedSets: 2,
                restSeconds: 120,
                displayName: "Nordic Curl"
            )
        ]
    )

    static let ascension = OverallRankTrialDefinition(
        id: "overall-rank-trial-ascendant-ascension",
        targetRank: .ascendant,
        displayName: "The Ascension",
        subtitle: "Unbound to Ascendant rank gate",
        estimatedMinutes: 75,
        minOverallLevel: 90,
        topAttributeCount: 6,
        topAttributeFloor: 95,
        requiredEquipment: [
            .bodyweight,
            .pullupBar,
            .dumbbell,
            .kettlebell,
            .openSpace
        ],
        movementStandards: [
            movementStandard("cardio.run", minimumAP: 560, displayName: "Run"),
            movementStandard("exercise.weighted-pullup", minimumAP: 520, displayName: "Weighted Pull-Up"),
            movementStandard("exercise.muscle-up", minimumAP: 520, displayName: "Muscle-Up"),
            movementStandard("skill.pl.full-planche", minimumAP: 480, displayName: "Full Planche"),
            movementStandard("skill.oah.one-arm-handstand-5s", minimumAP: 480, displayName: "One-Arm Handstand"),
            movementStandard("carry.farmer-carry", minimumAP: 500)
        ],
        skillStandards: [
            skillStandard("pp.strict-muscle-up", minimumTier: .ascendant),
            skillStandard("pl.full-planche", minimumTier: .ascendant),
            skillStandard("oah.one-arm-handstand-5s", minimumTier: .ascendant),
            skillStandard("co.2x-farmer-carry", minimumTier: .ascendant, displayName: "2x Farmer Carry")
        ],
        performanceStandards: [
            performanceStandard(
                "cardio.run",
                metric: .distanceMeters,
                minimumValue: 5_000,
                plannedSets: 1,
                restSeconds: 60,
                displayName: "5k Run"
            ),
            performanceStandard(
                "exercise.weighted-pullup",
                metric: .reps,
                minimumValue: 3,
                minimumQualifyingSets: 3,
                plannedSets: 3,
                restSeconds: 150,
                displayName: "Weighted Pull-Up"
            ),
            performanceStandard(
                "exercise.muscle-up",
                metric: .reps,
                minimumValue: 8,
                plannedSets: 1,
                restSeconds: 150,
                displayName: "Muscle-Up"
            ),
            performanceStandard(
                "skill.pl.full-planche",
                metric: .holdSeconds,
                minimumValue: 5,
                minimumQualifyingSets: 2,
                plannedSets: 2,
                restSeconds: 180,
                displayName: "Full Planche"
            ),
            performanceStandard(
                "skill.oah.one-arm-handstand-5s",
                metric: .holdSeconds,
                minimumValue: 5,
                minimumQualifyingSets: 2,
                plannedSets: 2,
                restSeconds: 180,
                displayName: "One-Arm Handstand"
            ),
            performanceStandard(
                "carry.farmer-carry",
                metric: .distanceMeters,
                minimumValue: 100,
                minimumQualifyingSets: 2,
                plannedSets: 2,
                restSeconds: 90,
                displayName: "Farmer Carry"
            )
        ]
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
        all.first { $0.id == id }
    }

    static func nextTrial(after rank: RankTitle) -> OverallRankTrialDefinition? {
        switch rank {
        case .initiate:
            return foundationProof
        case .novice:
            return calibration
        case .apprentice:
            return forge
        case .honed:
            return reckoning
        case .forged:
            return gauntlet
        case .veteran:
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
        case .honed: return 3
        case .forged: return 4
        case .veteran: return 5
        case .vessel: return 6
        case .unbound: return 7
        case .ascendant: return 8
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
                requirements: [],
                latestAttempt: input.attempts.sorted { $0.completedAt > $1.completedAt }.first
            )
        }

        let requirements = requirementLines(for: definition, input: input)
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
                result.formUnion([.cable, .machine, .bodyweight])
            case .barbell:
                result.formUnion([.barbell, .bodyweight])
            case .dumbbells, .homeWeights:
                result.formUnion([.dumbbell, .kettlebell, .bodyweight])
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
        input: OverallRankTrialReadinessInput
    ) -> [OverallRankTrialRequirementLine] {
        var lines: [OverallRankTrialRequirementLine] = []

        lines.append(
            OverallRankTrialRequirementLine(
                id: "overall-level",
                kind: .overallLevel,
                label: "Overall LV",
                current: "LV \(input.overallLevel)",
                required: "LV \(definition.minOverallLevel)",
                isMet: input.overallLevel >= definition.minOverallLevel
            )
        )

        if definition.topAttributeCount > 0 {
            let qualifiedAttributes = AttributeKey.allCases
                .map { input.attributeProfile.value(for: $0).current }
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

        let missingEquipment = definition.requiredEquipment.subtracting(input.equipment)
        lines.append(
            OverallRankTrialRequirementLine(
                id: "equipment",
                kind: .equipment,
                label: "Equipment",
                current: input.equipment.map(\.displayName).sorted().joined(separator: ", "),
                required: definition.requiredEquipment.map(\.displayName).sorted().joined(separator: ", "),
                isMet: missingEquipment.isEmpty
            )
        )

        return lines
    }
}

struct OverallRankTrialRunResult: Sendable {
    let definition: OverallRankTrialDefinition
    let attempt: OverallRankTrialAttempt
    let progress: OverallRankTrialProgress
    let completionResult: TrainingCompletionResult?
    let didAdvanceRank: Bool
    let wasDuplicate: Bool
    let callouts: [OverallRankTrialRunCallout]

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
        date: Date = Date()
    ) -> TrainingSessionDraft {
        definition.makeDraft(userId: userId, date: date)
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
            return OverallRankTrialRunResult(
                definition: definition,
                attempt: duplicate,
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
        return recordCompletedAttempt(
            performanceLog: performanceLog,
            completionResult: completionResult,
            store: store
        )
    }

    @discardableResult
    func recordCompletedAttempt(
        performanceLog: PerformanceLog,
        completionResult: TrainingCompletionResult,
        store: OverallRankTrialStore = .shared
    ) -> OverallRankTrialRunResult? {
        guard let definition = definition(for: performanceLog) else { return nil }
        let previousProgress = store.load(userId: performanceLog.userId)
        let passed = evaluatePerformance(performanceLog, against: definition)
        let attempt = OverallRankTrialAttempt(
            id: performanceLog.id,
            userId: performanceLog.userId,
            definitionId: definition.id,
            targetRank: definition.targetRank,
            startedAt: performanceLog.startedAt,
            completedAt: performanceLog.completedAt,
            performanceLogId: performanceLog.id,
            passed: passed,
            movementAPGained: completionResult.totalMovementAP,
            overallLevelXPGained: completionResult.overallLevelXPGained
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
        definition.performanceStandards.allSatisfy { standard in
            let matchingSets = performanceLog.blocks
                .flatMap(\.exercises)
                .filter { exercise in
                    exercise.movementId == standard.movementId
                        || exercise.rankStandardMovementId == standard.movementId
                        || MovementResolver.resolve(exercise.name).movementId == standard.movementId
                }
                .flatMap(\.sets)
                .filter { set in
                    !set.isWarmup && !set.qualityFlags.contains(.formBreak) && !set.qualityFlags.contains(.pain)
                }

            let values = matchingSets.map { set in
                switch standard.metric {
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

            let qualifyingSetCount = values.filter { $0 >= standard.minimumValue }.count
            let totalValue = values.reduce(0, +)
            return qualifyingSetCount >= standard.minimumQualifyingSets
                || totalValue >= standard.minimumValue * standard.minimumQualifyingSets
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
                        let standard = definition?.performanceStandards.first { standard in
                            prescription.movementId == standard.movementId
                                || prescription.rankStandardMovementId == standard.movementId
                                || MovementResolver.resolve(prescription.exerciseName).movementId == standard.movementId
                        }
                        let setCount = max(1, standard?.minimumQualifyingSets ?? 1)
                        let achieved = passing ? target : max(0, target - 1)
                        return PerformanceExercise(
                            id: prescription.id,
                            name: prescription.exerciseName,
                            movementId: prescription.movementId,
                            rankStandardMovementId: prescription.rankStandardMovementId,
                            plannedSets: prescription.sets,
                            plannedTarget: prescription.target.displayText,
                            sets: (1...setCount).map { setNumber in
                                PerformanceSet(
                                    setNumber: setNumber,
                                    reps: metric == .reps ? achieved : nil,
                                    holdSeconds: metric == .holdSeconds ? achieved : nil,
                                    durationSeconds: metric == .durationSeconds ? achieved : nil,
                                    distanceMeters: metric == .distanceMeters ? achieved : nil,
                                    calories: metric == .calories ? achieved : nil,
                                    rpe: passing ? 8 : 7,
                                    qualityFlags: passing ? [.clean] : []
                                )
                            }
                        )
                    }
                )
            }
        )
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
