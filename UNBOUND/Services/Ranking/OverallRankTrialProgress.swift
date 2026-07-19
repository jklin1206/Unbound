import Foundation

struct OverallRankTrialProgress: Codable, Equatable, Sendable {
    var highestPassedRank: RankTitle
    var attempts: [OverallRankTrialAttempt]

    static let empty = OverallRankTrialProgress(highestPassedRank: .initiate, attempts: [])

    var currentRank: RankTitle { highestPassedRank }

    /// Canonical "prior rank gates answered" count, derived from the
    /// authoritative monotonic `highestPassedRank` - NEVER the attempt log.
    /// The store trims `attempts` to a 50-entry tail, so a user with many
    /// retries/failures could otherwise scroll early gate passes out of the log
    /// and permanently, unrecoverably lose the final gate's `gatesAnswered` key.
    /// A confirmed rank R implies its gate and every earlier gate were answered,
    /// so counting from `highestPassedRank` can never regress. Excludes the
    /// final gate - this counts the gates that must precede it. Single source
    /// for both the `gatesAnswered` gate key and the Home deck's gate tally.
    var answeredGateCount: Int {
        OverallRankTrialDefinitions.all
            .filter { $0.format != .theLastGate }
            .filter { $0.targetRank.overallRankTrialOrder <= highestPassedRank.overallRankTrialOrder }
            .count
    }

    func latestAttempt(for definition: OverallRankTrialDefinition) -> OverallRankTrialAttempt? {
        attempts
            .filter { definition.matchesAttemptDefinitionId($0.definitionId) }
            .sorted { $0.completedAt > $1.completedAt }
            .first
    }

    /// Conservative union used by the cloud restore + sign-in migration paths.
    /// NEVER regresses: the higher `highestPassedRank` wins and attempts are
    /// unioned by id (self wins on an id collision), so a stale server copy can
    /// never lower a local rank or drop a locally-recorded attempt. Trimmed to
    /// the same 50-attempt tail the store keeps.
    func mergedNeverRegressing(with other: OverallRankTrialProgress) -> OverallRankTrialProgress {
        var byId: [String: OverallRankTrialAttempt] = [:]
        for attempt in other.attempts { byId[attempt.id] = attempt }
        for attempt in attempts { byId[attempt.id] = attempt }
        let mergedAttempts = byId.values.sorted { $0.completedAt < $1.completedAt }
        let higherRank = highestPassedRank.overallRankTrialOrder >= other.highestPassedRank.overallRankTrialOrder
            ? highestPassedRank
            : other.highestPassedRank
        return OverallRankTrialProgress(
            highestPassedRank: higherRank,
            attempts: Array(mergedAttempts.suffix(50))
        )
    }
}

extension OverallRankTrialDefinition {
    func matchesAttemptDefinitionId(_ definitionId: String) -> Bool {
        id == definitionId || legacyIds.contains(definitionId)
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
    static let shared = OverallRankTrialStore(backup: RankProgressCloudBackup.shared)

    private let defaults: UserDefaults
    private let keyPrefix = "unbound.overallRankTrials."
    /// Optional cloud mirror. The production `.shared` store wires the real
    /// backup; test-constructed stores get `nil` so unit tests never touch the
    /// outbox / SyncedDatabase. Local UserDefaults stays the source of truth.
    private let backup: (any RankProgressBackuping)?

    init(defaults: UserDefaults = .standard, backup: (any RankProgressBackuping)? = nil) {
        self.defaults = defaults
        self.backup = backup
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
        // Mirror the freshly recorded progress onto the synced `users` doc so a
        // reinstall restores the real rank. Fire-and-forget through the outbox;
        // failures are logged, never silenced. Local remains authoritative.
        backup?.backupTrials(progress, userId: userId)
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
    let equipment: Set<MovementEquipment>
    let clearedGateKeys: Set<String>
    /// Movement-tier pool behind the `movementsAtRank` key, used for progress
    /// copy ("3 of 5"); empty when the caller didn't compute it.
    let gateKeyMovementTiers: [RankTier]
    let attempts: [OverallRankTrialAttempt]

    init(
        userId: String,
        currentRank: RankTitle,
        overallLevel: Int,
        equipment: Set<MovementEquipment> = [.bodyweight],
        clearedGateKeys: Set<String>,
        gateKeyMovementTiers: [RankTier] = [],
        attempts: [OverallRankTrialAttempt] = []
    ) {
        self.userId = userId
        self.currentRank = currentRank
        self.overallLevel = overallLevel
        self.equipment = equipment
        self.clearedGateKeys = clearedGateKeys
        self.gateKeyMovementTiers = gateKeyMovementTiers
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
