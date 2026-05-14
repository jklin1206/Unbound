// SkillTierMigrationTests.swift
// Gated until Phase 7 (RankService DI init). Tests require RankService(tierStore:)
// which is added when SubRank layer is migrated. Re-copy from reference at that point.
import XCTest

@MainActor
final class SkillTierMigrationTests: XCTestCase {
    func testPlaceholderPhase7Gated() {
        // Intentionally empty — real tests need Phase 7's RankService(tierStore:) init.
    }
}
