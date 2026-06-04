// UNBOUND/Services/Squads/SquadService.swift
import Foundation

// MARK: - SquadService
//
// @MainActor service owning all squad mutation logic.
//
// Dependencies:
//   store   — UserDefaults JSON cache (SquadStore)
//   backend — thin Supabase abstraction (SquadBackendProtocol)
//   auth    — current user identity (AuthServiceProtocol)
//
// Note: the service intentionally does NOT depend on DatabaseServiceProtocol
// because the squad tables live in Supabase (not the local file-backed
// DatabaseService). SquadBackendProtocol isolates the Supabase calls so
// tests can run fully in-memory via MockSquadBackend.
//
@MainActor
final class SquadService: SquadServiceProtocol {
    static let shared = SquadService()

    private let store: SquadStore
    private let backend: SquadBackendProtocol
    private let activityBackend: SquadActivityBackendProtocol
    private let localDirectory: LocalSquadDirectory
    private let auth: AuthServiceProtocol
    // Resolved lazily (NOT a default-arg .shared) to avoid a static-init cycle:
    // SquadService.shared → SquadLoopReconciler.shared → SquadActivityService.shared
    // → SquadService.shared. Tests inject a non-nil instance.
    private let injectedLoopReconciler: SquadLoopReconciler?
    private var loopReconciler: SquadLoopReconciler { injectedLoopReconciler ?? .shared }
    private let logger = LoggingService.shared

    init(
        store: SquadStore = .shared,
        backend: SquadBackendProtocol = SquadBackend.shared,
        activityBackend: SquadActivityBackendProtocol = SquadActivityBackend.shared,
        localDirectory: LocalSquadDirectory = .shared,
        auth: AuthServiceProtocol = AuthService.shared,
        loopReconciler: SquadLoopReconciler? = nil
    ) {
        self.store = store
        self.backend = backend
        self.activityBackend = activityBackend
        self.localDirectory = localDirectory
        self.auth = auth
        self.injectedLoopReconciler = loopReconciler
    }

    // MARK: - Loading

    func loadCurrentSquad(userId: String) async {
        guard let userUUID = SquadUserIdentity.uuid(from: userId) else {
            if SquadUserIdentity.usesLocalOnlySquad(for: userId) {
                clearState(userId: userId)
            }
            return
        }

        if SquadUserIdentity.usesLocalOnlySquad(for: userId) {
            loadLocalOnlySquad(userId: userId, userUUID: userUUID)
            return
        }

        do {
            try await loadRemoteSquad(userId: userId, userUUID: userUUID)
        } catch {
            logger.log("loadCurrentSquad failed: \(error)", level: .error)
        }
    }

    // MARK: - Create

    func createSquad(name: String, userId: String) async throws -> Squad {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 30 else {
            throw SquadError.invalidName
        }
        guard let userUUID = SquadUserIdentity.uuid(from: userId) else {
            throw SquadError.invalidName
        }
        let current = store.load(userId: userId)
        if current.currentSquad != nil {
            throw SquadError.alreadyInSquad
        }

        if SquadUserIdentity.usesLocalOnlySquad(for: userId) {
            return try createLocalOnlySquad(name: trimmed, userId: userId, userUUID: userUUID)
        }

        var squad: Squad?
        var lastError: Error?
        for _ in 0..<10 {
            let code = Self.makeInviteCode()
            do {
                let s = try await backend.insertSquad(
                    id: UUID(),
                    name: trimmed,
                    captainId: userUUID,
                    inviteCode: code,
                    maxSize: 8
                )
                squad = s
                break
            } catch {
                lastError = error
                continue
            }
        }
        guard let created = squad else {
            throw lastError ?? SquadError.backendUnavailable
        }

        await loadCurrentSquad(userId: userId)
        return created
    }

    // MARK: - Join

    func joinSquad(inviteCode: String, userId: String) async throws -> Squad {
        guard let userUUID = SquadUserIdentity.uuid(from: userId) else {
            throw SquadError.invalidInviteCode
        }
        let current = store.load(userId: userId)
        if SquadUserIdentity.usesLocalOnlySquad(for: userId) {
            return try joinLocalOnlySquad(
                inviteCode: inviteCode,
                userId: userId,
                userUUID: userUUID,
                cached: current
            )
        }
        if current.currentSquad != nil {
            throw SquadError.alreadyInSquad
        }
        let joined = try await backend.invokeJoinSquadEdgeFunction(inviteCode: inviteCode, userId: userUUID)
        await loadCurrentSquad(userId: userId)
        NotificationCenter.default.post(name: .squadStateChanged, object: nil)
        return joined
    }

