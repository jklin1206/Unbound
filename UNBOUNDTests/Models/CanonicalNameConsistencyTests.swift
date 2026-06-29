import XCTest
@testable import UNBOUND

/// Locks the P1 rename: a true twin (the same physical movement recorded in
/// another subsystem) must read ONE canonical name across the skill node title,
/// the library exercise displayName, and the drill displayName. Regression drills
/// (Tuck L-Sit, Band-Assisted Full Planche, ...) are deliberately NOT here - they
/// are distinct movements that keep their own names.
final class CanonicalNameConsistencyTests: XCTestCase {

    /// (skill node id, canonical name, the twin movement ids that must all read it)
    private let reconciledTwins: [(node: String, name: String, twins: [String])] = [
        ("cl.hollow-body-30", "Hollow Body Hold", ["exercise.hollow-hold", "skill-drill.hollow-body-hold"]),
        ("hs.freestanding-hs-30", "Freestanding Handstand", ["skill-drill.freestanding-handstand"]),
        ("ld.weighted-pistol", "Weighted Pistol Squat", ["exercise.weighted-pistol"])
    ]

    func testReconciledTwinsShareOneName() throws {
        for twin in reconciledTwins {
            let node = try XCTUnwrap(
                SkillGraph.shared.nodes.first { $0.id == twin.node },
                "missing skill node \(twin.node)"
            )
            XCTAssertEqual(node.title, twin.name, "skill node \(twin.node) title should be the canonical name")

            for id in twin.twins {
                let def = try XCTUnwrap(
                    MovementCatalog.definition(for: id),
                    "missing movement definition \(id)"
                )
                XCTAssertEqual(def.displayName, twin.name, "\(id) displayName should match the canonical name")
            }
        }
    }
}
