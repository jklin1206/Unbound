import Foundation

enum RecoveryState: String, Codable, CaseIterable, Sendable, Equatable {
    case wellRecovered
    case normal
    case accumulated
    case flagged
}

struct CheckpointSignals: Codable, Equatable, Sendable {
    static let loadAdjustmentRange: ClosedRange<Double> = -1.0...1.0
    static let maxSummaryLength = 700

    var loadAdjustmentBias: Double?
    var recoveryStateHint: RecoveryState?
    var weakRegions: [BodyRegion]
    /// Existing skill ids are represented as `SkillNode.id` strings in the
    /// current skill tree model. Agent C can wrap this later if a typed SkillID
    /// lands globally.
    var skillFocusHints: [String]
    var nutrition: NutritionContext?
    var freeTextSummary: String?

    init(
        loadAdjustmentBias: Double? = nil,
        recoveryStateHint: RecoveryState? = nil,
        weakRegions: [BodyRegion] = [],
        skillFocusHints: [String] = [],
        nutrition: NutritionContext? = nil,
        freeTextSummary: String? = nil
    ) {
        self.loadAdjustmentBias = loadAdjustmentBias.map(Self.clampedLoadAdjustmentBias)
        self.recoveryStateHint = recoveryStateHint
        self.weakRegions = Self.uniquePreservingOrder(weakRegions)
        self.skillFocusHints = Self.normalizedSkillIDs(skillFocusHints)
        self.nutrition = nutrition
        self.freeTextSummary = Self.normalizedSummary(freeTextSummary)
    }

    enum CodingKeys: String, CodingKey {
        case loadAdjustmentBias
        case recoveryStateHint
        case weakRegions
        case skillFocusHints
        case nutrition
        case freeTextSummary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            loadAdjustmentBias: try container.decodeIfPresent(Double.self, forKey: .loadAdjustmentBias),
            recoveryStateHint: try container.decodeIfPresent(RecoveryState.self, forKey: .recoveryStateHint),
            weakRegions: try container.decodeIfPresent([BodyRegion].self, forKey: .weakRegions) ?? [],
            skillFocusHints: try container.decodeIfPresent([String].self, forKey: .skillFocusHints) ?? [],
            nutrition: try container.decodeIfPresent(NutritionContext.self, forKey: .nutrition),
            freeTextSummary: try container.decodeIfPresent(String.self, forKey: .freeTextSummary)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(loadAdjustmentBias, forKey: .loadAdjustmentBias)
        try container.encodeIfPresent(recoveryStateHint, forKey: .recoveryStateHint)
        try container.encode(weakRegions, forKey: .weakRegions)
        try container.encode(skillFocusHints, forKey: .skillFocusHints)
        try container.encodeIfPresent(nutrition, forKey: .nutrition)
        try container.encodeIfPresent(freeTextSummary, forKey: .freeTextSummary)
    }

    static func clampedLoadAdjustmentBias(_ value: Double) -> Double {
        min(max(value, loadAdjustmentRange.lowerBound), loadAdjustmentRange.upperBound)
    }

    private static func uniquePreservingOrder(_ regions: [BodyRegion]) -> [BodyRegion] {
        var seen = Set<BodyRegion>()
        return regions.filter { seen.insert($0).inserted }
    }

    private static func normalizedSkillIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.compactMap { raw in
            let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, seen.insert(id).inserted else { return nil }
            return id
        }
    }

    private static func normalizedSummary(_ summary: String?) -> String? {
        guard let summary else { return nil }
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count <= maxSummaryLength { return trimmed }
        return String(trimmed.prefix(maxSummaryLength))
    }
}
