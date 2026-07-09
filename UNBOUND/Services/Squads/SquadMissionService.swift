import Foundation
import Supabase

@MainActor
protocol SquadMissionServiceProtocol: Sendable {
    func generateThisWeek(squadId: UUID) async throws -> SquadMission
    func currentMission(squadId: UUID) async -> SquadMission?
    /// Like `currentMission` but includes completed missions — returns the most
    /// recent mission for the current ISO week regardless of completed_at.
    func latestMission(squadId: UUID) async -> SquadMission?
    func recordProgress(log: WorkoutLog, userId: String, sourceLogId: String) async
    func evaluateCompletion(squadId: UUID) async
    /// Captain-only: pick a mission kind for the current week via the
    /// `pick_squad_mission` RPC. Returns nil when a mission already exists.
    func pickMission(squadId: UUID, kind: SquadMission.Kind) async throws -> SquadMission?
    /// Fetch per-member contribution totals for a mission (from the receipts ledger).
    func fetchMissionContributions(missionId: UUID) async throws -> [MissionContribution]
}

@MainActor
final class SquadMissionService: SquadMissionServiceProtocol {
    static let shared = SquadMissionService()
    private let backend: SquadBackendProtocol
    private let squadService: any SquadServiceProtocol
    private let remoteReadsEnabled: Bool
    private let logger = LoggingService.shared
    /// DEBUG local-only squads have no Supabase identity, so a captain-picked
    /// mission lives here for the week instead of in squad_missions.
    private var localMissions: [UUID: SquadMission] = [:]
    /// Injectable so unit tests aren't coupled to the shared AuthService state.
    private let usesLocalMissions: () -> Bool

    convenience init(remoteReadsEnabled: Bool = true) {
        self.init(
            backend: SquadBackend.shared,
            squadService: SquadService.shared,
            remoteReadsEnabled: remoteReadsEnabled
        )
    }

    init(
        backend: SquadBackendProtocol,
        squadService: any SquadServiceProtocol,
        remoteReadsEnabled: Bool = true,
        usesLocalMissions: @escaping () -> Bool = {
            guard let userId = AuthService.shared.currentUserId else { return false }
            return SquadUserIdentity.usesLocalOnlySquad(for: userId)
        }
    ) {
        self.backend = backend
        self.squadService = squadService
        self.remoteReadsEnabled = remoteReadsEnabled
        self.usesLocalMissions = usesLocalMissions
    }

    // MARK: - Private Codable row type

    // The squad_missions table uses `mission_kind` (not `kind`) and snake_case columns;
    // UnboundSupabase.dbDecoder uses .convertFromSnakeCase, so properties declared
    // with camelCase will auto-map. However `mission_kind` → `missionKind` is fine.
    private struct MissionRow: Codable {
        let id: UUID
        let squadId: UUID
        let weekIso: String
        let missionKind: String
        let target: Int
        let currentProgress: Int
        let completedAt: Date?
        let createdAt: Date

