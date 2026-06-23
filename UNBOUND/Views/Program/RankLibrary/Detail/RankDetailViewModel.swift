import SwiftUI

/// The single view model behind the unified rank-detail screen. It resolves a
/// library row (or a skill-tree node) into the identity + per-tab derived data
/// that `RankDetailView` and its four tabs render.
///
/// A row that maps to a logged `MovementDefinition` becomes a `.exercise`
/// (ruler-logged, strength-ratio ladder). A pure skill node with no movement
/// stays a `.skill` (session-logged, tierCriteria ladder).
@Observable
final class RankDetailViewModel {
    enum Kind {
        case skill
        case exercise
    }

    // MARK: Identity (resolved in init)

    let kind: Kind
    let title: String
    let visualAssetName: String?
    var displayedTier: SkillTier
    var tint: Color { displayedTier.rewardTextTint }
    let skillNode: SkillNode?
    let movementDefinition: MovementDefinition?
    let row: ProgramRankLibraryRow?
    let graph: SkillGraph
    let nodeStates: [String: NodeState]

    /// True when this entry is a skill (logs + ranks by its OWN criterion via the
    /// session flow + tierCriteria ladder). False for an exercise (logs via the
    /// ruler + ranks by the movement's strength ladder). This is the single source
    /// of truth for logging/ranking behavior — NOT whether a `MovementDefinition`
    /// happens to resolve. A skill often maps to a (reps-templated) movement for
    /// the muscle map + equipment, but must never inherit a reps ruler from it.
    let isSkillEntry: Bool

    // MARK: Loaded async

    var progress: MovementProgressState?
    var history: [ProgramRankExerciseHistoryEntry] = []
    var userProfile: UserProfile?
    var isLoading: Bool = true

    // MARK: Derived, per-tab ready

    var statItems: [RankStatItem] = []
    var formCues: [String] = []
    var commonMistakes: [String] = []
    var assistance: [SkillGuideAssistance] = []
    var tips: [SkillGuideTip] = []

    // MARK: Logging

    /// True when a `MovementDefinition` resolved — the screen logs via the ruler.
    /// False for pure skills, which log session-based via the skill flow.
    let loggingIsRulerBased: Bool

    /// Ruler selections, owned here so the Overview tab stays a thin renderer.
    /// Seeded from the user's best on the first `load`, then driven by the rails.
    var selectedWeightDisplay: Double = 0
    var selectedReps: Int = 1
    var selectedSeconds: Int = 30
    var isSubmitting: Bool = false

    /// Has `load` seeded the ruler from the user's best yet? Only seed once so a
    /// reload after a successful attempt doesn't stomp the user's selection.
    private var hasSeededRuler = false

    /// The metric the ruler captures. Exercises derive it from the movement's
    /// rank template; skills derive it from their node target (reps vs timed
    /// hold) so they log on the SAME inline ruler — never a 1RM weight ruler.
    /// `.oneRepMax` is the defensive default for an exercise with no movement.
    var logMode: ProgramRankExerciseLogMode {
        if isSkillEntry, let node = skillNode {
            return Self.skillLogMode(for: node)
        }
        return movementDefinition.map(ProgramRankExerciseLogMode.mode(for:)) ?? .oneRepMax
    }

    /// Maps a skill node's target to the ruler metric. Hold/carry skills log a
    /// timed hold; everything else logs reps (the criterion the skill ranks on).
    static func skillLogMode(for node: SkillNode) -> ProgramRankExerciseLogMode {
        switch node.target {
        case .hold, .carry:
            return .hold
        case .reps, .steps, .weightMultiplier:
            return .reps
        case .composite(let reqs):
            let hasHold = reqs.contains { requirement in
                if case .hold = requirement { return true }
                if case .carry = requirement { return true }
                return false
            }
            return hasHold ? .hold : .reps
        }
    }

    var weightUnit: TrainingWeightUnit {
        WeightPlatePolicy.currentUnit
    }

    var canSubmitRuler: Bool {
        switch logMode {
        case .oneRepMax: return selectedWeightDisplay > 0
        case .reps:      return selectedReps > 0
        case .hold:      return selectedSeconds > 0
        }
    }

    private var selectedWeightKg: Double? {
        guard selectedWeightDisplay > 0 else { return nil }
        return weightUnit.kilograms(fromDisplayValue: selectedWeightDisplay)
    }

    // MARK: - Init from a library row