    // MARK: - Leave

    func leaveSquad(userId: String) async throws {
        if SquadUserIdentity.usesLocalOnlySquad(for: userId) {
            guard let userUUID = SquadUserIdentity.uuid(from: userId) else {
                throw SquadError.notInSquad
            }
            _ = try localDirectory.leaveSquad(userUUID: userUUID)
            clearState(userId: userId)
            return
        }

        let current = store.load(userId: userId)
        guard let squad = current.currentSquad else {
            throw SquadError.notInSquad
        }
        guard let userUUID = SquadUserIdentity.uuid(from: userId) else {
            throw SquadError.notInSquad
        }

        try await leaveRemoteSquad(squad: squad, userUUID: userUUID)
        clearState(userId: userId)
    }

    // MARK: - Affinity

    func setAffinity(_ axis: AttributeKey?, userId: String) async throws {
        let current = store.load(userId: userId)
        guard let squad = current.currentSquad else {
            throw SquadError.notInSquad
        }
        guard let userUUID = SquadUserIdentity.uuid(from: userId), squad.captainId == userUUID else {
            throw SquadError.notCaptain
        }
        let setAt: Date? = axis == nil ? nil : Date()
        if SquadUserIdentity.usesLocalOnlySquad(for: userId) {
            localDirectory.updateAffinity(squadId: squad.id, axis: axis, setAt: setAt)
        } else {
            try await backend.updateAffinity(squadId: squad.id, axis: axis, setAt: setAt)
        }
        // Update local cache.
        var s = store.load(userId: userId)
        if var sq = s.currentSquad {
            sq = sq.replacingAffinity(axis: axis, setAt: setAt)
            s.currentSquad = sq
        }
        store.save(s, userId: userId)
        NotificationCenter.default.post(name: .squadStateChanged, object: nil)
    }

    // MARK: - state

    func state(userId: String) -> SquadState {
        store.load(userId: userId)
    }

    // MARK: - Aggregate Build

    /// Returns a per-axis 0–80 value representing the squad's collective Build.
    ///
    /// Simpler path: weight each axis by how many members have it as their
    /// BuildIdentity.primary. Real per-axis aggregation (requiring individual
    /// AttributeProfile snapshots per member) is deferred to a future enrichment.
    ///
    ///   baseline = 30 (minimum floor for every axis)
    ///   + share × 50  (where share = members_with_this_axis / roster_size)
    ///
    /// Result range: 30 (no members have this as primary) → 80 (all members do).
    func aggregateBuildHexValues(userId: String) -> [AttributeKey: Double] {
        let roster = state(userId: userId).roster
        guard !roster.isEmpty else { return [:] }
        var counts: [AttributeKey: Int] = [:]
        for member in roster {
            guard let identity = member.buildIdentity, let primary = identity.primary else { continue }
            counts[primary, default: 0] += 1
        }
        let total = roster.count
        var out: [AttributeKey: Double] = [:]
        for axis in AttributeKey.allCases {
            let share = Double(counts[axis] ?? 0) / Double(total)
            out[axis] = 30 + share * 50
        }
        return out
    }

    private static func makeInviteCode() -> String {
        String((0..<6).map { _ in
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()!
        })
    }

    private func loadLocalOnlySquad(userId: String, userUUID: UUID) {
        if let local = localDirectory.squadForUser(userUUID) {
            saveLocalState(squad: local.squad, roster: local.members, userId: userId)
            return
        }

        let cached = store.load(userId: userId)
        if let squad = cached.currentSquad {
            let roster = normalizedLocalRoster(cached.roster, squad: squad, userUUID: userUUID)
            localDirectory.adoptCachedSquad(squad, members: roster)
            saveLocalState(squad: squad, roster: roster, userId: userId)
            return
        }

        clearState(userId: userId)
    }

