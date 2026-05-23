import Foundation

// MARK: - UserSkillProgress
//
// Tracks each user's per-node state for their archetype skill tree.
// Persisted in the local JSON store under collection "skillProgress",
// documentId = userId.
//
// The SkillProgressService is the only writer. Views read the snapshot.

struct UserSkillProgress: Codable {
    let userId: String
    var nodeStates: [String: NodeState]              // nodeId → state
    var achievedAt: [String: Date]                   // nodeId → first-achieved timestamp
    var masteredAt: [String: Date]                   // nodeId → first-mastered timestamp
    var updatedAt: Date

    // MARK: - Phase 1a addition (skill-tree redesign)
    //
    // Peer dictionary to `nodeStates`, keyed by the same nodeId, carrying
    // the 1-5 level + XP ladder progression. Mirrored in persistence so
    // the struct survives a round-trip without tripping Codable. Empty in
    // Phase 1a — Phase 1b wires the XP accrual logic that populates it.
    var skillProgress: [String: SkillProgress] = [:]

    /// nodeId → last `awardSessionXP` timestamp. Used to enforce the
    /// daily cap on the Train CTA so XP can't be grinded by tapping.
    var lastTrainedAt: [String: Date] = [:]

    /// Set of node ids the user has bookmarked from the detail view.
    /// Persists across app launches so the bookmark icon survives restart.
    var bookmarkedNodeIds: Set<String> = []

    /// Skills the user has explicitly opted into training. Distinct from
    /// `bookmarkedNodeIds` (passive save). Active goals drive the Program
    /// tab's TODAY'S TRAINING section.
    var activeGoalIds: Set<String> = []

    /// User's customized weekly schedule. Index 0 = Monday, 6 = Sunday.
    /// `nil` entries fall back to `ProgramScheduler.defaultWeeklySchedule`.
    /// Once authored (any non-nil index) the user owns the slot.
    var weeklySchedule: [DayCategory?] = Array(repeating: nil, count: 7)

    /// V4 — manual periodization tag. Default `.moderate`. Flows into AI
    /// session generation so prescriptions scale with the user's chosen
    /// intensity for this week.
    var currentWeekPhase: WeekPhase = .moderate

    static func empty(userId: String) -> UserSkillProgress {
        UserSkillProgress(
            userId: userId,
            nodeStates: [:],
            achievedAt: [:],
            masteredAt: [:],
            updatedAt: Date(),
            skillProgress: [:],
            lastTrainedAt: [:],
            bookmarkedNodeIds: [],
            activeGoalIds: [],
            weeklySchedule: Array(repeating: nil, count: 7),
            currentWeekPhase: .moderate
        )
    }

    /// State for a given node — falls back to .locked if not yet computed.
    func state(for nodeId: String) -> NodeState {
        nodeStates[nodeId] ?? .locked
    }
}
