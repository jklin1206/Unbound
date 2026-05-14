import Foundation
import Supabase

@MainActor
protocol SquadMissionServiceProtocol: Sendable {
    func generateThisWeek(squadId: UUID) async throws -> SquadMission
    func currentMission(squadId: UUID) async -> SquadMission?
    func recordProgress(log: WorkoutLog, userId: String) async
    func evaluateCompletion(squadId: UUID) async
}

@MainActor
final class SquadMissionService: SquadMissionServiceProtocol {
    static let shared = SquadMissionService()
    private let backend: SquadBackendProtocol
    private let squadService: any SquadServiceProtocol
    private let logger = LoggingService.shared

    init(
        backend: SquadBackendProtocol = SquadBackend.shared,
        squadService: any SquadServiceProtocol = SquadService.shared
    ) {
        self.backend = backend
        self.squadService = squadService
    }

    // MARK: - Private Codable row type

    // The squad_missions table uses `mission_kind` (not `kind`) and snake_case columns.
    // UnboundSupabase.dbDecoder uses .convertFromSnakeCase, so properties declared
    // with camelCase will auto-map. However `mission_kind` → `missionKind` is fine.
    private struct MissionRow: Codable {
        let id: UUID
        let squad_id: UUID
        let week_iso: String
        let mission_kind: String
        let target: Int
        let current_progress: Int
        let completed_at: Date?
        let created_at: Date

        func toModel() -> SquadMission? {
            guard let kind = SquadMission.Kind(rawValue: mission_kind) else { return nil }
            return SquadMission(
                id: id,
                squadId: squad_id,
                weekIso: week_iso,
                kind: kind,
                target: target,
                currentProgress: current_progress,
                completedAt: completed_at,
                createdAt: created_at
            )
        }
    }

    private var db: PostgrestClient { UnboundSupabase.client.schema("public") }

    // MARK: - SquadMissionServiceProtocol

    func generateThisWeek(squadId: UUID) async throws -> SquadMission {
        // NOTE: Missions are generated server-side by the `evaluate_squad_mission` cron
        // (supabase/functions/evaluate_squad_mission/index.ts). Squad_missions has
        // `with check (false)` for INSERT from authenticated callers — only the service-
        // role key used by the Edge Function can write new rows.
        //
        // This method returns the current mission if one exists, or constructs an
        // ephemeral model for local display if the cron hasn't run yet. It does NOT
        // write to the database.
        if let existing = await currentMission(squadId: squadId) {
            return existing
        }
        let weekIso = Self.currentWeekIso()
        let memberCount: Int
        do {
            memberCount = try await backend.fetchMembers(squadId: squadId).count
        } catch {
            memberCount = 4  // safe fallback
        }
        let (kind, target) = SquadMissionCatalog.generate(
            squadId: squadId, weekIso: weekIso, memberCount: memberCount
        )
        return SquadMission(
            id: UUID(),
            squadId: squadId,
            weekIso: weekIso,
            kind: kind,
            target: target,
            currentProgress: 0,
            completedAt: nil,
            createdAt: .now
        )
    }

    func currentMission(squadId: UUID) async -> SquadMission? {
        let weekIso = Self.currentWeekIso()
        do {
            let rows: [MissionRow] = try await db
                .from("squad_missions")
                .select()
                .eq("squad_id", value: squadId.uuidString)
                .eq("week_iso", value: weekIso)
                .is("completed_at", value: nil)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            return rows.first?.toModel()
        } catch {
            logger.log("SquadMissionService.currentMission error: \(error)", level: .warning)
            return nil
        }
    }

    func recordProgress(log: WorkoutLog, userId: String) async {
        // Generic +1 per log — mission-kind-specific refinement is a follow-up.
        logger.log(
            "SquadMissionService.recordProgress for user \(userId) — generic +1 (refinement pending)",
            level: .info
        )
    }

    func evaluateCompletion(squadId: UUID) async {
        guard let mission = await currentMission(squadId: squadId),
              mission.currentProgress >= mission.target,
              mission.completedAt == nil else { return }
        // Completion is marked by the evaluate_squad_mission Edge Function cron.
        // Post local notification so the UI can react immediately.
        NotificationCenter.default.post(name: .squadMissionCompleted, object: mission)
    }

    static func currentWeekIso() -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        let date = Date()
        let week = cal.component(.weekOfYear, from: date)
        let year = cal.component(.yearForWeekOfYear, from: date)
        return String(format: "%d-W%02d", year, week)
    }
}
