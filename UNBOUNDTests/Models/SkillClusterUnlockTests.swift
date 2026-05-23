import XCTest
@testable import UNBOUND

final class SkillClusterUnlockTests: XCTestCase {
    // MARK: - Cluster prerequisite wiring

    func testHandstandHasNoPrerequisite() {
        XCTAssertNil(SkillCluster.handstand.requiresClusterKeystone)
    }

    func testHandstandPushupRequiresHandstand() {
        XCTAssertEqual(SkillCluster.handstandPushup.requiresClusterKeystone, .handstand)
    }

    func testOneArmHandstandRequiresHandstandPushup() {
        XCTAssertEqual(SkillCluster.oneArmHandstand.requiresClusterKeystone, .handstandPushup)
    }

    // MARK: - SkillGraph.isClusterUnlocked

    func testClusterUnlockedWhenKeystoneAchieved() {
        let graph = SkillGraph.shared
        let emptyStates: [String: NodeState] = [:]

        // Handstand is ungated — always unlocked.
        XCTAssertTrue(graph.isClusterUnlocked(.handstand, nodeStates: emptyStates))
        // HSPU requires Handstand keystone — gated at spawn.
        XCTAssertFalse(graph.isClusterUnlocked(.handstandPushup, nodeStates: emptyStates))

        // After cracking the Handstand keystone, HSPU opens up.
        let unlockedStates: [String: NodeState] = ["hs.freestanding-hs-30": .achieved]
        XCTAssertTrue(graph.isClusterUnlocked(.handstandPushup, nodeStates: unlockedStates))
        // One-Arm Handstand still waits on HSPU.
        XCTAssertFalse(graph.isClusterUnlocked(.oneArmHandstand, nodeStates: unlockedStates))
    }
}
