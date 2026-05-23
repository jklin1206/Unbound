import Foundation
import Supabase

// MARK: - SupabaseDatabase
//
// Typed wrapper around UnboundSupabase.client for Postgres table operations.
// New Phase 2 code (ProgressionState, plan actions, etc.) reads/writes
// through this. Legacy local-JSON DatabaseService stays in place and gets
// migrated to cloud after Sign in with Apple lands in P2a.3.
//
// Every method requires an authenticated user (RLS enforces this on the
// backend; we short-circuit client-side to avoid pointless network calls).
// Before auth is wired, calls throw SupabaseDatabaseError.notAuthenticated.
//
// All models used here must:
//   - Conform to Codable
//   - Have property names that map cleanly to snake_case column names
//     (enable .convertToSnakeCase keyDecodingStrategy on the encoder/decoder
//      OR explicit CodingKeys in the struct)

enum SupabaseDatabaseError: Error {
    case notAuthenticated
    case invalidResponse
    case decodeFailed(underlying: Error)
}

final class SupabaseDatabase: @unchecked Sendable {
    static let shared = SupabaseDatabase()
    private let logger = LoggingService.shared

    private init() {}

    // MARK: Generic CRUD

    /// Insert-or-update (upsert) a Codable row in the given table. Uses
    /// the model's primary key column (`id` by default) for conflict
    /// resolution. Returns the row as stored.
    @discardableResult
    func upsert<T: Codable & Sendable>(
        _ object: T,
        into table: String,
        onConflict: String = "id"
    ) async throws -> T {
        try await requireAuth()
        do {
            let result: T = try await UnboundSupabase.client
                .from(table)
                .upsert(object, onConflict: onConflict)
                .select()
                .single()
                .execute()
                .value
            return result
        } catch {
            logger.log("Supabase upsert failed: \(error)", level: .error, context: ["table": table])
            throw error
        }
    }

    /// Fetch a single row by primary key (default `id`).
    func fetchOne<T: Codable & Sendable>(
        from table: String,
        keyedBy keyColumn: String = "id",
        equals value: String
    ) async throws -> T? {
        try await requireAuth()
        do {
            let result: T = try await UnboundSupabase.client
                .from(table)
                .select()
                .eq(keyColumn, value: value)
                .single()
                .execute()
                .value
            return result
        } catch {
            // PGRST116 = 0 rows returned — expected for "not found", not an error
            let errStr = String(describing: error)
            if errStr.contains("PGRST116") || errStr.contains("contains 0 rows") {
                return nil
            }
            logger.log("Supabase fetchOne failed: \(error)", level: .error, context: ["table": table])
            throw error
        }
    }

    /// Query rows where `column == value`. Supports ordering + limit.
    ///
    /// Supabase-swift changes the builder type on `.order`/`.limit`
    /// (Filter → Transform). Branch explicitly to keep the chain strongly typed.
    func query<T: Codable & Sendable>(
        from table: String,
        whereColumn column: String,
        equals value: String,
        orderBy: String? = nil,
        ascending: Bool = false,
        limit: Int? = nil
    ) async throws -> [T] {
        try await requireAuth()
        do {
            let filtered = UnboundSupabase.client
                .from(table)
                .select()
                .eq(column, value: value)

            switch (orderBy, limit) {
            case let (.some(col), .some(cap)):
                return try await filtered
                    .order(col, ascending: ascending)
                    .limit(cap)
                    .execute()
                    .value
            case let (.some(col), .none):
                return try await filtered
                    .order(col, ascending: ascending)
                    .execute()
                    .value
            case let (.none, .some(cap)):
                return try await filtered
                    .limit(cap)
                    .execute()
                    .value
            case (.none, .none):
                return try await filtered
                    .execute()
                    .value
            }
        } catch {
            logger.log("Supabase query failed: \(error)", level: .error, context: ["table": table])
            throw error
        }
    }

    /// Delete a row by primary key.
    func delete(
        from table: String,
        keyedBy keyColumn: String = "id",
        equals value: String
    ) async throws {
        try await requireAuth()
        do {
            try await UnboundSupabase.client
                .from(table)
                .delete()
                .eq(keyColumn, value: value)
                .execute()
        } catch {
            logger.log("Supabase delete failed: \(error)", level: .error, context: ["table": table])
            throw error
        }
    }

    // MARK: - Patch a partial field set
    //
    // Supabase-swift patch() takes an Encodable payload. Use a lightweight
    // struct or [String: AnyJSON] for the update set.
    func patch<Payload: Encodable & Sendable>(
        _ payload: Payload,
        in table: String,
        keyedBy keyColumn: String = "id",
        equals value: String
    ) async throws {
        try await requireAuth()
        do {
            try await UnboundSupabase.client
                .from(table)
                .update(payload)
                .eq(keyColumn, value: value)
                .execute()
        } catch {
            logger.log("Supabase patch failed: \(error)", level: .error, context: ["table": table])
            throw error
        }
    }

    // MARK: - Current user id (from Supabase auth session)

    /// Returns the authenticated user's UUID string. Throws if not signed in.
    func currentUserId() async throws -> String {
        guard let uid = await UnboundSupabase.currentUserId else {
            throw SupabaseDatabaseError.notAuthenticated
        }
        return uid
    }

    // MARK: - Auth guard

    private func requireAuth() async throws {
        guard await UnboundSupabase.isSignedIn else {
            throw SupabaseDatabaseError.notAuthenticated
        }
    }
}