        func toModel() -> SquadMission? {
            guard let kind = SquadMission.Kind(rawValue: missionKind) else { return nil }
            return SquadMission(
                id: id,
                squadId: squadId,
                weekIso: weekIso,
                kind: kind,
                target: target,
                currentProgress: currentProgress,
                completedAt: completedAt,
                createdAt: createdAt
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
            memberCount = max(1, try await backend.fetchMembers(squadId: squadId).count)
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
        if let local = localMission(squadId: squadId), local.completedAt == nil { return local }
        guard remoteReadsEnabled, !currentUserUsesLocalSquad else { return nil }
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

    func latestMission(squadId: UUID) async -> SquadMission? {
        if let local = localMission(squadId: squadId) { return local }
        guard remoteReadsEnabled, !currentUserUsesLocalSquad else { return nil }
        let weekIso = Self.currentWeekIso()
        do {
            let rows: [MissionRow] = try await db
                .from("squad_missions")
                .select()
                .eq("squad_id", value: squadId.uuidString)
                .eq("week_iso", value: weekIso)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            return rows.first?.toModel()
        } catch {
            logger.log("SquadMissionService.latestMission error: \(error)", level: .warning)
            return nil
        }
    }

    func recordProgress(log: WorkoutLog, userId: String, sourceLogId: String) async {
        guard let squad = squadService.state(userId: userId).currentSquad else { return }

        // DEBUG local-only squads: advance the in-memory mission with the same
        // per-kind math the server RPC applies.
        if currentUserUsesLocalSquad {
            guard var mission = localMission(squadId: squad.id), mission.completedAt == nil else { return }
            let delta = Self.localDelta(for: mission.kind, log: log)
            guard delta > 0 else { return }
            mission.currentProgress += delta
            if mission.currentProgress >= mission.target {
                mission.completedAt = .now
                NotificationCenter.default.post(name: .squadMissionCompleted, object: mission)
            }
            localMissions[squad.id] = mission
            return
        }

        // Increment the squad's current-week mission via the
        // `increment_squad_mission_progress` RPC (SECURITY DEFINER, squad-
        // membership guarded). The RPC computes the real delta server-side from
        // the workout_logs.exercise_entries jsonb — the +1 here is a signal only.
        do {
            try await backend.incrementMissionProgress(
                squadId: squad.id,
                delta: 1,
                sourceLogId: sourceLogId
            )
        } catch {
            logger.log(
                "SquadMissionService.recordProgress increment failed: \(error)",
                level: .warning
            )
        }
    }

    /// Mirror of the server RPC's per-kind delta for the DEBUG local path.
    static func localDelta(for kind: SquadMission.Kind, log: WorkoutLog) -> Int {
        let workingSets = log.exerciseEntries
            .filter { !$0.skipped }
            .flatMap(\.sets)
            .filter { !$0.isWarmup }
        switch kind {
        case .totalSessions, .crewCoverage:
            return 1
        case .totalWeight:
            return workingSets.reduce(0) { total, set in
                guard let weight = set.weightKg, weight > 0, set.reps > 0 else { return total }
                return total + Int(weight * Double(set.reps))
            }
        case .totalReps:
            return workingSets.reduce(0) { $0 + max($1.reps, 0) }
        case .trainTogether:
            return 0
        }
    }

    func evaluateCompletion(squadId: UUID) async {
        guard let mission = await currentMission(squadId: squadId),
              mission.currentProgress >= mission.target,
              mission.completedAt == nil else { return }
        // Completion is marked by the evaluate_squad_mission Edge Function cron.
        // Post local notification so the UI can react immediately.
        NotificationCenter.default.post(name: .squadMissionCompleted, object: mission)
    }

    func pickMission(squadId: UUID, kind: SquadMission.Kind) async throws -> SquadMission? {
        if currentUserUsesLocalSquad {
            if let existing = localMission(squadId: squadId) { return existing }
            let memberCount: Int
            if let userId = AuthService.shared.currentUserId {
                memberCount = max(2, squadService.state(userId: userId).roster.count)
            } else {
                memberCount = 2
            }
            let mission = SquadMission(
                id: UUID(),
                squadId: squadId,
                weekIso: Self.currentWeekIso(),
                kind: kind,
                target: SquadMissionCatalog.target(for: kind, memberCount: memberCount),
                currentProgress: 0,
                completedAt: nil,
                createdAt: .now
            )
            localMissions[squadId] = mission
            return mission
        }
        return try await backend.pickSquadMission(squadId: squadId, kind: kind)
    }

    private var currentUserUsesLocalSquad: Bool {
        usesLocalMissions()
    }

    /// The local mission only counts for the current ISO week.
    private func localMission(squadId: UUID) -> SquadMission? {
        guard let mission = localMissions[squadId], mission.weekIso == Self.currentWeekIso() else {
            return nil
        }
        return mission
    }

    func fetchMissionContributions(missionId: UUID) async throws -> [MissionContribution] {
        try await backend.fetchMissionContributions(missionId: missionId)
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
