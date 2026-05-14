// UNBOUND/Services/Squads/SquadPresenceService.swift
import Foundation

// MARK: - SquadPresenceRow
//
// Private Codable mirror of the squad_presence Supabase table row.
// snake_case fields match the DB column names for automatic Codable decoding.

private struct SquadPresenceRow: Codable {
    let user_id: String
    let squad_id: String
    let workout_started_at: String   // ISO8601
    let expires_at: String           // ISO8601

    private static let iso8601Formatter = ISO8601DateFormatter()

    var toModel: SquadPresence? {
        guard
            let userId = UUID(uuidString: user_id),
            let squadId = UUID(uuidString: squad_id),
            let startedAt = Self.iso8601Formatter.date(from: workout_started_at),
            let expiresAt = Self.iso8601Formatter.date(from: expires_at)
        else { return nil }
        return SquadPresence(
            userId: userId,
            squadId: squadId,
            workoutStartedAt: startedAt,
            expiresAt: expiresAt
        )
    }
}

// MARK: - SquadPresenceService
//
// Manages the user's "currently in a workout" presence row in squad_presence.
//
// Realtime subscription decision:
//   No existing supabase-swift Realtime usage was found in this codebase.
//   Rather than introduce an untested Realtime wiring pattern in Phase 7,
//   `subscribeToSquadPresence` uses a 30-second polling fallback and posts
//   .squadPresenceChanged on each refresh. The subscribe/unsubscribe stubs
//   carry a TODO for Realtime replacement in Phase 17.
//
// ServiceContainer wiring is deferred to Phase 16.

@MainActor
final class SquadPresenceService: SquadPresenceServiceProtocol {
    static let shared = SquadPresenceService()
    private let logger = LoggingService.shared

    // Polling timer used as fallback until Realtime is wired (Phase 17).
    private var pollTimer: Task<Void, Never>?

    private init() {}

    deinit {
        pollTimer?.cancel()
    }

    // MARK: - SquadPresenceServiceProtocol

    func markInWorkout(userId: String, squadId: UUID) async {
        let now = Date()
        let expires = now.addingTimeInterval(3 * 3600)
        let iso = ISO8601DateFormatter()
        do {
            try await UnboundSupabase.client.database
                .from("squad_presence")
                .upsert([
                    "user_id": userId,
                    "squad_id": squadId.uuidString,
                    "workout_started_at": iso.string(from: now),
                    "expires_at": iso.string(from: expires)
                ])
                .execute()
        } catch {
            logger.log("SquadPresence.markInWorkout error: \(error)", level: .warning)
        }
    }

    func clearPresence(userId: String) async {
        do {
            try await UnboundSupabase.client.database
                .from("squad_presence")
                .delete()
                .eq("user_id", value: userId)
                .execute()
        } catch {
            logger.log("SquadPresence.clearPresence error: \(error)", level: .warning)
        }
    }

    func subscribeToSquadPresence(squadId: UUID) async {
        // TODO(squads-impl, Phase 17): Replace this polling timer with a Supabase
        // Realtime postgres_changes subscription:
        //
        //   let channel = UnboundSupabase.client.realtime.channel("squad-presence-\(squadId)")
        //   channel.onPostgresChange(
        //       AnyAction.self,
        //       schema: "public", table: "squad_presence",
        //       filter: "squad_id=eq.\(squadId.uuidString)"
        //   ) { [weak self] _ in
        //       Task { await self?.refreshPresence(squadId: squadId) }
        //   }
        //   try? await channel.subscribe()
        //   self.channel = channel  // store as Any? with the type from the SDK
        //
        // Polling fallback at 30s cadence until Realtime is verified.
        pollTimer?.cancel()
        pollTimer = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await self?.refreshPresence(squadId: squadId)
            }
        }
    }

    func unsubscribeFromSquadPresence() async {
        // TODO(squads-impl, Phase 17): also tear down the Realtime channel.
        pollTimer?.cancel()
        pollTimer = nil
    }

    // MARK: - Private

    private func refreshPresence(squadId: UUID) async {
        do {
            let rows: [SquadPresenceRow] = try await UnboundSupabase.client.database
                .from("squad_presence")
                .select()
                .eq("squad_id", value: squadId.uuidString)
                .execute()
                .value
            let models = rows.compactMap(\.toModel)
            NotificationCenter.default.post(name: .squadPresenceChanged, object: models)
        } catch {
            logger.log("SquadPresence.refresh error: \(error)", level: .warning)
        }
    }
}
