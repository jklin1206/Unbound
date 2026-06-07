import Foundation

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
    /// Live build-weighted accumulation (Phase 7). Gates next-rank eligibility.
    let aggregateRank: RankTier
    let equipment: Set<MovementEquipment>
    let attempts: [OverallRankTrialAttempt]

    init(
        userId: String,
        currentRank: RankTitle,
        overallLevel: Int,
        aggregateRank: RankTier,
        equipment: Set<MovementEquipment> = [.bodyweight],
        attempts: [OverallRankTrialAttempt] = []
    ) {
        self.userId = userId
        self.currentRank = currentRank
        self.overallLevel = overallLevel
        self.aggregateRank = aggregateRank
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
