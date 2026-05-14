import Foundation
import Observation

// MARK: - SkillProgressService
//
// Computes skill-tree node states from the user's workout logs + any
// manual "I hit it" overrides. Exposes an @Observable snapshot for
// views. Persists UserSkillProgress in the local JSON store.
//
// State transitions:
//   locked → attempting    : all prerequisite nodes are .achieved or .mastered
//   attempting → achieved  : the node's requirement is met by a single log entry or an override
//   achieved → mastered    : requirement is met again at 2x threshold (e.g. double the target reps)
//
// Notification emits `NodeUnlockedEvent` when a node transitions to
// .achieved or .mastered — caller uses this to show the reveal overlay.

@Observable
@MainActor
final class SkillProgressService {

    // MARK: Singleton

    static let shared = SkillProgressService()

    // MARK: Published state

    /// Snapshot of node states keyed by nodeId. Views observe this.
    private(set) var nodeStates: [String: NodeState] = [:]

    /// Per-attempting-node fraction of the target hit by the user's best
    /// recent attempt. 0.0–1.0. Populated during recompute. Missing entries
    /// mean "no data yet" — render the hex without a fill.
    private(set) var nodeProgress: [String: Double] = [:]

    // MARK: - Phase 1a addition (skill-tree redesign)
    //
    // Peer snapshot of per-node 1-5 level + XP progression. Kept in parallel
    // with `nodeStates` rather than folded into NodeState so that all existing
    // `== .locked` / `== .achieved` comparisons across the codebase keep
    // working unchanged. Empty until Phase 1b wires XP accrual.
    private(set) var skillProgress: [String: SkillProgress] = [:]

    /// Mirror of `UserSkillProgress.bookmarkedNodeIds` for view binding.
    private(set) var bookmarkedNodeIds: Set<String> = []

