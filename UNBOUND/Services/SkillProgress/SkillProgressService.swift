import Foundation
import Observation

// MARK: - SkillProgressService
//
// Computes skill-tree node states from the user's workout logs + any
// manual "I hit it" overrides. Exposes an @Observable snapshot for
// views. Persists UserSkillProgress in the local JSON store.
//
// State transitions (2-state model):
//   locked → proven : the node's target requirement is met by a log entry or
//                     a manual "I hit this" override. How GOOD the user is at a
//                     proven node is the per-skill earned RankTier, not state.
//
// Notification emits `NodeUnlockedEvent` when a node transitions to
// .proven — caller uses this to show the reveal overlay.

@Observable
@MainActor
final class SkillProgressService {

    // MARK: Singleton

    static let shared = SkillProgressService()

    // MARK: Published state

    /// Snapshot of node states keyed by nodeId. Views observe this.
    private(set) var nodeStates: [String: NodeState] = [:]

    /// Per-reachable-node fraction of the target hit by the user's best
    /// recent attempt. 0.0–1.0. Populated during recompute. Missing entries
    /// mean "no data yet" — render the hex without a fill.
    private(set) var nodeProgress: [String: Double] = [:]

    /// Mirror of `UserSkillProgress.bookmarkedNodeIds` for view binding.
    private(set) var bookmarkedNodeIds: Set<String> = []

    /// Mirror of `UserSkillProgress.activeGoalIds` for view binding.
    /// Product copy calls these Program Focuses. The stored field keeps its
    /// older name so existing user data does not need a migration.
    private(set) var activeGoalIds: Set<String> = []

    var programFocusIds: Set<String> { activeGoalIds }

    /// Mirror of `UserSkillProgress.weeklySchedule` for view binding.
    /// Index 0 = Monday, 6 = Sunday. `nil` entries fall back to
    /// `ProgramScheduler.defaultWeeklySchedule`. Observed by the Program
    /// tab so editing the schedule re-flows TODAY'S TRAINING + day strip.
    private(set) var weeklySchedule: [DayCategory?] = Array(repeating: nil, count: 7)

    /// V4 — mirror of `UserSkillProgress.currentWeekPhase` for view binding.
    /// Drives AI session prescriptions (heavy/moderate/light/deload).
    private(set) var currentWeekPhase: WeekPhase = .moderate

    /// The most recent unlock event — views show a reveal when this changes.
    var pendingUnlock: NodeUnlockedEvent? = nil

    // MARK: Dependencies

    private let database: DatabaseServiceProtocol
    private var logger: LoggingService { LoggingService.shared }
    private var currentUserId: String? { AuthService.shared.currentUserId }

    private var progress: UserSkillProgress?

    private init() {
        self.database = DatabaseService.shared
    }

    /// Test-only initializer. Production code must use `SkillProgressService.shared`.
    /// Lets tests inject a `MockDB`-style `DatabaseServiceProtocol` without
    /// mutating the singleton's state.
    internal init(database: DatabaseServiceProtocol) {
        self.database = database
    }

    // MARK: Public API

    /// Load the user's progress from disk. Call on app start / home appear.
    func load(userId: String) async {
        if let existing: UserSkillProgress = try? await database.read(collection: "skillProgress", documentId: userId) {
            progress = existing
            nodeStates = existing.nodeStates
            bookmarkedNodeIds = existing.bookmarkedNodeIds
            activeGoalIds = existing.activeGoalIds
            // Older payloads predate `weeklySchedule` — Codable's default makes
            // it `[]` rather than the 7-nil array, so normalize on hydrate.
            weeklySchedule = existing.weeklySchedule.count == 7
                ? existing.weeklySchedule
                : Array(repeating: nil, count: 7)
            currentWeekPhase = existing.currentWeekPhase
        } else {
            let empty = UserSkillProgress.empty(userId: userId)
            progress = empty
            nodeStates = [:]
            bookmarkedNodeIds = []
            activeGoalIds = []
            weeklySchedule = Array(repeating: nil, count: 7)
            currentWeekPhase = .moderate
            try? await database.create(empty, collection: "skillProgress", documentId: userId)
        }
    }

