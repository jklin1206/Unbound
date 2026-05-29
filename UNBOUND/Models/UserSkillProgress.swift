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
    var provenAt: [String: Date]                     // nodeId → first-proven timestamp
    var updatedAt: Date

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
            provenAt: [:],
            updatedAt: Date(),
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

    // MARK: - Tolerant decoding (skill-tree redesign)
    //
    // Pre-redesign blobs split first-proof timestamps across `achievedAt` and
    // `masteredAt`, and carried the now-deleted `skillProgress` (fake LVL) and
    // `lastTrainedAt` dicts. Merge the two timestamp maps into `provenAt`
    // (earliest wins) and ignore the dropped keys, so existing local saves
    // decode without a migration.
    enum CodingKeys: String, CodingKey {
        case userId, nodeStates, provenAt, updatedAt
        case bookmarkedNodeIds, activeGoalIds, weeklySchedule, currentWeekPhase
        // Legacy-only keys, read on decode, never encoded:
        case achievedAt, masteredAt
    }

    init(
        userId: String,
        nodeStates: [String: NodeState],
        provenAt: [String: Date],
        updatedAt: Date,
        bookmarkedNodeIds: Set<String> = [],
        activeGoalIds: Set<String> = [],
        weeklySchedule: [DayCategory?] = Array(repeating: nil, count: 7),
        currentWeekPhase: WeekPhase = .moderate
    ) {
        self.userId = userId
        self.nodeStates = nodeStates
        self.provenAt = provenAt
        self.updatedAt = updatedAt
        self.bookmarkedNodeIds = bookmarkedNodeIds
        self.activeGoalIds = activeGoalIds
        self.weeklySchedule = weeklySchedule
        self.currentWeekPhase = currentWeekPhase
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(String.self, forKey: .userId)
        nodeStates = try c.decodeIfPresent([String: NodeState].self, forKey: .nodeStates) ?? [:]
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()

        // Merge legacy achievedAt + masteredAt into provenAt (earliest wins),
        // then layer any already-migrated provenAt on top.
        var merged: [String: Date] = [:]
        let sources = [
            try c.decodeIfPresent([String: Date].self, forKey: .achievedAt) ?? [:],
            try c.decodeIfPresent([String: Date].self, forKey: .masteredAt) ?? [:],
            try c.decodeIfPresent([String: Date].self, forKey: .provenAt) ?? [:]
        ]
        for map in sources {
            for (id, date) in map {
                merged[id] = merged[id].map { min($0, date) } ?? date
            }
        }
        provenAt = merged

        bookmarkedNodeIds = try c.decodeIfPresent(Set<String>.self, forKey: .bookmarkedNodeIds) ?? []
        activeGoalIds = try c.decodeIfPresent(Set<String>.self, forKey: .activeGoalIds) ?? []
        weeklySchedule = try c.decodeIfPresent([DayCategory?].self, forKey: .weeklySchedule) ?? Array(repeating: nil, count: 7)
        currentWeekPhase = try c.decodeIfPresent(WeekPhase.self, forKey: .currentWeekPhase) ?? .moderate
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(userId, forKey: .userId)
        try c.encode(nodeStates, forKey: .nodeStates)
        try c.encode(provenAt, forKey: .provenAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(bookmarkedNodeIds, forKey: .bookmarkedNodeIds)
        try c.encode(activeGoalIds, forKey: .activeGoalIds)
        try c.encode(weeklySchedule, forKey: .weeklySchedule)
        try c.encode(currentWeekPhase, forKey: .currentWeekPhase)
    }
}
