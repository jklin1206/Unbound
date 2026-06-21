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

    var nextGateText: String?
    var ladderRows: [RankLadderRow] = []
    var statItems: [RankStatItem] = []
    var formCues: [String] = []

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

    /// The metric the ruler captures, derived from the movement's rank template.
    /// `.oneRepMax` when there's no movement (defensive default — the ruler only
    /// shows for `loggingIsRulerBased`, where a definition always exists).
    var logMode: ProgramRankExerciseLogMode {
        movementDefinition.map(ProgramRankExerciseLogMode.mode(for:)) ?? .oneRepMax
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
        self.formCues = resolvedNode?.formCues ?? []
        self.ladderRows = Self.ladderRows(
            // Skill entries climb the SKILL ladder (skillNode); exercise entries the
            // STRENGTH ladder (movement). Pass node: nil for exercises so a happened-
            // to-resolve skillNode can never pull them onto a tierCriteria ladder.
            node: isSkill ? resolvedNode : nil,
            definition: resolvedDefinition,
            earnedTier: row.tier,
            isEarned: row.isEarned,
            isRankHidden: row.isRankHidden
        )
        self.nextGateText = Self.nextGateText(
            node: isSkill ? resolvedNode : nil,
            definition: resolvedDefinition,
            currentTier: row.isEarned ? row.tier : nil
        )
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
        self.formCues = node.formCues
        self.ladderRows = Self.ladderRows(
            node: node,
            definition: resolvedDefinition,
            earnedTier: earnedTier,
            isEarned: earnedTier > .initiate,
            isRankHidden: node.earnedRankIsBelowFloor(earnedTier)
        )
        self.nextGateText = Self.nextGateText(
            node: node,
            definition: resolvedDefinition,
            currentTier: earnedTier > .initiate ? earnedTier : nil
        )
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

        // Re-derive the rank-dependent display from the freshly loaded state so a
        // just-logged rank-up actually climbs the ladder. The init-time values are
        // computed from the original tier and would otherwise stay stale, leaving
        // the climb frozen after a successful log. Split by entry type: exercises
        // rank from movement progress, skills from their persisted skill tier.
        if !isSkillEntry, let progress {
            // EXERCISE/ruler case: re-derive from the loaded MovementProgressState.
            if let proven = resolvedTier(for: progress), proven.rawValue > displayedTier.rawValue {
                displayedTier = proven
            }
            let earned = displayedTier > .initiate || progress.totalAP > 0
            ladderRows = Self.ladderRows(
                node: nil,
                definition: movementDefinition,
                earnedTier: displayedTier,
                isEarned: earned,
                isRankHidden: false
            )
            nextGateText = Self.nextGateText(
                node: nil,
                definition: movementDefinition,
                currentTier: earned ? displayedTier : nil
            )
        } else if isSkillEntry, let node = skillNode {
            // SKILL case: re-derive from the skill's CURRENT persisted tier (same
            // source ProgramRankLibraryView uses), so a session that just ranked
            // this skill up climbs the ladder when the detail reloads.
            let skillTier = UserSkillTierStore.shared.load(userId: userId).tier(for: node.id)
            if skillTier.rawValue > displayedTier.rawValue {
                displayedTier = skillTier
            }
            // Live nodeStates (the init snapshot can predate a just-run session).
            let proven = SkillProgressService.shared.nodeStates[node.id] == .proven
            let earned = proven || displayedTier > .initiate
            ladderRows = Self.ladderRows(
                node: node,
                definition: nil,
                earnedTier: displayedTier,
                isEarned: earned,
                isRankHidden: node.earnedRankIsBelowFloor(displayedTier)
            )
            nextGateText = Self.nextGateText(
                node: node,
                definition: nil,
                currentTier: earned ? displayedTier : nil
            )
        }

        if loggingIsRulerBased, !hasSeededRuler {
            seedRuler(from: progress)
            hasSeededRuler = true
        }

        isLoading = false
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

    // MARK: - Ladder

    private static func ladderRows(
        node: SkillNode?,
        definition: MovementDefinition?,
        earnedTier: SkillTier,
        isEarned: Bool,
        isRankHidden: Bool
    ) -> [RankLadderRow] {
        let base: [(tier: SkillTier, detail: String)]
        if let node {
            base = skillLadder(for: node)
        } else if let definition {
            base = strengthLadder(for: definition)
        } else {
            base = []
        }
        guard !base.isEmpty else { return [] }

        let visibleTiers = base.map(\.tier)
        let nextTarget = isEarned ? earnedTier.next : earnedTier
        let currentTier = nextTarget.flatMap { target in
            visibleTiers.first { $0.rawValue >= target.rawValue }
        }

        return base.map { candidate in
            let isCleared = isEarned
                && !isRankHidden
                && candidate.tier.rawValue <= earnedTier.rawValue
            let isCurrent = !isCleared && candidate.tier == currentTier
            let isNext = isCurrent
            return RankLadderRow(
                tier: candidate.tier,
                criteriaText: candidate.detail,
                isCleared: isCleared,
                isCurrent: isCurrent,
                isNext: isNext
            )
        }
    }

    private static func skillLadder(for node: SkillNode) -> [(tier: SkillTier, detail: String)] {
        SkillTier.allCases
            .filter { $0.rawValue >= node.rankFloor.rawValue }
            .map { tier in
                (
                    tier: tier,
                    detail: node.tierCriteria[tier].map(criterionSummary)
                        ?? node.target.displayName
                )
            }
    }

    private static func strengthLadder(for definition: MovementDefinition) -> [(tier: SkillTier, detail: String)] {
        let key = MovementCatalog.normalized(definition.canonicalExerciseName ?? definition.displayName)
        return SkillTier.allCases.compactMap { tier in
            guard let ratio = StrengthStandards.ratio(exerciseKey: key, tier: tier, sex: nil) else { return nil }
            let ratioText = String(format: "%.2g", ratio)
            let prefix = definition.rankTemplate == .weightedBodyweight ? "added load " : ""
            return (tier: tier, detail: "\(prefix)\(ratioText)x bodyweight")
        }
    }

    // MARK: - Next gate

    private static func nextGateText(
        node: SkillNode?,
        definition: MovementDefinition?,
        currentTier: SkillTier?
    ) -> String? {
        if let node {
            return RankBenchmarkSummary.nextBenchmark(for: node, currentTier: currentTier)
        }
        if let definition {
            let item = ExerciseLibraryItem(definition: definition)
            return RankBenchmarkSummary.nextBenchmark(for: item, currentTier: currentTier)
        }
        return nil
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

    // MARK: - Criterion formatting

    private static func criterionSummary(_ criterion: TierCriterion) -> String {
        switch criterion {
        case .reps(let count, let exerciseName):
            return "\(count) \(displayExerciseName(exerciseName))"
        case .seconds(let seconds):
            return "\(seconds)-second hold"
        case .exerciseSeconds(let seconds, let exerciseName):
            return "\(seconds)s \(displayExerciseName(exerciseName)) hold"
        case .weightKg(let weight):
            return "\(WeightPlatePolicy.formatLoggedWeightWithUnit(weight, separator: " ")) working set"
        case .exerciseWeightKg(let weight, let exerciseName):
            return "\(WeightPlatePolicy.formatLoggedWeightWithUnit(weight, separator: " ")) \(displayExerciseName(exerciseName))"
        case .bodyweightRatio(let ratio):
            return "\(String(format: "%.2g", ratio))x bodyweight"
        case .exerciseBodyweightRatio(let ratio, let exerciseName):
            return "\(String(format: "%.2g", ratio))x bodyweight \(displayExerciseName(exerciseName))"
        case .variant(let name):
            return "Log \(displayExerciseName(name))"
        case .compound(let criteria):
            return criteria.map(criterionSummary).joined(separator: " + ")
        }
    }

    private static func displayExerciseName(_ name: String) -> String {
        name
            .split(separator: " ")
            .map { part in
                part
                    .split(separator: "-")
                    .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                    .joined(separator: "-")
            }
            .joined(separator: " ")
    }
}
