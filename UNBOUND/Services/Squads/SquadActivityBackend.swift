// UNBOUND/Services/Squads/SquadActivityBackend.swift
import Foundation

// MARK: - Production backend
//
// Reads/writes to the `squad_activity` Supabase table.
// Supabase-swift SDK usage — stubs TODO until squads schema is deployed.
// Tests never touch this file — they use MockSquadActivityBackend.

final class SquadActivityBackend: SquadActivityBackendProtocol, @unchecked Sendable {
    static let shared = SquadActivityBackend()
    private let logger = LoggingService.shared

    private init() {}

    func insert(_ entry: SquadActivityEntry) async {
        // TODO(squads-impl, Phase 9): Insert entry into squad_activity via Supabase.
        // Shape:
        //   try await UnboundSupabase.client.database
        //       .from("squad_activity")
        //       .insert(SquadActivityRow(from: entry))
        //       .execute()
        logger.log("SquadActivityBackend.insert stub — entry kind: \(entry.kind.rawValue)", level: .debug)
    }

    func fetchRecent(squadId: UUID, limit: Int) async throws -> [SquadActivityEntry] {
        // TODO(squads-impl, Phase 9): Fetch from squad_activity via Supabase.
        // Shape:
        //   let rows: [SquadActivityRow] = try await UnboundSupabase.client.database
        //       .from("squad_activity")
        //       .select()
        //       .eq("squad_id", value: squadId.uuidString)
        //       .order("created_at", ascending: false)
        //       .limit(limit)
        //       .execute()
        //       .value
        //   return rows.map(\.toModel)
        logger.log("SquadActivityBackend.fetchRecent stub — squadId: \(squadId)", level: .debug)
        return []
    }
}
