import Foundation

// MARK: - SkillProgress
//
// Per-node XP progression data. Lives alongside the existing NodeState
// enum (locked / attempting / achieved / mastered) rather than replacing
// it — NodeState is widely compared with `==` across views and services,
// and mutating its cases would cascade breakage.
//
// Phase 1a: struct scaffolding only. Dictionary is empty at runtime.
// Phase 1b wires XP accrual into SkillProgressService.

public struct SkillProgress: Codable, Hashable, Sendable {
    public var currentLevel: Int      // 1...5
    public var xpInLevel: Int         // XP accumulated toward the next level
    public var xpToNextLevel: Int     // required XP to hit next level

    public init(currentLevel: Int, xpInLevel: Int, xpToNextLevel: Int) {
        self.currentLevel = currentLevel
        self.xpInLevel = xpInLevel
        self.xpToNextLevel = xpToNextLevel
    }

    public static let starter = SkillProgress(currentLevel: 1, xpInLevel: 0, xpToNextLevel: 100)
}
