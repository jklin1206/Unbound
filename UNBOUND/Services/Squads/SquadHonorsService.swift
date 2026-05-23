import Foundation
import Supabase

@MainActor
protocol SquadHonorsServiceProtocol: Sendable {
    func currentHonors(squadId: UUID) async -> [WeeklyHonor]
    func recordHonor(_ honor: WeeklyHonor) async
}

@MainActor
final class SquadHonorsService: SquadHonorsServiceProtocol {
    static let shared = SquadHonorsService()
    private let backend: SquadBackendProtocol
    private let logger = LoggingService.shared

    init(backend: SquadBackendProtocol = SquadBackend.shared) {
        self.backend = backend
    }

    // MARK: - Private Codable row type

    private struct HonorRow: Codable {
        let id: UUID
        let squad_id: UUID
        let week_iso: String
        let honor_kind: String
        let recipient_user_id: UUID
        let awarded_at: Date

        func toModel() -> WeeklyHonor? {
            guard let kind = WeeklyHonor.Kind(rawValue: honor_kind) else { return nil }
            return WeeklyHonor(
                id: id,
                squadId: squad_id,
                weekIso: week_iso,
                kind: kind,
                recipientUserId: recipient_user_id,
                awardedAt: awarded_at
            )
        }
    }

    private var db: PostgrestClient { UnboundSupabase.client.schema("public") }

    // MARK: - SquadHonorsServiceProtocol

    func currentHonors(squadId: UUID) async -> [WeeklyHonor] {
        let weekIso = SquadMissionService.currentWeekIso()
        do {
            let rows: [HonorRow] = try await db
                .from("squad_weekly_honors")
                .select()
                .eq("squad_id", value: squadId.uuidString)
                .eq("week_iso", value: weekIso)
                .execute()
                .value
            return rows.compactMap { $0.toModel() }
        } catch {
            logger.log("SquadHonorsService.currentHonors error: \(error)", level: .warning)
            return []
        }
    }

    func recordHonor(_ honor: WeeklyHonor) async {
        // NOTE: squad_weekly_honors has `with check (false)` for INSERT from authenticated
        // callers — only the service-role key used by the `assign_weekly_honors` cron can
        // write new rows. Client-side we post the notification so the UI reacts immediately
        // to server-pushed data (e.g. via a real-time subscription or after a poll).
        NotificationCenter.default.post(name: .weeklyHonorReceived, object: honor)
    }
}
