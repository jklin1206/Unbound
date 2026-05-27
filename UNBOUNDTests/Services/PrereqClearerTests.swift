import XCTest
@testable import UNBOUND

final class PrereqClearerTests: XCTestCase {
    func testPullupProofClearsRepPrereqsButNotHoldOrMobility() {
        let proof = AchievedSkillProof(
            id: "pullup-proof",
            exerciseName: "pullup",
            family: .reps,
            magnitude: 12,
            unit: .reps
        )
        let requirements = [
            repRequirement(.apprentice), // 3 reps
            repRequirement(.forged),     // 5 reps
            repRequirement(.master),      // 8 reps
            repRequirement(.vessel),     // 10 reps
            SkillUnlockRequirement(
                sourceSkillId: "pp.dead-hang",
                requiredTier: .forged,
                note: "Dead hang is a direct hold proof.",
                directProofFamily: .hold
            ),
            SkillUnlockRequirement(
                sourceSkillId: "pp.pullup",
                requiredTier: .initiate,
                note: "Mobility drill must be proven directly.",
                directProofFamily: .mobility
            )
        ]

        let cleared = PrereqClearer.autoClearedPrereqs(from: [proof], requirements: requirements)
        let clearedIds = Set(cleared.map(\.requirement.id))

        XCTAssertTrue(clearedIds.contains(repRequirement(.apprentice).id))
        XCTAssertTrue(clearedIds.contains(repRequirement(.forged).id))
        XCTAssertTrue(clearedIds.contains(repRequirement(.master).id))
        XCTAssertTrue(clearedIds.contains(repRequirement(.vessel).id))
        XCTAssertFalse(clearedIds.contains("pp.dead-hang:\(SkillTier.forged.rawValue)"))
        XCTAssertFalse(cleared.contains { $0.requirement.directProofFamily == .mobility })
    }

    func testSafetyRequiredPrereqNeverAutoClears() {
        let proof = AchievedSkillProof(
            exerciseName: "pullup",
            family: .reps,
            magnitude: 12,
            unit: .reps
        )
        let safetyRequirement = SkillUnlockRequirement(
            sourceSkillId: "pp.pullup",
            requiredTier: .forged,
            note: "Requires a direct pain-free form check.",
            directProofFamily: .reps,
            autoClearFromHigherProof: true,
            safetyRequired: true
        )

        XCTAssertFalse(safetyRequirement.autoClearFromHigherProof)
        XCTAssertTrue(
            PrereqClearer.autoClearedPrereqs(from: [proof], requirements: [safetyRequirement]).isEmpty
        )
    }

    func testLoadedProofClearsLoadedPrereqsButNotTempoPrereqs() {
        let proof = AchievedSkillProof(
            exerciseName: "weighted pullup",
            family: .loaded,
            magnitude: 0.6,
            unit: .bodyweightRatio
        )
        let loadedRequirement = SkillUnlockRequirement(
            sourceSkillId: "pp.weighted-pullup",
            requiredTier: .forged,
            note: "Loaded pull standard.",
            directProofFamily: .loaded
        )
        let tempoRequirement = SkillUnlockRequirement(
            sourceSkillId: "pp.slow-pullup",
            requiredTier: .forged,
            note: "Tempo pull-up is direct proof only.",
            directProofFamily: .tempo,
            autoClearFromHigherProof: true
        )

        let cleared = PrereqClearer.autoClearedPrereqs(
            from: [proof],
            requirements: [loadedRequirement, tempoRequirement]
        )

        XCTAssertEqual(cleared.map(\.requirement.id), [loadedRequirement.id])
    }

    private func repRequirement(_ tier: SkillTier) -> SkillUnlockRequirement {
        SkillUnlockRequirement(
            sourceSkillId: "pp.pullup",
            requiredTier: tier,
            note: "Rep prereq",
            directProofFamily: .reps
        )
    }
}
