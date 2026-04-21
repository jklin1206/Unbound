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

    static func empty(userId: String) -> UserSkillProgress {
        UserSkillProgress(
            userId: userId,
            nodeStates: [:],
            achievedAt: [:],
            masteredAt: [:],
            updatedAt: Date()
        )
    }

    /// State for a given node — falls back to .locked if not yet computed.
    func state(for nodeId: String) -> NodeState {
        nodeStates[nodeId] ?? .locked
    }
}
