import Foundation

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

    func currentHonors(squadId: UUID) async -> [WeeklyHonor] {
        // TODO(squads-impl): backend.fetchHonors(squadId:weekIso:)
        return []
    }

    func recordHonor(_ honor: WeeklyHonor) async {
        // TODO(squads-impl): backend.insertHonor(honor)
        NotificationCenter.default.post(name: .weeklyHonorReceived, object: honor)
    }
}