    @MainActor
    init(row: ProgramRankLibraryRow) {
        let resolvedDefinition = Self.resolveDefinition(
            sourceId: row.sourceId,
            title: row.title,
            source: row.source
        )
        let resolvedNode = Self.resolveNode(for: row, definition: resolvedDefinition)
        let isSkill = row.source == .skill

        self.row = row
        self.graph = SkillGraph.shared
        self.nodeStates = SkillProgressService.shared.nodeStates
        self.skillNode = resolvedNode
        self.movementDefinition = resolvedDefinition
        self.isSkillEntry = isSkill
        // Entry type drives everything: a skill ranks + logs by its own criterion,
        // an exercise by the movement. The movement is still kept resolved (for the
        // Overview muscle map + equipment) but never makes a skill ruler-based.
        self.kind = isSkill ? .skill : .exercise
        self.loggingIsRulerBased = !isSkill && (resolvedDefinition != nil)
        self.title = isSkill ? row.title : (resolvedDefinition?.displayName ?? row.title)
        self.visualAssetName = row.visualAssetName
        self.displayedTier = row.tier
        let rowCoaching = Self.resolveCoaching(definition: resolvedDefinition, node: resolvedNode)
        self.formCues = rowCoaching.cues
        self.commonMistakes = rowCoaching.mistakes
        let rowExtras = Self.resolveGuideExtras(definition: resolvedDefinition, node: resolvedNode)
        self.assistance = rowExtras.assistance
        self.tips = rowExtras.tips
    }

    // MARK: - Init from a skill-tree node

    init(node: SkillNode, graph: SkillGraph, nodeStates: [String: NodeState]) {
        let resolvedDefinition = Self.definition(forSkillNode: node)
        let earnedTier = node.placementRank

        self.row = nil
        self.graph = graph
        self.nodeStates = nodeStates
        self.skillNode = node
        self.movementDefinition = resolvedDefinition
        // A skill-tree node is always a skill: session-logged, tierCriteria ladder.
        // The movement (if any) stays resolved only for the muscle map + equipment.
        self.isSkillEntry = true
        self.kind = .skill
        self.loggingIsRulerBased = false
        self.title = node.title
        self.visualAssetName = SkillTraditionalVisualResolver.assetName(for: node)
        self.displayedTier = earnedTier
        let nodeCoaching = Self.resolveCoaching(definition: resolvedDefinition, node: node)
        self.formCues = nodeCoaching.cues
        self.commonMistakes = nodeCoaching.mistakes
        let nodeExtras = Self.resolveGuideExtras(definition: resolvedDefinition, node: node)
        self.assistance = nodeExtras.assistance
        self.tips = nodeExtras.tips
    }

    // MARK: - Async load

    @MainActor
    func load(services: ServiceContainer) async {
        guard let userId = services.auth.currentUserId else {
            isLoading = false
            return
        }

        isLoading = true

        async let progressLoad: [MovementProgressState] = services.database.query(
            collection: "movement_progress",
            field: "userId",
            isEqualTo: userId,
            orderBy: nil,
            descending: true,
            limit: nil
        )
        async let logLoad: [PerformanceLog] = services.database.query(
            collection: "performanceLogs",
            field: "userId",
            isEqualTo: userId,
            orderBy: "completedAt",
            descending: true,
            limit: 80
        )
        async let profileLoad: UserProfile? = services.database.read(
            collection: "users",
            documentId: userId
        )

        let progressStates = (try? await progressLoad) ?? []
        let logs = (try? await logLoad) ?? []
        userProfile = try? await profileLoad

        if let standardId = movementDefinition?.rankStandardMovementId {
            progress = progressStates.first { $0.rankStandardMovementId == standardId }
            history = ProgramRankExerciseHistoryEntry.entries(
                from: logs,
                rankStandardMovementId: standardId
            )
        }

        statItems = Self.statItems(for: progress)

        // Re-derive the displayed tier from the freshly loaded state so a
        // just-logged rank-up updates the showcase emblem. The init-time value is
        // computed from the original tier and would otherwise stay stale. Split by
        // entry type: exercises rank from movement progress, skills from their
        // persisted skill tier.
        if !isSkillEntry, let progress {
            // EXERCISE/ruler case: re-derive from the loaded MovementProgressState.
            if let proven = resolvedTier(for: progress), proven.rawValue > displayedTier.rawValue {
                displayedTier = proven
            }
        } else if isSkillEntry, let node = skillNode {
            // SKILL case: re-derive from the skill's CURRENT persisted tier (same
            // source ProgramRankLibraryView uses), so a quick log that just ranked
            // this skill up updates the showcase when the detail reloads.
            let skillTier = UserSkillTierStore.shared.load(userId: userId).tier(for: node.id)
            if skillTier.rawValue > displayedTier.rawValue {
                displayedTier = skillTier
            }
        }

        if loggingIsRulerBased, !hasSeededRuler {
            seedRuler(from: progress)
            hasSeededRuler = true
        } else if isSkillEntry, !hasSeededRuler, let node = skillNode {
            seedSkillRuler(for: node)
            hasSeededRuler = true
        }

        isLoading = false
    }