    private func loadRemoteSquad(userId: String, userUUID: UUID) async throws {
        guard let squadId = try await backend.fetchMySquadId(userId: userUUID) else {
            clearState(userId: userId)
            return
        }

        let squad = try await backend.fetchSquad(byId: squadId)
        let roster = try await backend.fetchMembers(squadId: squadId)
        var state = store.load(userId: userId)
        state.currentSquad = squad
        state.roster = roster
        if let activity = try? await activityBackend.fetchRecent(squadId: squadId, limit: 50) {
            state.recentActivity = activity
        }
        store.save(state, userId: userId)
        await loopReconciler.reconcile(userId: userId, userUUID: userUUID, squad: squad)
        NotificationCenter.default.post(name: .squadStateChanged, object: nil)
    }

    private func joinLocalOnlySquad(
        inviteCode: String,
        userId: String,
        userUUID: UUID,
        cached: SquadState
    ) throws -> Squad {
        let normalizedInviteCode = inviteCode.uppercased()

        if let local = localDirectory.squadForUser(userUUID) {
            saveLocalState(squad: local.squad, roster: local.members, userId: userId)
            guard local.squad.inviteCode.uppercased() == normalizedInviteCode else {
                throw SquadError.alreadyInSquad
            }
            return local.squad
        }

        if let squad = cached.currentSquad {
            let roster = normalizedLocalRoster(cached.roster, squad: squad, userUUID: userUUID)
            localDirectory.adoptCachedSquad(squad, members: roster)
            saveLocalState(squad: squad, roster: roster, userId: userId)
            guard squad.inviteCode.uppercased() == normalizedInviteCode else {
                throw SquadError.alreadyInSquad
            }
            return squad
        }

        let joined = try localDirectory.joinSquad(inviteCode: inviteCode, userUUID: userUUID)
        saveLocalState(squad: joined.squad, roster: joined.members, userId: userId)
        return joined.squad
    }

    private func leaveRemoteSquad(squad: Squad, userUUID: UUID) async throws {
        guard squad.captainId == userUUID else {
            try await backend.deleteMember(squadId: squad.id, userId: userUUID)
            return
        }

        let remainingMembers = try await backend.fetchMembers(squadId: squad.id)
            .filter { $0.userId != userUUID }
        guard let newCaptain = remainingMembers.first else {
            try await backend.deleteSquad(squadId: squad.id)
            return
        }

        try await backend.updateCaptain(squadId: squad.id, newCaptainId: newCaptain.userId)
        try await backend.deleteMember(squadId: squad.id, userId: userUUID)
    }

    private func createLocalOnlySquad(name: String, userId: String, userUUID: UUID) throws -> Squad {
        var lastError: Error?
        for _ in 0..<10 {
            do {
                let created = try localDirectory.createSquad(
                    name: name,
                    captainUUID: userUUID,
                    inviteCode: Self.makeInviteCode()
                )
                saveLocalState(squad: created.squad, roster: created.members, userId: userId)
                return created.squad
            } catch SquadError.alreadyInSquad {
                throw SquadError.alreadyInSquad
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError ?? SquadError.backendUnavailable
    }

    private func clearState(userId: String) {
        var state = store.load(userId: userId)
        state.currentSquad = nil
        state.roster = []
        store.save(state, userId: userId)
        NotificationCenter.default.post(name: .squadStateChanged, object: nil)
    }

    private func saveLocalState(squad: Squad, roster: [SquadMember], userId: String) {
        let existing = store.load(userId: userId)
        var state = existing
        state.currentSquad = squad
        state.roster = normalizedLocalRoster(
            roster,
            squad: squad,
            userUUID: SquadUserIdentity.uuid(from: userId)
        )
        state.activeRosterPresence = []
        state.recentActivity = existing.recentActivity.filter { $0.squadId == squad.id }
        store.save(state, userId: userId)
        NotificationCenter.default.post(name: .squadStateChanged, object: nil)
    }

    private func normalizedLocalRoster(_ roster: [SquadMember], squad: Squad, userUUID: UUID?) -> [SquadMember] {
        let seededRoster: [SquadMember]
        if roster.isEmpty, let userUUID {
            seededRoster = [
                SquadMember(
                    id: UUID(),
                    squadId: squad.id,
                    userId: userUUID,
                    joinedAt: Date(),
                    displayName: "You",
                    equippedTitle: nil,
                    buildIdentity: nil
                )
            ]
        } else {
            seededRoster = roster
        }

        return seededRoster.map { member in
            guard member.userId == userUUID else { return member }
            var copy = member
            copy.displayName = "You"
            return copy
        }
    }
}
