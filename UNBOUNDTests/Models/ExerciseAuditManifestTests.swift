import XCTest
import UIKit
@testable import UNBOUND

/// Not an assertion suite — a manifest dumper for the exercise audit pipeline.
/// When `UNBOUND_AUDIT_MANIFEST_PATH` is set (pass as
/// `TEST_RUNNER_UNBOUND_AUDIT_MANIFEST_PATH` to xcodebuild), writes a JSON
/// manifest of every visual-bearing movement — id, name, role, slot,
/// equipment, and the resolved art asset — the ground truth the
/// name↔art↔equipment audit verifies against. Skips otherwise.
final class ExerciseAuditManifestTests: XCTestCase {
    private struct Row: Codable {
        let id: String
        let displayName: String
        let role: String
        let slot: String
        let equipment: [String]
        let equipmentLabels: [String]
        let assetName: String?
        let canonicalExerciseName: String?
        let aliases: [String]
    }

    func testDumpManifestIfRequested() throws {
        guard let path = ProcessInfo.processInfo.environment["UNBOUND_AUDIT_MANIFEST_PATH"] else {
            throw XCTSkip("UNBOUND_AUDIT_MANIFEST_PATH not set — manifest dump not requested.")
        }

        let visualRoles: Set<MovementRole> = [
            .canonicalExercise, .skillTarget, .skillDrill,
            .cardioModality, .carrySled, .mobilityDuration
        ]
        let rows = MovementCatalog.definitions
            .filter { visualRoles.contains($0.role) }
            .map { definition in
                Row(
                    id: definition.id,
                    displayName: definition.displayName,
                    role: "\(definition.role)",
                    slot: "\(definition.movementSlot)",
                    equipment: definition.equipment.map { "\($0)" },
                    equipmentLabels: ExerciseLibrary.equipmentLabels(for: definition),
                    assetName: ExerciseVisualAsset.existingAssetName(for: definition),
                    canonicalExerciseName: definition.canonicalExerciseName,
                    aliases: definition.aliases
                )
            }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(rows).write(to: URL(fileURLWithPath: path))
    }
}
