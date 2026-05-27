// UNBOUND/Services/Squads/SquadActivityService.swift
import Foundation

// MARK: - SquadActivityService
//
// Records squad-level activity events (weekly vow completions, title unlocks,
// linked sessions, member joins, affinity changes, streak extensions).
//
// On init it installs NotificationCenter observers for:
//   .weeklyVowCompleted / .trialCompleted adapter -> record(.trialCompleted, ...)
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
    private var recordedVowCompletionIds = Set<String>()

    convenience init() {
        self.init(
            backend: SquadActivityBackend.shared,
            auth: AuthService.shared,
            squadService: SquadService.shared,
            observesNotifications: !Self.isRunningUnderXCTest
        )
    }

    init(
        backend: SquadActivityBackendProtocol,
        auth: AuthServiceProtocol,
        squadService: SquadServiceProtocol,
        observesNotifications: Bool = true
    ) {
        self.backend = backend
        self.auth = auth
        self.squadService = squadService
        if observesNotifications {
            observeTrialsNotifications()
        }
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
            userId: SquadUserIdentity.uuid(from: userId) ?? UUID(),
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

    private static var isRunningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func observeTrialsNotifications() {
        let vowObs = NotificationCenter.default.addObserver(
            forName: .weeklyVowCompleted, object: nil, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.recordWeeklyVowCompletion(note)
            }
        }

        let legacyTrialObs = NotificationCenter.default.addObserver(
            forName: .trialCompleted, object: nil, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.recordWeeklyVowCompletion(note)
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

        observers = [vowObs, legacyTrialObs, titleObs]
    }

    private func recordWeeklyVowCompletion(_ note: Notification) async {
        guard let vow = note.object as? WeeklyVow else { return }
        guard !recordedVowCompletionIds.contains(vow.id) else { return }
        guard let userId = auth.currentUserId else { return }
        recordedVowCompletionIds.insert(vow.id)
        await record(
            kind: .trialCompleted,
            payload: .trialCompleted(
                trialName: vow.chosenCard.displayName,
                theme: vow.chosenCard.theme
            ),
            userId: userId
        )
    }
}
