import Foundation
import Supabase

// MARK: - Supabase client (module-level singleton)
//
// Project: xwoemvkzrnnsvtupxctu
// Publishable (anon) key — safe to ship; RLS enforces per-user access.
// Service-role key is NEVER in this bundle; it lives in Edge Function
// secrets for operations that need to bypass RLS (Anthropic proxy etc.).
//
// Every UNBOUND Swift surface that needs a table query hits this single
// instance. DatabaseService wraps CRUD on top; services like UserService
// talk to the wrapper, never Supabase directly.

enum UnboundSupabase {

    /// JSONEncoder used for all Postgres writes. Maps Swift's camelCase
    /// property names to snake_case column names, encodes dates as ISO 8601.
    /// Recursively applied to nested types (jsonb columns get snake_case keys
    /// inside the JSON blob, which is consistent because reads use the
    /// matching decoder).
    static let dbEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    /// JSONDecoder used for all Postgres reads. Mirror of `dbEncoder`.
    static let dbDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Public (anon) client for user-scoped operations.
    static let client: SupabaseClient = {
        SupabaseClient(
            supabaseURL: URL(string: "https://xwoemvkzrnnsvtupxctu.supabase.co")!,
            supabaseKey: "sb_publishable_fV5czmcBduBDMSK7BkEcCw_ahyzYdGF",
            options: SupabaseClientOptions(
                db: SupabaseClientOptions.DatabaseOptions(
                    encoder: dbEncoder,
                    decoder: dbDecoder
                ),
                // Opt into the fixed session-emission behavior (supabase-swift
                // PR #822). Without this the SDK logs a deprecation warning and,
                // in the next major, would silently change behavior. With it,
                // the locally stored session is emitted immediately as the
                // initial session regardless of validity — callers that gate on
                // the initial session must check `session.isExpired` themselves.
                // All other auth defaults (keychain storage, PKCE, auto-refresh)
                // are preserved by the iOS convenience initializer.
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }()

    /// Convenience — the currently authenticated user's UUID, or nil if
    /// the user hasn't signed in with Apple yet (still on local-UUID).
    static var currentUserId: String? {
        get async {
            do {
                let session = try await client.auth.session
                return session.user.id.uuidString
            } catch {
                return nil
            }
        }
    }

    /// True once the user has successfully authenticated via Sign in with Apple.
    static var isSignedIn: Bool {
        get async {
            await currentUserId != nil
        }
    }
}