    /// Re-evaluate node states after a workout log is saved.
    /// Scans the full SkillGraph against the user's recent logs.
    func recompute(after log: WorkoutLog, userBodyweightKg: Double?) async {
        let graph = SkillGraph.shared
        var mutated = false
        var unlocked: NodeUnlockedEvent? = nil

        // Fetch recent logs for compound/cumulative evaluation
        let allLogs = (try? await WorkoutLogService.shared.fetchRecentLogs(userId: log.userId, limit: 60)) ?? []
        let pool = allLogs + [log]

        var progressMap: [String: Double] = [:]

        for node in graph.nodes {
            let currentState = progress?.state(for: node.id) ?? .locked
            // Gate: prereqs must be met (OR across groups, AND within a group)
            let gate = prereqsMet(for: node)
            let newState: NodeState

            if currentState == .proven {
                // Earned never demotes: once proven, always proven, even if the
                // proof ages out of the recent-log window. Mirrors the Phase-7
                // "claimed rank never demotes" guarantee for aggregate rank.
                newState = .proven
            } else if gate && requirementMet(node.requirement, logs: pool, bodyweightKg: userBodyweightKg, threshold: 1.0) {
                newState = .proven
            } else {
                newState = .locked
                // Compute how far along toward the target the user is so the
                // hex fill animates even before the node is proven.
                let frac = bestFraction(node.requirement, logs: pool, bodyweightKg: userBodyweightKg)
                if frac > 0 { progressMap[node.id] = min(1.0, frac) }
            }

            if newState != currentState {
                mutated = true
                progress?.nodeStates[node.id] = newState
                if newState == .proven && progress?.provenAt[node.id] == nil {
                    progress?.provenAt[node.id] = Date()
                    unlocked = NodeUnlockedEvent(node: node, newState: .proven, gainsAwarded: gainsFor(node: node))
                }
            }
        }

        if mutated, var p = progress {
            p.updatedAt = Date()
            progress = p
            nodeStates = p.nodeStates
            try? await database.create(p, collection: "skillProgress", documentId: p.userId)

            if let unlocked {
                pendingUnlock = unlocked
            }
        }
        // Always publish progress map (even if no state transitions) so the
        // UI can show in-hex fills update in real time.
        nodeProgress = progressMap
    }

    /// Manual override for skill nodes that can't be detected from logs
    /// (dragon flag, L-sit, etc.). User taps "I hit this" in the detail sheet.
    func manuallyMark(nodeId: String, state: NodeState) async {
        guard var p = progress else { return }
        guard let node = SkillGraph.shared.node(id: nodeId) else { return }
        guard prereqsMet(for: node) else { return }

        p.nodeStates[nodeId] = state
        if state == .proven && p.provenAt[nodeId] == nil { p.provenAt[nodeId] = Date() }
        p.updatedAt = Date()
        progress = p
        nodeStates = p.nodeStates
        try? await database.create(p, collection: "skillProgress", documentId: p.userId)

        let event = NodeUnlockedEvent(node: node, newState: state, gainsAwarded: gainsFor(node: node))
        pendingUnlock = event
    }

    /// Clears the pending unlock after the reveal UI dismisses.
    func clearPendingUnlock() {
        pendingUnlock = nil
    }

    // MARK: - Train availability

    /// True when the Train CTA is enabled for a node. The old per-skill XP
    /// daily cap is gone (it only throttled fake attendance XP), so a trainable
    /// node is always ready — the meaningful signal is the earned RankTier.
    func canTrain(nodeId: String) -> Bool { true }

    /// Wall-clock time the next train is available. Always nil — no cap.
    func nextTrainAvailable(nodeId: String) -> Date? { nil }

