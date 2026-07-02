// UNBOUND/Services/Squads/SquadActivityService.swift
import Foundation

// MARK: - SquadActivityService
//
// Records squad-level activity events (proof challenge completions, title unlocks,
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
    private let sessionXP: SessionXPServiceProtocol
    /// Routes DEBUG local-only squad users to the cached-state feed instead of
    /// Supabase. Injectable so tests with non-UUID user ids still exercise the
    /// backend path.
    private let usesLocalOnlyFeed: (String) -> Bool
    private var observers: [NSObjectProtocol] = []
    private var recordedVowCompletionIds = Set<String>()

    convenience init() {
        self.init(
            backend: SquadActivityBackend.shared,
            auth: AuthService.shared,
            squadService: SquadService.shared,
            sessionXP: SessionXPService.shared,
            observesNotifications: !Self.isRunningUnderXCTest
        )
    }

    init(
        backend: SquadActivityBackendProtocol,
        auth: AuthServiceProtocol,
        squadService: SquadServiceProtocol,
        sessionXP: SessionXPServiceProtocol,
        observesNotifications: Bool = true,
        usesLocalOnlyFeed: @escaping (String) -> Bool = SquadUserIdentity.usesLocalOnlySquad
    ) {
        self.backend = backend
        self.auth = auth
        self.squadService = squadService
        self.sessionXP = sessionXP
        self.usesLocalOnlyFeed = usesLocalOnlyFeed
        if observesNotifications {
            observeTrialsNotifications()
        }
    }

    convenience init(
        backend: SquadActivityBackendProtocol,
        auth: AuthServiceProtocol,
        squadService: SquadServiceProtocol,
        observesNotifications: Bool = true,
        usesLocalOnlyFeed: @escaping (String) -> Bool = SquadUserIdentity.usesLocalOnlySquad
    ) {
        self.init(
            backend: backend,
            auth: auth,
            squadService: squadService,
            sessionXP: SessionXPService.shared,
            observesNotifications: observesNotifications,
            usesLocalOnlyFeed: usesLocalOnlyFeed
        )
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
        if usesLocalOnlyFeed(userId) {
            appendLocalEntry(entry, userId: userId)
        } else {
            await backend.insert(entry)
        }
        NotificationCenter.default.post(name: .squadActivityRecorded, object: entry)
    }

    /// DEBUG local-only squads have no Supabase identity, so their feed lives
    /// in the cached SquadState (capped like the remote fetch).
    private func appendLocalEntry(_ entry: SquadActivityEntry, userId: String) {
        var state = squadService.state(userId: userId)
        state.recentActivity = Array(([entry] + state.recentActivity).prefix(50))
        SquadStore.shared.save(state, userId: userId)
    }

    func fetchRecent(userId: String) async throws -> [SquadActivityEntry] {
        let state = squadService.state(userId: userId)
        guard let squad = state.currentSquad else { return [] }
        if usesLocalOnlyFeed(userId) {
            return state.recentActivity.filter { $0.squadId == squad.id }
        }
        return try await backend.fetchRecent(squadId: squad.id, limit: 50)
    }

    /// Sink for a detected linked session (a squadmate trained inside the user's
    /// overlap window). Applies the +20% LV bonus through `LinkedSessionEvaluator`
    /// and posts `.linkedSessionDetected` so `LinkedSessionToast` slides up.
    ///
    /// Trigger sources:
    ///   - The `detect_linked_sessions` Edge Function inserts a `squad_activity`
    ///     row of kind `linkedSession` and (Phase 10) pushes APNs to participants.
    ///   - The push handler / activity-feed hydration calls this method with the
    ///     base session XP from the user's just-recorded session.
    ///
    /// `baseSessionXP` is the **pre-affinity** session XP. The evaluator subtracts
    /// any affinity bonus already applied this session so the net stays +20%.
    func handleLinkedSessionDetected(
        userId: String,
        participantDisplayNames: [String],
        baseSessionXP: Int
    ) async {
        await LinkedSessionEvaluator.applyLinkedXPBonus(
            userId: userId,
            sessionXPDelta: baseSessionXP,
            service: sessionXP
        )
        let xpBonus = Int(Double(baseSessionXP) * 0.20)
        NotificationCenter.default.post(
            name: .linkedSessionDetected,
            object: nil,
            userInfo: [
                "participantDisplayNames": participantDisplayNames,
                "xpBonus": xpBonus
            ]
        )
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
                theme: TrialTheme(lane: vow.chosenCard.lane)
            ),
            userId: userId
        )
    }
}
