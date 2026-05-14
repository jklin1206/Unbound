import Foundation

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

    func generateThisWeek(squadId: UUID) async throws -> SquadMission {
        let weekIso = Self.currentWeekIso()
        // TODO(squads-impl): backend.fetchSquad + backend.fetchMembers
        let memberCount = 4  // fallback until SquadBackend fetch wires through
        let (kind, target) = SquadMissionCatalog.generate(squadId: squadId, weekIso: weekIso, memberCount: memberCount)
        let mission = SquadMission(
            id: UUID(),
            squadId: squadId,
            weekIso: weekIso,
            kind: kind,
            target: target,
            currentProgress: 0,
            completedAt: nil,
            createdAt: .now
        )
        // TODO(squads-impl, Phase 9): backend.insertSquadMission(mission) once Edge Function is deployed
        return mission
    }

    func currentMission(squadId: UUID) async -> SquadMission? {
        // TODO(squads-impl): backend.fetchCurrentMission(squadId:weekIso:)
        return nil
    }

    func recordProgress(log: WorkoutLog, userId: String) async {
        // Determine if log contributes to current mission.
        // For v1, increment a generic +1 per log. Refinement is follow-up.
        logger.log("SquadMissionService.recordProgress for user \(userId) — generic +1 (refinement pending)", level: .info)
    }

    func evaluateCompletion(squadId: UUID) async {
        guard let mission = await currentMission(squadId: squadId),
              mission.currentProgress >= mission.target,
              mission.completedAt == nil else { return }
        // TODO(squads-impl, Phase 9): backend.markMissionCompleted(missionId:)
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
