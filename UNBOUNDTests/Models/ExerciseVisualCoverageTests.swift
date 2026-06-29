import XCTest
import UIKit
@testable import UNBOUND

/// Authoritative audit: EVERY movement that shows a visual to the user (rank
/// library, exercise library, skill detail, workout cards) must resolve to a
/// bundled, loadable image. The legacy `MovementResolverTests` only checked
/// `role == .canonicalExercise`, so skill drills (e.g. Hollow Body Hold), skill
/// targets, cardio, carry, and mobility could ship with no art and nothing
/// caught it. This test closes that gap and lists every miss in one run.
final class ExerciseVisualCoverageTests: XCTestCase {

    /// The roles that render a movement visual. `alias`, `routineContainer`, and
    /// `routineStep` intentionally have no per-movement art (they use a glyph
    /// placeholder), so they are excluded.
    private static let visualBearingRoles: Set<MovementRole> = [
        .canonicalExercise,
        .skillTarget,
        .skillDrill,
        .cardioModality,
        .carrySled,
        .mobilityDuration
    ]

    func testEveryVisualBearingMovementResolvesToALoadableImage() {
        let definitions = MovementCatalog.definitions
            .filter { Self.visualBearingRoles.contains($0.role) }

        var unresolved: [String] = []
        var notLoadable: [String] = []

        for definition in definitions {
            guard let assetName = ExerciseVisualAsset.existingAssetName(for: definition) else {
                unresolved.append("\(definition.role) | \(definition.id) — \(definition.displayName)")
                continue
            }
            if UIImage(named: assetName) == nil {
                notLoadable.append("\(definition.id) — \(definition.displayName) -> \(assetName)")
            }
        }

        var report = ""
        if !unresolved.isEmpty {
            report += "\nMovements with NO resolvable visual asset (\(unresolved.count)):\n"
                + unresolved.sorted().joined(separator: "\n")
        }
        if !notLoadable.isEmpty {
            report += "\n\nMovements whose resolved asset does not load (\(notLoadable.count)):\n"
                + notLoadable.sorted().joined(separator: "\n")
        }

        XCTAssertTrue(unresolved.isEmpty && notLoadable.isEmpty, report)
    }

    /// Every live skill node (what the rank library / skill tree actually shows)
    /// must resolve through `SkillTraditionalVisualResolver` to a loadable image.
    func testEverySkillNodeResolvesToALoadableImage() {
        var misses: [String] = []

        for node in SkillGraph.shared.nodes {
            guard let assetName = SkillTraditionalVisualResolver.assetName(for: node) else {
                misses.append("\(node.id) — \(node.title) (no asset)")
                continue
            }
            if UIImage(named: assetName) == nil {
                misses.append("\(node.id) — \(node.title) -> \(assetName) (not loadable)")
            }
        }

        XCTAssertTrue(
            misses.isEmpty,
            "Skill nodes missing a loadable visual (\(misses.count)):\n\(misses.sorted().joined(separator: "\n"))"
        )
    }

    /// The specific regression that prompted this audit: "Hollow Body Hold"
    /// must show art on both its skill-target and skill-drill surfaces.
    func testHollowBodyHoldHasVisualOnEverySurface() throws {
        let skillTarget = try XCTUnwrap(
            MovementCatalog.definition(for: "skill.cl.hollow-body-30"),
            "Hollow Body Hold skill target should exist"
        )
        let skillTargetAsset = try XCTUnwrap(
            ExerciseVisualAsset.existingAssetName(for: skillTarget),
            "Hollow Body Hold (skill) should resolve a visual"
        )
        XCTAssertNotNil(UIImage(named: skillTargetAsset), "\(skillTargetAsset) should load")

        let skillDrill = try XCTUnwrap(
            MovementCatalog.definition(for: "skill-drill.hollow-body-hold"),
            "Hollow Body Hold skill drill should exist"
        )
        let skillDrillAsset = try XCTUnwrap(
            ExerciseVisualAsset.existingAssetName(for: skillDrill),
            "Hollow Body Hold (drill) should resolve a visual"
        )
        XCTAssertNotNil(UIImage(named: skillDrillAsset), "\(skillDrillAsset) should load")
    }
}