    /// Seed the inline ruler for a skill from its node target, so the reps /
    /// hold ruler opens at the criterion value instead of a bare default.
    private func seedSkillRuler(for node: SkillNode) {
        switch node.target {
        case .reps(_, let count, _), .steps(_, let count):
            selectedReps = max(1, count)
        case .hold(_, let seconds), .carry(_, let seconds, _):
            selectedSeconds = max(5, seconds)
        case .weightMultiplier:
            selectedReps = max(1, selectedReps)
        case .composite(let reqs):
            for requirement in reqs {
                if case .reps(_, let count, _) = requirement { selectedReps = max(1, count) }
                if case .steps(_, let count) = requirement { selectedReps = max(1, count) }
                if case .hold(_, let seconds) = requirement { selectedSeconds = max(5, seconds) }
                if case .carry(_, let seconds, _) = requirement { selectedSeconds = max(5, seconds) }
            }
        }
    }

    // MARK: - Ruler logging (exercise case)

    private func seedRuler(from progress: MovementProgressState?) {
        selectedReps = max(1, progress?.bestReps ?? 10)
        switch logMode {
        case .oneRepMax:
            if let oneRepMax = progress?.bestEstimatedOneRepMaxKg ?? progress?.bestLoadKg {
                selectedWeightDisplay = WeightPlatePolicy.editingValue(fromKilograms: oneRepMax, unit: weightUnit)
            } else if movementDefinition?.rankTemplate == .weightedBodyweight {
                selectedWeightDisplay = 0
            } else {
                selectedWeightDisplay = weightUnit == .pounds ? 135 : 60
            }
        case .reps, .hold:
            selectedWeightDisplay = 0
        }
        selectedSeconds = progress?.bestHoldSeconds ?? progress?.bestDurationSeconds ?? 30
    }

    func weightRulerConfig(allowsBodyweight: Bool) -> ProgramRankWeightRulerConfig {
        let step = WeightPlatePolicy.loadIncrement(unit: weightUnit)
        let majorIncrement: Double = weightUnit == .pounds ? 25 : 10
        let start: Double
        let baseEnd: Double

        if movementDefinition?.rankTemplate == .weightedBodyweight {
            start = allowsBodyweight ? 0 : step
            baseEnd = weightUnit == .pounds ? 300 : 140
        } else {
            start = weightUnit == .pounds ? 45 : 20
            baseEnd = weightUnit == .pounds ? 1_000 : 450
        }
        let selectedEnd = selectedWeightDisplay > 0
            ? (ceil((selectedWeightDisplay + majorIncrement * 2) / majorIncrement) * majorIncrement)
            : baseEnd
        let end = max(baseEnd, selectedEnd)

        return ProgramRankWeightRulerConfig(
            start: start,
            end: end,
            step: step,
            majorDisplayIncrement: majorIncrement
        )
    }

    func formatDisplayWeight(_ value: Double) -> String {
        "\(WeightPlatePolicy.formatDisplayValue(value))\(weightUnit.shortLabel)"
    }

    var addedLoadSummary: String {
        selectedWeightDisplay > 0 ? "+\(formatDisplayWeight(selectedWeightDisplay))" : "Bodyweight only"
    }

    var logSummary: String {
        switch logMode {
        case .oneRepMax:
            if movementDefinition?.rankTemplate == .weightedBodyweight {
                return "Added 1RM \(addedLoadSummary)"
            }
            return "1RM \(formatDisplayWeight(selectedWeightDisplay))"
        case .reps:
            return "\(selectedReps) reps"
        case .hold:
            return "\(ProgramRankExerciseFormatter.seconds(selectedSeconds)) hold"
        }
    }

    /// Logs the current ruler selection as a single rank attempt and returns the
    /// reveal to animate (rank-up or hold). Returns `nil` on validation failure;
    /// throws on a save error so the caller can surface a retry alert.
    @MainActor
    func submitLog(services: ServiceContainer) async throws -> ProgramRankAttemptReveal? {
        guard !isSubmitting else { return nil }
        guard let definition = movementDefinition, canSubmitRuler else { return nil }
        guard let userId = services.auth.currentUserId else { return nil }

        isSubmitting = true
        defer { isSubmitting = false }

        let now = Date()
        let priorTier = displayedTier
        let performanceLog = makePerformanceLog(definition: definition, userId: userId, completedAt: now)

        let result = try await TrainingCompletionService.shared.complete(performanceLog, services: services)
        let reveal = makeRankReveal(from: result, definition: definition, priorTier: priorTier)
        await load(services: services)
        return reveal
    }

