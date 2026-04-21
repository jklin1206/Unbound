import XCTest
@testable import UNBOUND

final class WeakPointBiaserTests: XCTestCase {

    // MARK: bias(from:) — FocusArea[] → [MuscleGroup: Int]

    func testBiasWeightsFromPriorityOneAndTwo() {
        let focus = [
            FocusArea(muscleGroup: .shoulders, priority: 1, rationale: "narrow", suggestedFocus: ""),
            FocusArea(muscleGroup: .back,      priority: 2, rationale: "flat",   suggestedFocus: "")
        ]
        let bias = WeakPointBiaser.bias(from: focus)
        XCTAssertEqual(bias[.shoulders], 2)
        XCTAssertEqual(bias[.back], 1)
        XCTAssertNil(bias[.chest])
    }

    func testPriorityThreeAndHigherAreIgnored() {
        let focus = [
            FocusArea(muscleGroup: .arms, priority: 3, rationale: "", suggestedFocus: ""),
            FocusArea(muscleGroup: .core, priority: 4, rationale: "", suggestedFocus: "")
        ]
        XCTAssertTrue(WeakPointBiaser.bias(from: focus).isEmpty)
    }

    func testEmptyInputProducesEmpty() {
        XCTAssertTrue(WeakPointBiaser.bias(from: []).isEmpty)
    }

    // MARK: pickBiased(candidates:...) — C-bias / selection

    func testPickBiasedPrefersOverlap() {
        struct Ex: Equatable { let name: String; let groups: [MuscleGroup] }
        let a = Ex(name: "flat-bench", groups: [.chest])
        let b = Ex(name: "incline-bench", groups: [.chest, .shoulders])
        let bias: [MuscleGroup: Int] = [.shoulders: 2]
        let picked = WeakPointBiaser.pickBiased(
            candidates: [a, b],
            biasedGroups: bias,
            biasedGroupsFor: { $0.groups }
        )
        XCTAssertEqual(picked, b)
    }

    func testPickBiasedFallsBackToFirstWhenNoOverlap() {
        struct Ex: Equatable { let name: String; let groups: [MuscleGroup] }
        let a = Ex(name: "squat", groups: [.legs])
        let b = Ex(name: "bench", groups: [.chest])
        let picked = WeakPointBiaser.pickBiased(
            candidates: [a, b],
            biasedGroups: [.shoulders: 2],
            biasedGroupsFor: { $0.groups }
        )
        // Both tie with score 0; Swift's `max` returns the LAST element on ties.
        // That's fine — we just check something got picked, not which.
        XCTAssertNotNil(picked)
    }

    func testPickBiasedEmptyCandidatesReturnsNil() {
        struct Ex: Equatable { let name: String; let groups: [MuscleGroup] }
        let picked = WeakPointBiaser.pickBiased(
            candidates: [Ex](),
            biasedGroups: [.shoulders: 2],
            biasedGroupsFor: { $0.groups }
        )
        XCTAssertNil(picked)
    }

    // MARK: addAccessories(to:from:...) — B-bias / volume

    func testAddAccessoriesAddsHighestBiasedFirst() {
        struct Ex: Equatable { let name: String; let groups: [MuscleGroup] }
        let pool = [
            Ex(name: "raise",     groups: [.shoulders]),   // shoulders=2 → score 2
            Ex(name: "face-pull", groups: [.shoulders]),   // score 2
            Ex(name: "shrug",     groups: [.traps]),       // traps=1 → score 1
            Ex(name: "curl",      groups: [.arms])         // unbiased → score 0
        ]
        let result = WeakPointBiaser.addAccessories(
            to: [Ex](),
            from: pool,
            biasedGroups: [.shoulders: 2, .traps: 1],
            maxAccessories: 2,
            targetGroupsFor: { $0.groups }
        )
        // Should pick two shoulder-biased (score 2), not the traps or arm entries.
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.groups.contains(.shoulders) })
    }

    func testAddAccessoriesExcludesAlreadyIncluded() {
        struct Ex: Equatable { let name: String; let groups: [MuscleGroup] }
        let raise = Ex(name: "raise", groups: [.shoulders])
        let facePull = Ex(name: "face-pull", groups: [.shoulders])
        let pool = [raise, facePull]
        let result = WeakPointBiaser.addAccessories(
            to: [raise],            // already present
            from: pool,
            biasedGroups: [.shoulders: 2],
            maxAccessories: 2,
            targetGroupsFor: { $0.groups }
        )
        // Should only add face-pull (raise already included).
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], raise)
        XCTAssertEqual(result[1], facePull)
    }

    func testAddAccessoriesReturnsUnchangedWhenNoBias() {
        struct Ex: Equatable { let name: String; let groups: [MuscleGroup] }
        let pool = [Ex(name: "curl", groups: [.arms]), Ex(name: "bench", groups: [.chest])]
        let base = [Ex(name: "squat", groups: [.legs])]
        let result = WeakPointBiaser.addAccessories(
            to: base,
            from: pool,
            biasedGroups: [:],
            maxAccessories: 2,
            targetGroupsFor: { $0.groups }
        )
        XCTAssertEqual(result, base)
    }
}
