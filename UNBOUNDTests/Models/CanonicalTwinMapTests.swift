import XCTest
@testable import UNBOUND

/// Locks `exerciseSkillTwins` as the AUTHORITATIVE, complete, metric-safe join
/// between a library exercise and the skill it IS (the P2 canonical-id model).
///
/// - Soundness: every entry points at a real exercise + real skill node, is
///   metric-compatible (a hold skill twins only a hold exercise), and resolves
///   through the runtime `owningSkillId` path the rank engine uses.
/// - Completeness: the map is EXACTLY the set of library exercises that fold
///   into a skill row, so it can never silently drift as the catalog grows
///   (a new bodyweight skill+exercise twin fails this until it is mapped).
final class CanonicalTwinMapTests: XCTestCase {

    private static let holdTemplates: Set<MovementRankTemplate> = [.holdControl, .carrySled, .mobilityDuration]

    private static func isHold(_ requirement: NodeRequirement) -> Bool {
        switch requirement {
        case .hold, .carry: return true
        case .weightMultiplier, .reps, .steps: return false
        case .composite(let reqs): return reqs.contains { isHold($0) }
        }
    }

    private static func searchKey(_ s: String) -> String {
        String(String(s).lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    /// The skill a folded library exercise belongs to, replicating the three
    /// `movementFoldsIntoShownSkill` signals (name / skillId / same-art+assoc).
    private func foldTargetNodeId(for def: MovementDefinition, nodes: [SkillNode]) -> String? {
        let titleKey = Self.searchKey(def.displayName)
        if let n = nodes.first(where: { Self.searchKey($0.title) == titleKey }) { return n.id }
        if let sid = def.skillId, let n = nodes.first(where: { $0.id == sid }) { return n.id }
        if let asset = ExerciseVisualAsset.existingAssetName(for: def),
           let n = nodes.first(where: { SkillTraditionalVisualResolver.assetName(for: $0) == asset
               && def.skillAssociations.contains($0.id) }) {
            return n.id
        }
        return nil
    }

    func testTwinMapIsSound() throws {
        let nodesById = Dictionary(uniqueKeysWithValues: SkillGraph.shared.nodes.map { ($0.id, $0) })
        for (exId, nodeId) in MovementCatalog.exerciseSkillTwins {
            let def = try XCTUnwrap(MovementCatalog.definition(for: exId), "twin key \(exId) is not a real movement")
            XCTAssertEqual(def.role, .canonicalExercise, "\(exId) should be a library exercise")
            let node = try XCTUnwrap(nodesById[nodeId], "twin value \(nodeId) is not a real skill node")

            XCTAssertEqual(
                Self.holdTemplates.contains(def.rankTemplate),
                Self.isHold(node.target),
                "metric mismatch: \(exId) (\(def.rankTemplate)) twins hold-skill? vs \(nodeId) target \(node.target.displayName)"
            )
            XCTAssertEqual(
                MovementCatalog.owningSkillId(forMovementId: exId), nodeId,
                "\(exId) must resolve to \(nodeId) through owningSkillId"
            )
        }
    }

    func testTwinMapIsComplete() {
        let nodes = SkillGraph.shared.nodes
        var foldingExercises: [String: String] = [:]
        for def in MovementCatalog.definitions where def.role == .canonicalExercise {
            if let nodeId = foldTargetNodeId(for: def, nodes: nodes) {
                foldingExercises[def.id] = nodeId
            }
        }

        let mapped = Set(MovementCatalog.exerciseSkillTwins.keys)
        let folding = Set(foldingExercises.keys)

        let missing = folding.subtracting(mapped)
        let extra = mapped.subtracting(folding)
        XCTAssertTrue(missing.isEmpty, "library exercises that fold into a skill but are missing from exerciseSkillTwins: \(missing.sorted())")
        XCTAssertTrue(extra.isEmpty, "exerciseSkillTwins entries that do not fold into any skill: \(extra.sorted())")

        // And where both agree on the exercise, they must agree on the skill.
        for ex in mapped.intersection(folding) {
            XCTAssertEqual(MovementCatalog.exerciseSkillTwins[ex], foldingExercises[ex],
                           "\(ex) maps to a different skill than it folds into")
        }
    }
}
