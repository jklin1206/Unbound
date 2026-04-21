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

    /// Public (anon) client for user-scoped operations.
    static let client: SupabaseClient = {
        SupabaseClient(
            supabaseURL: URL(string: "https://xwoemvkzrnnsvtupxctu.supabase.co")!,
            supabaseKey: "sb_publishable_fV5czmcBduBDMSK7BkEcCw_ahyzYdGF"
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
