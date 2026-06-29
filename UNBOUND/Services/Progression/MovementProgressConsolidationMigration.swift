import Foundation

/// One-time LOCAL migration that consolidates split `movement_progress` rows
/// created before a movement's rank standards were unified (P3 of the movement
/// unification). When a skill drill began routing its XP into its canonical
/// library-exercise standard, any XP already banked under the drill's own id
/// must fold into the canonical row so no progress is lost or double-counted.
///
/// For each `retired -> canonical` pair in
/// `MovementCatalog.skillDrillCanonicalStandard`, the retired row is merged into
/// the canonical row (sum AP, keep best metrics, union the dedupe sets) and then
/// deleted. `movement_progress` is local-only
/// (`RemoteSync.localOnlyCollections`), so there is no server migration.
///
/// Idempotent: guarded by a per-user UserDefaults flag, and self-healing even
/// without it because the retired row is deleted after the first merge (a second
/// pass finds nothing to merge). The append-only audit collections
/// (`movement_ap_gains`, `movement_progress_prior_states/source_receipts`) are
/// left as-is; they do not feed the displayed total, which reads the merged
/// state, and the unioned `processedSourceLogIds` prevents any re-application.
@MainActor
enum MovementProgressConsolidationMigration {

    private static let flagKey = "unbound.movementProgress.consolidatedV1"

    /// retired standard id -> canonical standard id
    static var consolidations: [String: String] { MovementCatalog.skillDrillCanonicalStandard }

    @discardableResult
    static func migrateIfNeeded(
        userId: String,
        database: any DatabaseServiceProtocol = SyncedDatabase.shared,
        defaults: UserDefaults = .standard
    ) async -> Bool {
        let key = "\(flagKey).\(userId)"
        guard !defaults.bool(forKey: key) else { return false }

        var didMerge = false
        for (retiredId, canonicalId) in consolidations where retiredId != canonicalId {
            if await merge(userId: userId, retiredId: retiredId, canonicalId: canonicalId, database: database) {
                didMerge = true
            }
        }
        defaults.set(true, forKey: key)
        return didMerge
    }

    private static func merge(
        userId: String,
        retiredId: String,
        canonicalId: String,
        database: any DatabaseServiceProtocol
    ) async -> Bool {
        let retiredDoc = "\(userId):\(retiredId)"
        guard let retired: MovementProgressState = try? await database.read(
            collection: "movement_progress",
            documentId: retiredDoc
        ) else {
            return false   // nothing banked under the retired standard
        }

        let canonicalDoc = "\(userId):\(canonicalId)"
        let display = MovementCatalog.definition(for: canonicalId)?.displayName ?? retired.displayName
        let template = MovementCatalog.definition(for: canonicalId)?.rankTemplate ?? retired.rankTemplate

        var merged: MovementProgressState = (try? await database.read(
            collection: "movement_progress",
            documentId: canonicalDoc
        )) ?? MovementProgressState(
            userId: userId,
            rankStandardMovementId: canonicalId,
            displayName: display,
            rankTemplate: template
        )

        merged.merge(from: retired)
        merged.displayName = display
        merged.rankTemplate = template

        do {
            try await database.create(merged, collection: "movement_progress", documentId: canonicalDoc)
            try await database.delete(collection: "movement_progress", documentId: retiredDoc)
            return true
        } catch {
            LoggingService.shared.log(
                "Movement progress consolidation failed: \(error)",
                level: .warning,
                context: ["retired": retiredDoc, "canonical": canonicalDoc]
            )
            return false
        }
    }
}
