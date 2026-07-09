import Foundation

/// Publishes the current user's `SquadMemberFlair` to `squad_member_flair` and
/// reads squadmates' flair through the gated `squad_member_flair_for_squad` RPC.
///
/// Writes are RLS-guarded to the owner (auth.uid() = user_id); reads only succeed
/// for a squad the caller belongs to. Both no-op gracefully when the user isn't
/// cloud-linked (anonymous / dev builds), since there's no real Supabase session
/// to satisfy the policies.
enum SquadFlairService {
    private static let logger = LoggingService.shared

    /// Upsert the caller's own flair. Skips silently unless the current Supabase
    /// session matches `userId` (RLS would reject it anyway).
    static func publish(_ flair: SquadMemberFlair, userId: String) async {
        guard let uid = await UnboundSupabase.currentUserId, uid == userId else { return }

        struct Row: Encodable {
            let userId: String
            let flair: SquadMemberFlair
        }
        do {
            try await UnboundSupabase.client
                .from("squad_member_flair")
                .upsert(Row(userId: uid, flair: flair), onConflict: "user_id")
                .execute()
        } catch {
            logger.log("SquadFlair publish failed: \(error)", level: .warning)
        }
    }

    /// Every squadmate's flair, keyed by their user id. Empty on any failure or
    /// when the caller isn't cloud-linked.
    static func fetch(squadId: UUID) async -> [UUID: SquadMemberFlair] {
        guard await UnboundSupabase.isSignedIn else { return [:] }

        struct Params: Encodable { let pSquadId: String }
        struct FlairRow: Decodable {
            let userId: UUID
            let flair: SquadMemberFlair
        }
        do {
            let rows: [FlairRow] = try await UnboundSupabase.client
                .rpc("squad_member_flair_for_squad", params: Params(pSquadId: squadId.uuidString))
                .execute()
                .value
            return Dictionary(rows.map { ($0.userId, $0.flair) }, uniquingKeysWith: { first, _ in first })
        } catch {
            logger.log("SquadFlair fetch failed: \(error)", level: .warning)
            return [:]
        }
    }
}
