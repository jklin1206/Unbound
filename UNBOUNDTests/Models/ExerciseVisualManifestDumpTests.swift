import XCTest
import UIKit
@testable import UNBOUND

/// Dumps the AUTHORITATIVE visual manifest: for every movement and skill node the
/// app renders, the EXACT asset name the resolver returns and whether it loads -
/// using the same resolver calls the app uses at runtime
/// (`ExerciseVisualAsset.existingAssetName(for:)` and
/// `SkillTraditionalVisualResolver.assetName(for:)`).
///
/// `scripts/gen_library.py` (the movement-library review sheet) consumes
/// `docs/asset-sets/exercise-visual-manifest.json` so the sheet shows EXACTLY the
/// image the code resolves - no python-guessed asset names. Re-run this whenever
/// art or resolution changes:
///   xcodebuild test ... -only-testing:UNBOUNDTests/ExerciseVisualManifestDumpTests
final class ExerciseVisualManifestDumpTests: XCTestCase {

    private static let visualBearingRoles: Set<MovementRole> = [
        .canonicalExercise,
        .skillTarget,
        .skillDrill,
        .cardioModality,
        .carrySled,
        .mobilityDuration
    ]

    func testDumpVisualManifest() throws {
        var entries: [[String: Any]] = []

        for def in MovementCatalog.definitions where Self.visualBearingRoles.contains(def.role) {
            let asset = ExerciseVisualAsset.existingAssetName(for: def)
            let loads = asset.flatMap { UIImage(named: $0) } != nil
            entries.append([
                "id": def.id,
                "displayName": def.displayName,
                "role": "\(def.role)",
                "asset": asset ?? "",
                "loads": loads
            ])
        }

        for node in SkillGraph.shared.nodes {
            let asset = SkillTraditionalVisualResolver.assetName(for: node)
            let loads = asset.flatMap { UIImage(named: $0) } != nil
            entries.append([
                "id": node.id,
                "displayName": node.title,
                "role": "skillNode",
                "asset": asset ?? "",
                "loads": loads
            ])
        }

        let data = try JSONSerialization.data(
            withJSONObject: entries,
            options: [.prettyPrinted, .sortedKeys]
        )

        // Repo root from this source file: <repo>/UNBOUNDTests/Models/<thisFile>
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let out = repo.appendingPathComponent("docs/asset-sets/exercise-visual-manifest.json")
        try data.write(to: out)

        let missing = entries.filter { ($0["loads"] as? Bool) != true }
        print("VISUAL MANIFEST: wrote \(entries.count) entries to \(out.path); \(missing.count) do not load")
        XCTAssertFalse(entries.isEmpty, "manifest should not be empty")
    }
}
