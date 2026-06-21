import Foundation

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

struct BodyMapSourceReceipt: Codable, Identifiable, Hashable, Sendable {
    var id: String { sourceLogId }

    let sourceLogId: String
    let userId: String
    let noveltyMultiplier: Double
    let regionRewards: [BodyMapRegionReward]

    var result: BodyMapIngestResult {
        BodyMapIngestResult(
            noveltyMultiplier: noveltyMultiplier,
            regionRewards: regionRewards,
            wasDuplicate: true
        )
    }
}
