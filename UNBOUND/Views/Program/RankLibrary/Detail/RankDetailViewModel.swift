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
            // Weighted skills (added-load criterion, e.g. weighted pull-up) log
            // on the SAME weight ruler as a weighted exercise — the load is what
            // sets the rank. Everything else logs reps or a timed hold.
            if skillIsWeightBased { return .oneRepMax }
            return Self.skillLogMode(for: node)
        }
        return movementDefinition.map(ProgramRankExerciseLogMode.mode(for:)) ?? .oneRepMax
    }

    /// A skill that ranks by ADDED LOAD (weighted pull-up, weighted dip, …). Needs
    /// a resolved movement twin so the weight ruler has a template to configure.
    var skillIsWeightBased: Bool {
        guard isSkillEntry, let node = skillNode, movementDefinition != nil else { return false }
        return Self.targetIsWeightBased(node.target)
    }

    private static func targetIsWeightBased(_ requirement: NodeRequirement) -> Bool {
        switch requirement {
        case .weightMultiplier:
            return true
        case .composite(let reqs):
            return reqs.contains { targetIsWeightBased($0) }
        default:
            return false
        }
    }

    /// The node's own movement — the first exercise its target names. Used to
    /// name-gate per-attempt grading (`SkillStandards.nodeProgress`) so an
    /// authored variant ladder can't grade this screen's raw reps as another
    /// variant's rung.
    private static func targetExerciseName(_ requirement: NodeRequirement) -> String? {
        switch requirement {
        case .weightMultiplier(let exercise, _),
             .reps(let exercise, _, _),
             .hold(let exercise, _),
             .steps(let exercise, _),
             .carry(let exercise, _, _):
            return exercise
        case .composite(let reqs):
            return reqs.compactMap { targetExerciseName($0) }.first
        }
    }

    /// Maps a skill node's target to the ruler metric. Hold/carry skills log a
    /// timed hold; everything else logs reps (the criterion the skill ranks on).
    /// Weighted skills are handled earlier in `logMode` (the weight ruler).
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
        // Start neutral; the user's real EARNED tier is resolved in `load()` from
        // their persisted skill tier. The node's `placementRank` is its tree
        // difficulty, NOT the user's current rank — never show it as such.
        self.displayedTier = .initiate
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

        if isSkillEntry, let node = skillNode {
            // Skills read their OWN logged attempts (keyed by the block's skillId),
            // never a reps-templated movement twin — so a hold skill surfaces its
            // holds instead of "0 reps", and its PRs come from real skill data.
            history = ProgramRankExerciseHistoryEntry.entries(from: logs, skillId: node.id)
            if let standardId = movementDefinition?.rankStandardMovementId {
                progress = progressStates.first { $0.rankStandardMovementId == standardId }
            }
        } else if let standardId = movementDefinition?.rankStandardMovementId {
            progress = progressStates.first { $0.rankStandardMovementId == standardId }
            history = ProgramRankExerciseHistoryEntry.entries(
                from: logs,
                rankStandardMovementId: standardId
            )
        }

        statItems = isSkillEntry
            ? Self.skillStatItems(history: history, logMode: logMode)
            : Self.statItems(for: progress)

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
    /// hold / weight ruler opens at a sensible value instead of a bare default.
    private func seedSkillRuler(for node: SkillNode) {
        // Weighted skills open the weight ruler at a modest added load.
        if skillIsWeightBased {
            selectedWeightDisplay = weightUnit == .pounds ? 25 : 10
            return
        }
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

    // MARK: - Per-attempt grade

    /// The rank THIS attempt's effort earns, graded in isolation — independent of
    /// the sticky best. Drives the per-attempt reveal so logging the same movement
    /// over and over surfaces a different rank each time. Reads the SAME ladders
    /// the persisted tier is derived from (node tierCriteria for skills, the
    /// movement strength ladder for exercises), so the grade never drifts.
    func gradeForCurrentAttempt() -> SkillTier {
        // Bodyweight skill (reps / timed hold): grade against the node's own
        // generated tierCriteria — the single source SkillStandards reads.
        if isSkillEntry, !skillIsWeightBased, let node = skillNode {
            let peakReps = (logMode == .reps) ? selectedReps : 0
            let peakSeconds = (logMode == .hold) ? selectedSeconds : 0
            // This screen logs the node's OWN movement, so grade against the
            // rungs that name it. On authored variant ladders (ld.nordic-curl,
            // ...) a raw rep here must not grade as another variant's rung.
            return SkillStandards.nodeProgress(
                skillId: node.id,
                exerciseKey: Self.targetExerciseName(node.target),
                peakReps: peakReps,
                peakSeconds: peakSeconds
            )?.current ?? .initiate
        }
        // Exercise or weighted skill: grade against the movement's strength ladder
        // by resolving a transient single-attempt state (the resolver the sticky
        // tier also uses), so the grade matches what the log would credit.
        guard let definition = movementDefinition else { return .initiate }
        let attempt = MovementProgressState(
            userId: "",
            rankStandardMovementId: definition.rankStandardMovementId,
            displayName: definition.displayName,
            rankTemplate: definition.rankTemplate,
            bestEstimatedOneRepMaxKg: logMode == .oneRepMax ? selectedWeightKg : nil,
            bestReps: logMode == .reps ? selectedReps : nil,
            bestHoldSeconds: logMode == .hold ? selectedSeconds : nil
        )
        return MovementProgressTierResolver.derivedTier(
            for: attempt,
            bodyweightKg: userProfile?.weightKg,
            sex: userProfile?.biologicalSex
        ) ?? .initiate
    }

    // MARK: - Prerequisites (skill entries)

    /// A resolved prerequisite skill for the Overview tab — the node and whether
    /// the user has already proven it.
    struct PrereqItem: Identifiable {
        let id: String
        let title: String
        let isProven: Bool
    }

    /// Prerequisite groups resolved to displayable items. Each inner array is one
    /// AND-group (all required); multiple arrays are OR-alternatives ("any one
    /// path"). Empty for entry nodes, exercises, or when no prereq id resolves to
    /// a graph node. Drives the Overview's PREREQUISITES section.
    var prerequisiteGroups: [[PrereqItem]] {
        guard isSkillEntry, let node = skillNode else { return [] }
        return node.prereqs.compactMap { group -> [PrereqItem]? in
            let items = group.nodeIds.compactMap { id -> PrereqItem? in
                guard let prereqNode = graph.node(id: id) else { return nil }
                return PrereqItem(
                    id: id,
                    title: prereqNode.title,
                    isProven: (nodeStates[id] ?? .locked) == .proven
                )
            }
            return items.isEmpty ? nil : items
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
        let attemptGrade = gradeForCurrentAttempt()
        let attemptSummary = logSummary
        let performanceLog = makePerformanceLog(definition: definition, userId: userId, completedAt: now)

        _ = try await TrainingCompletionService.shared.complete(performanceLog, services: services)
        await load(services: services)
        return ProgramRankAttemptReveal(
            attemptSummary: attemptSummary,
            tier: attemptGrade,
            previousTier: priorTier
        )
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
        let isWeighted = (logMode == .oneRepMax)
        let now = Date()
        let priorTier = displayedTier
        let attemptGrade = gradeForCurrentAttempt()
        let attemptSummary = logSummary

        // Just the metric — an honest, clean single set. Weighted skills record
        // a single rep at the added load (the value the rank is read from).
        let set = LoggedSet(
            reps: isHold ? 0 : (isWeighted ? 1 : selectedReps),
            holdSeconds: isHold ? selectedSeconds : nil,
            weightKg: isWeighted ? selectedWeightKg : nil,
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
            attemptSummary: attemptSummary,
            tier: attemptGrade,
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
            // Skill rows fall back to the canonical "skill.<id>" movement so the
            // Overview's Target Map + Equipment populate (see definition(forSkillNode:)).
            ?? (source == .skill ? MovementCatalog.definition(for: "skill.\(sourceId)") : nil)
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
        // The canonical "skill.<id>" movement carries the node's muscle map +
        // equipment, but the bare-id lookup always misses (skill defs are keyed
        // "skill.<id>"). Without this fallback a skill that didn't alias-match a
        // catalog exercise resolved no definition, so the Overview's Target Map
        // and Equipment sections silently vanished. Kept LAST so weighted skills
        // still resolve their loaded exercise twin first (the weight ruler needs it).
        MovementCatalog.definition(for: node.id)
            ?? MovementCatalog.resolvedTrainingMovement(name: node.title)?.standard
            ?? MovementCatalog.definition(for: "skill.\(node.id)")
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

    /// PRs for a SKILL, derived from its own logged attempts. A skill ranks on
    /// its own criterion (reps / a timed hold), so its records come straight from
    /// the attempt history — not from a reps-templated movement twin that would
    /// report "0 reps" for a hold.
    private static func skillStatItems(
        history: [ProgramRankExerciseHistoryEntry],
        logMode: ProgramRankExerciseLogMode
    ) -> [RankStatItem] {
        guard !history.isEmpty else { return [] }
        switch logMode {
        case .hold:
            guard let best = history.compactMap(\.holdSeconds).filter({ $0 > 0 }).max() else { return [] }
            return [RankStatItem(
                id: "best-hold",
                label: "Best Hold",
                value: ProgramRankExerciseFormatter.seconds(best),
                systemImage: "timer"
            )]
        case .reps:
            guard let best = history.compactMap(\.reps).filter({ $0 > 0 }).max() else { return [] }
            return [RankStatItem(id: "best-reps", label: "Best Reps", value: "\(best)", systemImage: "repeat")]
        case .oneRepMax:
            guard let best = history.compactMap(\.oneRepMaxKg).max() else { return [] }
            let unit = WeightPlatePolicy.currentUnit
            return [RankStatItem(
                id: "best-1rm",
                label: "Best 1RM",
                value: "\(WeightPlatePolicy.formatLoggedWeight(best, unit: unit))\(unit.shortLabel)",
                systemImage: "trophy.fill"
            )]
        }
    }

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
