import XCTest
@testable import UNBOUND

/// Dumps the COMPLETE twin map: for every skill node, every movement record
/// (library exercise + skill drill) that the rank library folds into it, with
/// all three name strings side by side. This is the ground-truth source for the
/// canonical-name reconciliation table (the "same movement, three names" cleanup)
/// - it runs the real `ProgramRankLibraryView.movementFoldsIntoShownSkill`
/// signals, not a hand-guessed list.
///
///   xcodebuild test ... -only-testing:UNBOUNDTests/MovementFoldMapDumpTests
final class MovementFoldMapDumpTests: XCTestCase {

    private struct NodeInfo {
        let id: String
        let title: String
        let asset: String?
        let criterionExercise: String
        let targetKind: String
    }

    private static func targetKind(_ requirement: NodeRequirement) -> String {
        switch requirement {
        case .weightMultiplier: return "weight"
        case .reps(_, _, let load): return load == nil ? "reps" : "reps+load"
        case .hold: return "hold"
        case .steps: return "steps"
        case .carry: return "carry"
        case .composite: return "composite"
        }
    }

    private static func searchKey(_ s: String) -> String {
        String(String(s).lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    func testDumpFoldMap() throws {
        let nodes: [NodeInfo] = SkillGraph.shared.nodes.map { node in
            NodeInfo(
                id: node.id,
                title: node.title,
                asset: SkillTraditionalVisualResolver.assetName(for: node),
                criterionExercise: node.target.displayName,
                targetKind: Self.targetKind(node.target)
            )
        }

        // Replicates movementFoldsIntoShownSkill's three signals, but resolves the
        // TARGET node (not just a bool) so we can group + compare names.
        func foldTarget(for def: MovementDefinition) -> NodeInfo? {
            let titleKey = Self.searchKey(def.displayName)
            if let n = nodes.first(where: { Self.searchKey($0.title) == titleKey }) { return n }
            if let sid = def.skillId, let n = nodes.first(where: { $0.id == sid }) { return n }
            if let asset = ExerciseVisualAsset.existingAssetName(for: def),
               let n = nodes.first(where: { $0.asset == asset && def.skillAssociations.contains($0.id) }) {
                return n
            }
            return nil
        }

        let foldRoles: Set<MovementRole> = [.canonicalExercise, .skillDrill]
        var groups: [String: [[String: String]]] = [:]
        for def in MovementCatalog.definitions where foldRoles.contains(def.role) {
            guard let node = foldTarget(for: def) else { continue }
            groups[node.id, default: []].append([
                "id": def.id,
                "name": def.displayName,
                "role": "\(def.role)",
                "rankStandard": def.rankStandardMovementId,
                "rankTemplate": "\(def.rankTemplate)",
                "skillId": def.skillId ?? ""
            ])
        }

        // Emit one entry per node that has >=1 folded movement, sorted, with the
        // node's own title + criterion so name divergence is obvious.
        var out: [[String: Any]] = []
        for node in nodes where groups[node.id] != nil {
            let folded = groups[node.id]!
            let allNames = Set([node.title] + folded.map { $0["name"]! }).map { Self.searchKey($0) }
            out.append([
                "skillNodeId": node.id,
                "skillNodeTitle": node.title,
                "criterion": node.criterionExercise,
                "targetKind": node.targetKind,
                "divergentNames": Set(allNames).count > 1,
                "folded": folded.sorted { ($0["role"] ?? "") < ($1["role"] ?? "") }
            ])
        }
        out.sort { ($0["skillNodeId"] as! String) < ($1["skillNodeId"] as! String) }

        let data = try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys])
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = repo.appendingPathComponent("docs/asset-sets/movement-fold-map.json")
        try data.write(to: url)

        let divergent = out.filter { ($0["divergentNames"] as? Bool) == true }
        print("FOLD MAP: \(out.count) skills have folded twins; \(divergent.count) have DIVERGENT names. Wrote \(url.path)")
        XCTAssertFalse(out.isEmpty)
    }
}
