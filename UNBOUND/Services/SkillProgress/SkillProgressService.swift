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

    /// The most recent unlock event — views show a reveal when this changes.
    var pendingUnlock: NodeUnlockedEvent? = nil

    // MARK: Dependencies

    private var database: DatabaseServiceProtocol { DatabaseService.shared }
    private var logger: LoggingService { LoggingService.shared }
    private var currentUserId: String? { AuthService.shared.currentUserId }

    private var progress: UserSkillProgress?

    private init() {}

    // MARK: Public API

    /// Load the user's progress from disk. Call on app start / home appear.
    func load(userId: String, archetype: Archetype? = nil) async {
        if let existing: UserSkillProgress = try? await database.read(collection: "skillProgress", documentId: userId) {
            progress = existing
            nodeStates = existing.nodeStates
        } else {
            let empty = UserSkillProgress.empty(userId: userId)
            progress = empty
            nodeStates = [:]
            try? await database.create(empty, collection: "skillProgress", documentId: userId)
        }
        seedSpawnPoints(for: archetype ?? currentArchetype())
    }

    /// Re-evaluate node states after a workout log is saved.
    /// Scans the full SkillGraph against the user's recent logs.
    func recompute(after log: WorkoutLog, for archetype: Archetype, userBodyweightKg: Double?) async {
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

    /// Seeds `.attempting` for the archetype's spawn-point nodes if they
    /// haven't already been recorded. Runs on load.
    private func seedSpawnPoints(for archetype: Archetype) {
        guard var p = progress else { return }
        let spawnIds = ArchetypeSpawnPoints.nodeIds(for: archetype)
        for id in spawnIds where p.state(for: id) == .locked {
            p.nodeStates[id] = .attempting
        }
        progress = p
        nodeStates = p.nodeStates
    }

    private func currentArchetype() -> Archetype {
        // Best-effort read from UserDefaults cache; real implementation
        // would take archetype as a parameter or cache on load.
        .vTaper
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