    private static let skillQuickLogXP: Int = 10

    /// Logs the current ruler selection as a single skill set and returns the
    /// reveal to animate. Skills rank by their OWN criterion through the shared
    /// completion service (the single source) — the same inline ruler as an
    /// exercise, never a strength ladder and never a separate session.
    @MainActor
    func submitSkillLog(services: ServiceContainer) async throws -> ProgramRankAttemptReveal? {
        guard !isSubmitting, let node = skillNode, canSubmitRuler else { return nil }
        guard let userId = services.auth.currentUserId else { return nil }

        isSubmitting = true
        defer { isSubmitting = false }

        let isHold = (logMode == .hold)
        let now = Date()
        let priorTier = displayedTier

        // Just the metric — an honest, clean single set.
        let set = LoggedSet(
            reps: isHold ? 0 : selectedReps,
            holdSeconds: isHold ? selectedSeconds : nil,
            weightKg: nil,
            rpe: nil,
            qualityFlags: [.clean],
            notes: nil
        )
        let performanceLog = TrainingSessionAdapters.performanceLogForSkillSession(
            id: "rank-skill-log-\(UUID().uuidString)",
            userId: userId,
            skillId: node.id,
            skillTitle: node.title,
            startedAt: now,
            completedAt: now,
            durationSeconds: 0,
            exercises: [LoggedExercise(name: node.title, sets: [set])]
        )

        _ = try await TrainingCompletionService.shared.complete(
            performanceLog,
            services: services,
            skillXPAwarded: Self.skillQuickLogXP
        )

        // Per-set badge unlocks (parity with the prior quick-log path).
        let triggerKey = isHold ? "\(node.id).hold" : node.id
        let triggerReps = isHold ? selectedSeconds : selectedReps
        _ = await services.badges.evaluate(
            trigger: .setCompleted(exerciseKey: triggerKey, reps: triggerReps)
        )

        // load() re-derives `displayedTier` from the skill's persisted tier.
        await load(services: services)
        return ProgramRankAttemptReveal(
            attemptSummary: logSummary,
            tier: displayedTier,
            previousTier: priorTier
        )
    }

    private func makePerformanceLog(
        definition: MovementDefinition,
        userId: String,
        completedAt: Date
    ) -> PerformanceLog {
        let set = PerformanceSet(
            setNumber: 1,
            reps: logMode.recordsReps ? selectedReps : logMode.recordsOneRepMax ? 1 : nil,
            weightKg: logMode.recordsOneRepMax ? selectedWeightKg : nil,
            holdSeconds: logMode == .hold ? selectedSeconds : nil,
            durationSeconds: nil,
            distanceMeters: nil,
            calories: nil,
            rpe: nil,
            qualityFlags: [],
            notes: nil
        )
        let exercise = PerformanceExercise(
            name: definition.displayName,
            movementId: definition.id,
            rankStandardMovementId: definition.rankStandardMovementId,
            plannedSets: 1,
            plannedTarget: logSummary,
            sets: [set],
            notes: nil
        )
        let block = PerformanceBlock(
            kind: definition.blockKind,
            title: definition.displayName,
            exercises: [exercise],
            durationSeconds: nil,
            distanceMeters: nil,
            calories: nil,
            notes: "Single rank attempt"
        )
        return PerformanceLog(
            id: "rank-log-\(UUID().uuidString)",
            userId: userId,
            source: .custom,
            title: "\(definition.displayName) Rank Attempt",
            startedAt: completedAt,
            completedAt: completedAt,
            blocks: [block],
            overallRPE: nil,
            notes: nil
        )
    }

    private func makeRankReveal(
        from result: TrainingCompletionResult,
        definition: MovementDefinition,
        priorTier: SkillTier
    ) -> ProgramRankAttemptReveal {
        let standardId = definition.rankStandardMovementId
        let updatedProgress = result.movementProgressStates.first { $0.rankStandardMovementId == standardId }
        let previousTier = resolvedTier(for: result.movementProgressPriorStates[standardId]) ?? priorTier
        let achievedTier = resolvedTier(for: updatedProgress)
            ?? resolvedTier(for: result.movementProgressPriorStates[standardId])
            ?? priorTier
        return ProgramRankAttemptReveal(
            attemptSummary: logSummary,
            tier: achievedTier,
            previousTier: previousTier
        )
    }