    /// True when a node is allowed to be trained directly. Locked skills are
    /// still viewable as dossiers, but training/program actions require the
    /// tier-aware unlock standards to be met.
    func isNodeTrainable(nodeId: String) -> Bool {
        guard let node = SkillGraph.shared.node(id: nodeId) else { return false }
        guard let p = progress else { return node.prereqs.isEmpty }
        guard SkillGraph.shared.isClusterUnlocked(node.cluster, nodeStates: p.nodeStates) else { return false }
        return prereqsMet(for: node)
    }

    // MARK: - Bookmarks

    func isBookmarked(nodeId: String) -> Bool {
        bookmarkedNodeIds.contains(nodeId)
    }

    /// Toggle the bookmark state for a node and persist. View binds via
    /// `@Bindable` on the singleton so the icon flips after the await.
    func toggleBookmark(nodeId: String) async {
        guard var p = progress else { return }
        if p.bookmarkedNodeIds.contains(nodeId) {
            p.bookmarkedNodeIds.remove(nodeId)
        } else {
            p.bookmarkedNodeIds.insert(nodeId)
        }
        p.updatedAt = Date()
        progress = p
        bookmarkedNodeIds = p.bookmarkedNodeIds
        try? await database.create(p, collection: "skillProgress", documentId: p.userId)
    }

    // MARK: - Program Focuses (Program scheduler)

    /// Maximum number of skills a user can have actively training at once.
    /// Cap exists to keep the Program tab focused.
    static let activeGoalCap: Int = 3
    static let programFocusCap: Int = activeGoalCap

    func isActiveGoal(nodeId: String) -> Bool {
        activeGoalIds.contains(nodeId)
    }

    func isProgramFocus(nodeId: String) -> Bool {
        isActiveGoal(nodeId: nodeId)
    }

    /// Toggle whether a node is a Program Focus. Caps at `programFocusCap` —
    /// attempts to add a new focus beyond the cap silently no-op (the view
    /// should disable the add button when at cap, but the service guards
    /// anyway). Persists via the same path as bookmarks.
    func toggleActiveGoal(nodeId: String) async {
        guard var p = progress else { return }
        guard isNodeTrainable(nodeId: nodeId) || p.activeGoalIds.contains(nodeId) else { return }
        let wasFocus = p.activeGoalIds.contains(nodeId)
        if wasFocus {
            p.activeGoalIds.remove(nodeId)
        } else {
            // Cap enforcement — don't grow past the limit.
            guard p.activeGoalIds.count < Self.activeGoalCap else { return }
            p.activeGoalIds.insert(nodeId)
        }
        p.updatedAt = Date()
        progress = p
        activeGoalIds = p.activeGoalIds
        try? await database.create(p, collection: "skillProgress", documentId: p.userId)

        // On ADD: pre-generate today's session so the Program tab Train
        // button is instant when the user gets there. Fire-and-forget —
        // if the lookup fails it'll retry on first user-initiated open.
        if !wasFocus, let userId = currentUserId {
            Task.detached { @MainActor in
                await RPESessionService.shared.prefetch(
                    skillId: nodeId,
                    userId: userId
                )
            }
        }
    }

    func toggleProgramFocus(nodeId: String) async {
        await toggleActiveGoal(nodeId: nodeId)
    }

    // MARK: - Weekly schedule (Program scheduler V3)

    /// Persist the user's weekly schedule. Index 0 = Monday, 6 = Sunday.
    /// `nil` entries fall back to `ProgramScheduler.defaultWeeklySchedule`.
    /// Observed views re-render via the @Observable property mirror.
    func setWeeklySchedule(_ schedule: [DayCategory?]) async {
        guard schedule.count == 7, var p = progress else { return }
        p.weeklySchedule = schedule
        p.updatedAt = Date()
        progress = p
        weeklySchedule = schedule
        try? await database.create(p, collection: "skillProgress", documentId: p.userId)
    }

