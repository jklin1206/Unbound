import XCTest
@testable import UNBOUND

final class PrereqMetadataMigrationTests: XCTestCase {
    func testEveryGraphPrereqHasClearingMetadata() {
        let graph = SkillGraph.shared
        let requirements = graph.nodes.flatMap {
            SkillUnlockStandards.groups(for: $0, in: graph).flatMap(\.requirements)
        }

        XCTAssertFalse(requirements.isEmpty)
        for requirement in requirements {
            XCTAssertTrue(
                requirement.proofFamilyCovered.contains(requirement.directProofFamily),
                "\(requirement.id) must cover its direct proof family"
            )
            XCTAssertFalse(
                requirement.autoClearFromHigherProof && requirement.safetyRequired,
                "\(requirement.id) cannot auto-clear when safety proof is required"
            )
        }
    }
}
