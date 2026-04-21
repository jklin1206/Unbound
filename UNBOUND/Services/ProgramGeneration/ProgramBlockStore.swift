import Foundation

/// Persistence for `ProgramBlock` records. Uses `DatabaseService` (local-first
/// file-backed JSON, Supabase-mirrored at a higher layer). Collection key:
/// `"program_blocks"`.
///
/// Why `actor`: the singleton `shared` instance is shared state. An actor
/// prevents data races. Tests that inject a different database use a separate
/// instance via `init(database:)`.
actor ProgramBlockStore {

    static let shared = ProgramBlockStore()

    private let database: DatabaseServiceProtocol
    private let collection = "program_blocks"

    init(database: DatabaseServiceProtocol = DatabaseService.shared) {
        self.database = database
    }

    /// Persist (or overwrite) a block record.
    func save(_ block: ProgramBlock) async {
        do {
            try await database.create(block, collection: collection, documentId: block.id)
        } catch {
            LoggingService.shared.log(
                "ProgramBlockStore.save failed: \(error)",
                level: .error,
                context: ["blockId": block.id, "userId": block.userId]
            )
        }
    }

    /// Return the block with the highest `blockNumber` for the user, or nil.
    func latestBlock(userId: String) async -> ProgramBlock? {
        let all = await blocks(userId: userId)
        return all.first   // blocks(userId:) returns descending
    }

    /// All blocks for a user, sorted by `blockNumber` descending (newest first).
    func blocks(userId: String) async -> [ProgramBlock] {
        do {
            let results: [ProgramBlock] = try await database.query(
                collection: collection,
                field: "userId",
                isEqualTo: userId,
                orderBy: nil,
                descending: false,
                limit: nil
            )
            return results.sorted(by: { $0.blockNumber > $1.blockNumber })
        } catch {
            LoggingService.shared.log(
                "ProgramBlockStore.blocks failed: \(error)",
                level: .error,
                context: ["userId": userId]
            )
            return []
        }
    }
}