    /// V4 — Persist the user's current week-phase tag. Same pattern as
    /// `setWeeklySchedule`. Drives AI session prescription intensity.
    func setWeekPhase(_ phase: WeekPhase) async {
        guard var p = progress else { return }
        p.currentWeekPhase = phase
        p.updatedAt = Date()
        progress = p
        currentWeekPhase = phase
        try? await database.create(p, collection: "skillProgress", documentId: p.userId)
    }

    // MARK: Internal helpers

    /// OR-across-groups, AND-within-a-group. A node is unlocked if ANY
    /// of its unlock-standard groups has ALL source skills at the required
    /// tier. Baseline Forged unlocks accept legacy proven-compatible state
    /// while old progress saves migrate onto tier-backed standards.
    /// Entry nodes (no prereqs) are always considered gate-met.
    private func prereqsMet(for node: SkillNode) -> Bool {
        if node.prereqs.isEmpty { return true }
        guard let progress else { return false }

        let tierState = UserSkillTierStore.shared.load(userId: progress.userId)
        let groups = SkillUnlockStandards.groups(for: node, in: SkillGraph.shared)

        return groups.contains { group in
            group.requirements.allSatisfy { requirement in
                SkillUnlockStandards.isSatisfied(
                    requirement,
                    nodeStates: progress.nodeStates,
                    tierState: tierState
                )
            }
        }
    }

    // MARK: Requirement evaluation

    /// Does the user's recent log pool meet `requirement` at `threshold`×?
    /// threshold 1.0 = exactly the benchmark (proven).
    // Internal (not private) so the auto-proof detection can be unit-tested
    // directly without driving the full SkillGraph prereq/cluster machinery.
    func requirementMet(
        _ requirement: NodeRequirement,
        logs: [WorkoutLog],
        bodyweightKg: Double?,
        threshold: Double
    ) -> Bool {
        switch requirement {
        case .weightMultiplier(let exercise, let mult):
            guard let bw = bodyweightKg else { return false }
            let target = bw * mult * threshold
            return proofSets(exercise: exercise, logs: logs)
                .contains { ($0.weightKg ?? 0) >= target }
        case .reps(let exercise, let count, _):
            let target = Int(Double(count) * threshold)
            return repsMetricMet(exercise: exercise, target: target, logs: logs)
        case .hold(let exercise, let seconds):
            // Hold: best logged duration meets the target seconds.
            let target = Int((Double(seconds) * threshold).rounded())
            return secondsMetricMet(exercise: exercise, target: target, logs: logs)
        case .steps(let exercise, let count):
            let target = Int((Double(count) * threshold).rounded())
            return repsMetricMet(exercise: exercise, target: target, logs: logs)
        case .carry(let exercise, let seconds, _):
            // Carry: target duration AND the set must be loaded.
            let target = Int((Double(seconds) * threshold).rounded())
            return secondsMetricMet(exercise: exercise, target: target, logs: logs, requireLoad: true)
        case .composite(let parts):
            // Every part must be proven at this threshold.
            return parts.allSatisfy {
                requirementMet($0, logs: logs, bodyweightKg: bodyweightKg, threshold: threshold)
            }
        }
    }

    /// Best non-warmup `reps` (used as the metric column for steps) meets
    /// `target`, optionally requiring the set to be loaded.
    private func repsMetricMet(
        exercise: String,
        target: Int,
        logs: [WorkoutLog],
        requireLoad: Bool = false
    ) -> Bool {
        proofSets(exercise: exercise, logs: logs).contains { set in
            set.reps >= target && (!requireLoad || (set.weightKg ?? 0) > 0)
        }
    }

    /// Best non-warmup hold/carry duration meets `target` seconds. Reads
    /// `durationSeconds`, falling back to `reps` for legacy reps-column holds.
    private func secondsMetricMet(
        exercise: String,
        target: Int,
        logs: [WorkoutLog],
        requireLoad: Bool = false
    ) -> Bool {
        proofSets(exercise: exercise, logs: logs).contains { set in
            (set.durationSeconds ?? set.reps) >= target
                && (!requireLoad || (set.weightKg ?? 0) > 0)
        }
    }