    /// Mirror of `UserSkillProgress.activeGoalIds` for view binding.
    /// Active goals are skills the user has explicitly opted into training
    /// — they drive the Program tab's TODAY'S TRAINING section.
    private(set) var activeGoalIds: Set<String> = []

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
            skillProgress = existing.skillProgress
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
            skillProgress = [:]
            bookmarkedNodeIds = []
            activeGoalIds = []
            weeklySchedule = Array(repeating: nil, count: 7)
            currentWeekPhase = .moderate
            try? await database.create(empty, collection: "skillProgress", documentId: userId)
        }
        seedRootNodes()
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

            if !gate {
                newState = .locked
            } else if requirementMet(node.requirement, logs: pool, bodyweightKg: userBodyweightKg, threshold: 2.0) {
                newState = .mastered
            } else if requirementMet(node.requirement, logs: pool, bodyweightKg: userBodyweightKg, threshold: 1.0) {
                newState = .achieved
            } else {
                newState = .attempting
                // Compute how far along toward the target the user is.
                let frac = bestFraction(node.requirement, logs: pool, bodyweightKg: userBodyweightKg)
                if frac > 0 { progressMap[node.id] = min(1.0, frac) }
            }

            if newState != currentState {
                mutated = true
                progress?.nodeStates[node.id] = newState
                if newState == .achieved && progress?.achievedAt[node.id] == nil {
                    progress?.achievedAt[node.id] = Date()
                    unlocked = NodeUnlockedEvent(node: node, newState: .achieved, gainsAwarded: gainsFor(node: node))
                }
                if newState == .mastered && progress?.masteredAt[node.id] == nil {
                    progress?.masteredAt[node.id] = Date()
                    unlocked = NodeUnlockedEvent(node: node, newState: .mastered, gainsAwarded: gainsFor(node: node))
                }
            }
        }

        if mutated, var p = progress {
            p.updatedAt = Date()
            progress = p
            nodeStates = p.nodeStates
            try? await database.create(p, collection: "skillProgress", documentId: p.userId)

            if let unlocked {
                awardGains(unlocked.gainsAwarded)
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
        if state == .achieved && p.achievedAt[nodeId] == nil { p.achievedAt[nodeId] = Date() }
        if state == .mastered && p.masteredAt[nodeId] == nil { p.masteredAt[nodeId] = Date() }
        p.updatedAt = Date()
        progress = p
        nodeStates = p.nodeStates
        try? await database.create(p, collection: "skillProgress", documentId: p.userId)

        let event = NodeUnlockedEvent(node: node, newState: state, gainsAwarded: gainsFor(node: node))
        awardGains(event.gainsAwarded)
        pendingUnlock = event
    }

    /// Clears the pending unlock after the reveal UI dismisses.
    func clearPendingUnlock() {
        pendingUnlock = nil
    }

    // MARK: - Phase 1b: XP API

    /// Returns the current `SkillProgress` for `nodeId`, or `.starter`
    /// (Lv1, 0/100 XP) if nothing has been stored yet. Never mutates.
    func currentSkillProgress(for nodeId: String) -> SkillProgress {
        skillProgress[nodeId] ?? .starter
    }

    /// Grants XP for a verified session on this node. Handles level-up
    /// transitions (including multi-level jumps when xpAmount is large),
    /// promotes `NodeState` to `.achieved` on the first level-up, and caps
    /// the node at Level 5 with `.mastered` once the final XP bar fills.
    ///
    /// No-ops when the node is already `.mastered` (cap).
    ///
    /// - Parameters:
    ///   - nodeId: The node that earned XP from this session.
    ///   - xpAmount: XP to grant. Defaults to `25` (one verified session).
    func awardSessionXP(forNodeId nodeId: String, xpAmount: Int = 25) async {
        guard var p = progress else { return }
        guard xpAmount > 0 else { return }

        // 1. Load or initialize progress for this node.
        var sp = p.skillProgress[nodeId] ?? .starter

        // 2. Already capped at mastered → no-op.
        let existingState = p.nodeStates[nodeId] ?? .locked
        if existingState == .mastered && sp.currentLevel == 5 {
            return
        }

        // 2b. Daily cap: one award per node per 24h. Prevents tap-to-grind.
        if let last = p.lastTrainedAt[nodeId],
           Date().timeIntervalSince(last) < 24 * 3600 {
            return
        }

        // 3. Add the XP.
        sp.xpInLevel += xpAmount

        // 4. Roll overflow forward, level by level, up to Lv5.
        //    Lv5 keeps the Lv5 bar (175 XP) as its "until mastered" threshold
        //    — filling it flips the node to .mastered in step 5 below.
        while sp.xpInLevel >= sp.xpToNextLevel && sp.currentLevel < 5 {
            sp.xpInLevel -= sp.xpToNextLevel
            sp.currentLevel += 1
            let nextThreshold = sp.currentLevel == 5
                ? xpForLevel(5)
                : xpForLevel(sp.currentLevel + 1)
            sp.xpToNextLevel = nextThreshold
        }

        // 5. At Lv5 with its bar full → mastered.
        let hasMasteredThisCall: Bool
        if sp.currentLevel == 5 && sp.xpInLevel >= sp.xpToNextLevel {
            sp.xpInLevel = sp.xpToNextLevel   // cap the display
            hasMasteredThisCall = existingState != .mastered
        } else {
            hasMasteredThisCall = false
        }

        // 6. Side-effect on NodeState — never downgrade.
        //    Lv1→Lv2+: promote .locked / .attempting to .achieved.
        //    Lv5 with full XP: promote to .mastered.
        var newNodeState: NodeState? = nil
        if hasMasteredThisCall {
            newNodeState = .mastered
        } else if sp.currentLevel >= 2 && (existingState == .locked || existingState == .attempting) {
            newNodeState = .achieved
        }

        // 7. Commit to state.
        p.skillProgress[nodeId] = sp
        p.lastTrainedAt[nodeId] = Date()
        if let newState = newNodeState {
            p.nodeStates[nodeId] = newState
            if newState == .achieved && p.achievedAt[nodeId] == nil {
                p.achievedAt[nodeId] = Date()
            }
            if newState == .mastered && p.masteredAt[nodeId] == nil {
                p.masteredAt[nodeId] = Date()
            }
        }
        p.updatedAt = Date()
        progress = p
        skillProgress = p.skillProgress
        nodeStates = p.nodeStates

        // 8. Persist (mirrors the manuallyMark / recompute pattern).
        try? await database.create(p, collection: "skillProgress", documentId: p.userId)

        // 9. Publish an unlock event if this call pushed the node over a
        //    reveal-worthy threshold. Uses the same NodeUnlockedEvent that
        //    views already listen for via pendingUnlock.
        if let newState = newNodeState,
           let node = SkillGraph.shared.node(id: nodeId),
           newState == .achieved || newState == .mastered {
            let event = NodeUnlockedEvent(
                node: node,
                newState: newState,
                gainsAwarded: gainsFor(node: node)
            )
            awardGains(event.gainsAwarded)
            pendingUnlock = event
        }
    }

    /// True when the Train CTA is allowed to award XP. Gated by the
    /// 24h cap recorded in `UserSkillProgress.lastTrainedAt`. Treat
    /// missing entries as "ready to train."
    func canTrain(nodeId: String) -> Bool {
        guard let last = progress?.lastTrainedAt[nodeId] else { return true }
        return Date().timeIntervalSince(last) >= 24 * 3600
    }

    /// Wall-clock time the next train is available. Nil = ready now.
    func nextTrainAvailable(nodeId: String) -> Date? {
        guard let last = progress?.lastTrainedAt[nodeId] else { return nil }
        return last.addingTimeInterval(24 * 3600)
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

    // MARK: - Active goals (Program scheduler)

    /// Maximum number of skills a user can have actively training at once.
    /// Cap exists to keep the Program tab focused — V1 surfaces all active
    /// goals every day, so 3+ would already feel like a heavy daily list.
    static let activeGoalCap: Int = 3

    func isActiveGoal(nodeId: String) -> Bool {
        activeGoalIds.contains(nodeId)
    }

    /// Toggle whether a node is an active goal. Caps at `activeGoalCap` —
    /// attempts to add a new goal beyond the cap silently no-op (the view
    /// should disable the add button when at cap, but the service guards
    /// anyway). Persists via the same path as bookmarks.
    func toggleActiveGoal(nodeId: String) async {
        guard var p = progress else { return }
        let wasGoal = p.activeGoalIds.contains(nodeId)
        if wasGoal {
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
        if !wasGoal, let userId = currentUserId {
            Task.detached { @MainActor in
                await RPESessionService.shared.prefetch(
                    skillId: nodeId,
                    userId: userId
                )
            }
        }
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

    /// XP required to reach `level` starting from `level - 1`.
    /// Lv1 is the starting floor — nothing required to be there.
    /// Curve: 100 / 125 / 150 / 175 for Lv2 / Lv3 / Lv4 / Lv5.
    func xpForLevel(_ level: Int) -> Int {
        guard level >= 2 && level <= 5 else { return 0 }
        return 100 + 25 * (level - 2)
    }

    // MARK: Internal helpers

    /// OR-across-groups, AND-within-a-group. A node is unlocked if ANY
    /// of its prereq groups has ALL node-ids achieved/mastered.
    /// Entry nodes (no prereqs) are always considered gate-met.
    private func prereqsMet(for node: SkillNode) -> Bool {
        if node.prereqs.isEmpty { return true }
        return node.prereqs.contains { group in
            group.nodeIds.allSatisfy { id in
                let state = progress?.state(for: id) ?? .locked
                return state == .achieved || state == .mastered
            }
        }
    }

    /// Seeds `.attempting` for the universal root nodes (no-prereq nodes) if
    /// they haven't already been recorded. Also self-heals: any node currently
    /// `.attempting` whose prereqs are NOT met (because the tree was
    /// restructured underneath them) gets demoted to `.locked`. This keeps
    /// existing user state consistent with content updates.
    private func seedRootNodes() {
        guard var p = progress else { return }
        let graph = SkillGraph.shared

        // 1. Demote any orphaned .attempting nodes whose prereqs no longer hold.
        for (id, state) in p.nodeStates where state == .attempting {
            guard let node = graph.node(id: id) else { continue }
            if !node.prereqs.isEmpty {
                let met = node.prereqs.contains { group in
                    group.nodeIds.allSatisfy { reqId in
                        let s = p.state(for: reqId)
                        return s == .achieved || s == .mastered
                    }
                }
                if !met { p.nodeStates[id] = .locked }
            }
        }

        // 2. Seed root nodes (no prereqs) as .attempting (only if currently locked).
        let rootIds = graph.nodes.filter { $0.prereqs.isEmpty }.map(\.id)
        for id in rootIds where p.state(for: id) == .locked {
            p.nodeStates[id] = .attempting
        }

        progress = p
        nodeStates = p.nodeStates
    }

    // MARK: Requirement evaluation

    /// Does the user's recent log pool meet `requirement` at `threshold`×?
    /// threshold 1.0 = exactly the benchmark. 2.0 = "mastered" (double).
    private func requirementMet(
        _ requirement: NodeRequirement,
        logs: [WorkoutLog],
        bodyweightKg: Double?,
        threshold: Double
    ) -> Bool {
        switch requirement {
        case .weightMultiplier(let exercise, let mult):
            guard let bw = bodyweightKg else { return false }
            let target = bw * mult * threshold
            return logs.contains(where: { log in
                log.exerciseEntries.contains(where: { entry in
                    matches(entry.exerciseName, exercise) &&
                    entry.sets.contains(where: { ($0.weightKg ?? 0) >= target })
                })
            })
        case .reps(let exercise, let count, _):
            let target = Int(Double(count) * threshold)
            return logs.contains(where: { log in
                log.exerciseEntries.contains(where: { entry in
                    matches(entry.exerciseName, exercise) &&
                    entry.sets.contains(where: { $0.reps >= target && !$0.isWarmup })
                })
            })
        case .hold, .steps, .carry, .composite:
            // Holds, step-count, carries, and composites require explicit
            // logging formats we don't capture in V1 WorkoutLog. Defer to
            // the manual "I hit it" flow for these types.
            return false
        }
    }

    /// Fuzzy match between a logged exercise name and a node's named exercise.
    private func matches(_ logged: String, _ required: String) -> Bool {
        let l = logged.lowercased()
        let r = required.lowercased()
        return l == r || l.contains(r) || r.contains(l)
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
            let best = logs.flatMap(\.exerciseEntries)
                .filter { matches($0.exerciseName, exercise) }
                .flatMap(\.sets)
                .compactMap(\.weightKg)
                .max() ?? 0
            return target > 0 ? best / target : 0

        case .reps(let exercise, let count, _):
            let target = Double(count)
            let best = logs.flatMap(\.exerciseEntries)
                .filter { matches($0.exerciseName, exercise) }
                .flatMap(\.sets)
                .filter { !$0.isWarmup }
                .map { Double($0.reps) }
                .max() ?? 0
            return target > 0 ? best / target : 0

        case .composite(let parts):
            // Fraction = minimum across parts (slowest link wins).
            let fracs = parts.map { bestFraction($0, logs: logs, bodyweightKg: bodyweightKg) }
            return fracs.min() ?? 0

        case .hold, .steps, .carry:
            // Not captured in WorkoutLog today — depends on manual flow.
            return 0
        }
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

    private func awardGains(_ amount: Int) {
        let current = UserDefaults.standard.integer(forKey: "unbound.gains")
        UserDefaults.standard.set(current + amount, forKey: "unbound.gains")
    }
}

// MARK: - NodeUnlockedEvent

struct NodeUnlockedEvent: Identifiable {
    let id = UUID()
    let node: SkillNode
    let newState: NodeState
    let gainsAwarded: Int
}