    private func resolvedTier(for state: MovementProgressState?) -> SkillTier? {
        guard let state else { return nil }
        return MovementProgressTierResolver.provenTier(
            for: state,
            bodyweightKg: userProfile?.weightKg,
            sex: userProfile?.biologicalSex
        )
    }

    // MARK: - Resolution helpers

    private static func resolveDefinition(
        sourceId: String,
        title: String,
        source: ProgramRankLibrarySource
    ) -> MovementDefinition? {
        MovementCatalog.definition(for: sourceId)
            ?? MovementCatalog.resolvedTrainingMovement(name: title)?.standard
    }

    private static func resolveNode(
        for row: ProgramRankLibraryRow,
        definition: MovementDefinition?
    ) -> SkillNode? {
        if row.source == .skill, let node = SkillGraph.shared.node(id: row.sourceId) {
            return node
        }
        if let skillId = definition?.skillId {
            return SkillGraph.shared.node(id: skillId)
        }
        return nil
    }

    private static func definition(forSkillNode node: SkillNode) -> MovementDefinition? {
        MovementCatalog.definition(for: node.id)
            ?? MovementCatalog.resolvedTrainingMovement(name: node.title)?.standard
    }

    /// Form cues + common mistakes for the Overview tab. Precedence:
    ///   1. Exercise-specific authored coaching (e.g. "bench press"), so a
    ///      barbell lift shows its own cues rather than a borrowed skill link's.
    ///   2. The skill node's own authored cues (skills keep their content).
    ///   3. A movement-pattern fallback for unlinked gym lifts.
    private static func resolveCoaching(
        definition: MovementDefinition?,
        node: SkillNode?
    ) -> (cues: [String], mistakes: [String]) {
        if let definition, let specific = MovementCoaching.specificEntry(for: definition) {
            return (specific.cues, specific.mistakes)
        }
        if let node {
            return (node.formCues, node.commonMistakes)
        }
        if let definition, let pattern = MovementCoaching.patternEntry(for: definition) {
            return (pattern.cues, pattern.mistakes)
        }
        return ([], [])
    }

    /// Curated "assist" (regressions / how to scale) and "tips" (technique
    /// notes) for the guide's Assist + Tips segments. Comes only from the
    /// hand-authored `SkillGuideLibrary`, keyed by the skill node id (skills)
    /// or the movement's explicit `skillId` (exercises). Nil for unlinked lifts.
    private static func resolveGuideExtras(
        definition: MovementDefinition?,
        node: SkillNode?
    ) -> (assistance: [SkillGuideAssistance], tips: [SkillGuideTip]) {
        let guideId = node?.id ?? definition?.skillId
        guard let guideId, let guide = SkillGuideLibrary.guide(for: guideId) else { return ([], []) }
        return (guide.assistance, guide.tips)
    }

    // MARK: - Stats

    private static func statItems(for progress: MovementProgressState?) -> [RankStatItem] {
        guard let progress else { return [] }
        let unit = WeightPlatePolicy.currentUnit
        var items: [RankStatItem] = []

        if let oneRepMax = progress.bestEstimatedOneRepMaxKg {
            items.append(RankStatItem(
                id: "best-1rm",
                label: "Best 1RM",
                value: "\(WeightPlatePolicy.formatLoggedWeight(oneRepMax, unit: unit))\(unit.shortLabel)",
                systemImage: "trophy.fill"
            ))
        }
        if let load = progress.bestLoadKg {
            items.append(RankStatItem(
                id: "best-load",
                label: "Best Load",
                value: "\(WeightPlatePolicy.formatLoggedWeight(load, unit: unit))\(unit.shortLabel)",
                systemImage: "scalemass.fill"
            ))
        }
        if let reps = progress.bestReps {
            items.append(RankStatItem(
                id: "best-reps",
                label: "Best Reps",
                value: "\(reps)",
                systemImage: "repeat"
            ))
        }
        if let hold = progress.bestHoldSeconds ?? progress.bestDurationSeconds {
            items.append(RankStatItem(
                id: "best-hold",
                label: "Best Hold",
                value: ProgramRankExerciseFormatter.seconds(hold),
                systemImage: "timer"
            ))
        }
        items.append(RankStatItem(
            id: "total-ap",
            label: "Accumulated",
            value: "\(Int(progress.totalAP.rounded())) XP",
            systemImage: "bolt.fill"
        ))
        if let lastLogged = progress.lastLoggedAt {
            items.append(RankStatItem(
                id: "last-logged",
                label: "Last Logged",
                value: lastLogged.formatted(.dateTime.month(.abbreviated).day()),
                systemImage: "calendar"
            ))
        }
        return items
    }

}