    private func proofSets(exercise: String, logs: [WorkoutLog]) -> [SetLog] {
        logs.flatMap(\.exerciseEntries)
            .filter { !$0.skipped }
            .filter { matches($0.exerciseName, exercise) }
            .flatMap(\.sets)
            .filter { !$0.isWarmup && $0.isProofEligible }
    }

    /// Strict movement-aware proof match between a logged exercise and a node target.
    private func matches(_ logged: String, _ required: String) -> Bool {
        MovementProofMatcher.namesMatch(logged: logged, required: required)
    }

    // MARK: Progress fraction (best attempt vs target)

    /// Returns 0.0–1.0+ indicating how close the user's best recent attempt
    /// is to the node's target. Only reps + weightMultiplier produce real
    /// numbers today; holds / steps / carries / composites return 0 and
    /// rely on the manual "I hit this" flow.
    private func bestFraction(
        _ requirement: NodeRequirement,
        logs: [WorkoutLog],
        bodyweightKg: Double?
    ) -> Double {
        switch requirement {
        case .weightMultiplier(let exercise, let mult):
            guard let bw = bodyweightKg, bw > 0 else { return 0 }
            let target = bw * mult
            let best = proofSets(exercise: exercise, logs: logs)
                .compactMap(\.weightKg)
                .max() ?? 0
            return target > 0 ? best / target : 0

        case .reps(let exercise, let count, _):
            let target = Double(count)
            let best = proofSets(exercise: exercise, logs: logs)
                .map { Double($0.reps) }
                .max() ?? 0
            return target > 0 ? best / target : 0

        case .composite(let parts):
            // Fraction = minimum across parts (slowest link wins).
            let fracs = parts.map { bestFraction($0, logs: logs, bodyweightKg: bodyweightKg) }
            return fracs.min() ?? 0

        case .hold(let exercise, let seconds):
            return secondsMetricFraction(exercise: exercise, target: Double(seconds), logs: logs)
        case .steps(let exercise, let count):
            return repsMetricFraction(exercise: exercise, target: Double(count), logs: logs)
        case .carry(let exercise, let seconds, _):
            return secondsMetricFraction(exercise: exercise, target: Double(seconds), logs: logs, requireLoad: true)
        }
    }

    /// Best non-warmup `reps` (metric column for steps) over target.
    private func repsMetricFraction(exercise: String, target: Double, logs: [WorkoutLog]) -> Double {
        guard target > 0 else { return 0 }
        let best = proofSets(exercise: exercise, logs: logs)
            .map { Double($0.reps) }
            .max() ?? 0
        return best / target
    }

    /// Best non-warmup hold/carry duration over target. Reads `durationSeconds`,
    /// falling back to `reps` for legacy reps-column holds.
    private func secondsMetricFraction(
        exercise: String,
        target: Double,
        logs: [WorkoutLog],
        requireLoad: Bool = false
    ) -> Double {
        guard target > 0 else { return 0 }
        let best = proofSets(exercise: exercise, logs: logs)
            .filter { !requireLoad || ($0.weightKg ?? 0) > 0 }
            .map { Double($0.durationSeconds ?? $0.reps) }
            .max() ?? 0
        return best / target
    }

    // MARK: Gains awarded per node

    private func gainsFor(node: SkillNode) -> Int {
        if node.isMythic { return 400 }
        if node.isKeystone { return 200 }
        switch node.type {
        case .strength: return 50
        case .skill:    return 40
        case .hold:     return 40
        }
    }

}

// MARK: - NodeUnlockedEvent

struct NodeUnlockedEvent: Identifiable {
    let id = UUID()
    let node: SkillNode
    let newState: NodeState
    let gainsAwarded: Int
}
