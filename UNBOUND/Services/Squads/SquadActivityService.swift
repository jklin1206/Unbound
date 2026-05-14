// UNBOUND/Services/Squads/SquadActivityService.swift
import Foundation

// MARK: - SquadActivityService
//
// Records squad-level activity events (trial completions, title unlocks,
// linked sessions, member joins, affinity changes, streak extensions).
//
// On init it installs NotificationCenter observers for:
//   .trialCompleted  → record(.trialCompleted, ...)
//   .titleUnlocked   → record(.titleUnlocked, ...)
//
// Dependencies are injected so tests run fully in-memory.
// ServiceContainer wiring is deferred to Phase 16.

@MainActor
final class SquadActivityService: SquadActivityServiceProtocol {
    static let shared = SquadActivityService()

    private let backend: SquadActivityBackendProtocol
    private let auth: AuthServiceProtocol
    private let squadService: SquadServiceProtocol
    private var observers: [NSObjectProtocol] = []

    init(
        backend: SquadActivityBackendProtocol = SquadActivityBackend.shared,
        auth: AuthServiceProtocol = AuthService.shared,
        squadService: SquadServiceProtocol = SquadService.shared
    ) {
        self.backend = backend
        self.auth = auth
        self.squadService = squadService
        observeTrialsNotifications()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - SquadActivityServiceProtocol

    func record(kind: SquadActivityEntry.Kind, payload: SquadActivityPayload, userId: String) async {
        // Skip if user is not in a squad.
        guard let squad = squadService.state(userId: userId).currentSquad else { return }

        let entry = SquadActivityEntry(
            id: UUID(),
            squadId: squad.id,
            userId: UUID(uuidString: userId) ?? UUID(),
            kind: kind,
            payload: payload,
            createdAt: .now
        )
        await backend.insert(entry)
        NotificationCenter.default.post(name: .squadActivityRecorded, object: entry)
    }

    func fetchRecent(userId: String) async throws -> [SquadActivityEntry] {
        guard let squad = squadService.state(userId: userId).currentSquad else { return [] }
        return try await backend.fetchRecent(squadId: squad.id, limit: 50)
    }

    // MARK: - Private

    private func observeTrialsNotifications() {
        // .trialCompleted posts a Trial as object.
        // Trial.chosenCard is a TrialCard with displayName + theme.
        let trialObs = NotificationCenter.default.addObserver(
            forName: .trialCompleted, object: nil, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let trial = note.object as? Trial else { return }
                guard let userId = self.auth.currentUserId else { return }
                await self.record(
                    kind: .trialCompleted,
                    payload: .trialCompleted(
                        trialName: trial.chosenCard.displayName,
                        theme: trial.chosenCard.theme
                    ),
                    userId: userId
                )
            }
        }

        // .titleUnlocked posts a TitleID as object.
        let titleObs = NotificationCenter.default.addObserver(
            forName: .titleUnlocked, object: nil, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let titleId = note.object as? TitleID else { return }
                guard let userId = self.auth.currentUserId else { return }
                await self.record(
                    kind: .titleUnlocked,
                    payload: .titleUnlocked(titleId: titleId),
                    userId: userId
                )
            }
        }

        observers = [trialObs, titleObs]
    }
}
