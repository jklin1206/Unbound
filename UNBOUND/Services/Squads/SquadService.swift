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
// ServiceContainer wiring is deferred to Phase 16.

@MainActor
final class SquadService: SquadServiceProtocol {
    static let shared = SquadService()

    private let store: SquadStore
    private let backend: SquadBackendProtocol
    private let localDirectory: LocalSquadDirectory
    private let auth: AuthServiceProtocol
    private let logger = LoggingService.shared

    init(
        store: SquadStore = .shared,
        backend: SquadBackendProtocol = SquadBackend.shared,
        localDirectory: LocalSquadDirectory = .shared,
        auth: AuthServiceProtocol = AuthService.shared
    ) {
        self.store = store
        self.backend = backend
        self.localDirectory = localDirectory
        self.auth = auth
    }

    // MARK: - T5.5 loadCurrentSquad

    func loadCurrentSquad(userId: String) async {
        if SquadUserIdentity.usesLocalOnlySquad(for: userId) {
            guard let userUUID = SquadUserIdentity.uuid(from: userId) else {
                store.save(.empty, userId: userId)
                NotificationCenter.default.post(name: .squadStateChanged, object: nil)
                return
            }
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

            store.save(.empty, userId: userId)
            NotificationCenter.default.post(name: .squadStateChanged, object: nil)
            return
        }
        guard let userUUID = SquadUserIdentity.uuid(from: userId) else { return }
        do {
            guard let squadId = try await backend.fetchMySquadId(userId: userUUID) else {
                // User is not in any squad — persist empty state.
                var s = store.load(userId: userId)
                s.currentSquad = nil
                s.roster = []
                store.save(s, userId: userId)
                NotificationCenter.default.post(name: .squadStateChanged, object: nil)
                return
            }
            let squad = try await backend.fetchSquad(byId: squadId)
            let roster = try await backend.fetchMembers(squadId: squadId)
            var s = store.load(userId: userId)
            s.currentSquad = squad
            s.roster = roster
            // TODO(squads-impl, Phase 6): hydrate state.recentActivity via SquadActivityService.fetchRecent(squadId:).
            // TODO(squads-impl, Phase 8): hydrate state.activeRosterPresence via SquadPresenceService.snapshot(squadId:).
            store.save(s, userId: userId)
            NotificationCenter.default.post(name: .squadStateChanged, object: nil)
        } catch {
            logger.log("loadCurrentSquad failed: \(error)", level: .error)
        }
    }

    // MARK: - T5.2 createSquad

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

        // Generate a unique 6-char A-Z0-9 invite code with up to 10 retries
        // on backend collision (UNIQUE constraint on invite_code column).
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
                // Retry only on invite-code collision; surface other errors immediately.
                // A production Postgres unique-violation comes back as a specific code
                // (23505). For now we retry on any error and bail after 10 attempts.
                continue
            }
        }
        guard let created = squad else {
            throw lastError ?? SquadError.backendUnavailable
        }

        await loadCurrentSquad(userId: userId)
        return created
    }

    // MARK: - T5.3 joinSquad

    func joinSquad(inviteCode: String, userId: String) async throws -> Squad {
        guard let userUUID = SquadUserIdentity.uuid(from: userId) else {
            throw SquadError.invalidInviteCode
        }
        let current = store.load(userId: userId)
        if SquadUserIdentity.usesLocalOnlySquad(for: userId) {
            if let local = localDirectory.squadForUser(userUUID) {
                saveLocalState(squad: local.squad, roster: local.members, userId: userId)
                if local.squad.inviteCode.uppercased() == inviteCode.uppercased() {
                    return local.squad
                }
                throw SquadError.alreadyInSquad
            }
            if let squad = current.currentSquad {
                let roster = normalizedLocalRoster(current.roster, squad: squad, userUUID: userUUID)
                localDirectory.adoptCachedSquad(squad, members: roster)
                saveLocalState(squad: squad, roster: roster, userId: userId)
                if squad.inviteCode.uppercased() == inviteCode.uppercased() {
                    return squad
                }
                throw SquadError.alreadyInSquad
            }
            let joined = try localDirectory.joinSquad(inviteCode: inviteCode, userUUID: userUUID)
            saveLocalState(squad: joined.squad, roster: joined.members, userId: userId)
            return joined.squad
        }
        if current.currentSquad != nil {
            throw SquadError.alreadyInSquad
        }
        // Delegates validation + insert + activity to the join_squad Edge Function.
        // SquadError cases (invalidInviteCode, squadFull, alreadyInSquad) bubble up directly.
        let joined = try await backend.invokeJoinSquadEdgeFunction(inviteCode: inviteCode, userId: userUUID)
        await loadCurrentSquad(userId: userId)
        NotificationCenter.default.post(name: .squadStateChanged, object: nil)
        // TODO: SquadActivityService.record(.memberJoined, ...) — Phase 6
        return joined
    }

    // MARK: - T5.4 leaveSquad

    func leaveSquad(userId: String) async throws {
        // COMMENT: This is a multi-step client-side operation (check → maybe updateCaptain
        // → deleteMember / deleteSquad). There is a race if the captain leaves at the same
        // time as another member. For v1 we accept this risk — a simultaneous leave is
        // rare and non-catastrophic (at worst the DB ends up without a valid captain_id
        // reference, which the DB FK will reject). The correct fix is a server-side
        // `leave_squad` Edge Function that wraps the whole sequence in a Postgres
        // transaction. Deferred to a future sub-project.

        if SquadUserIdentity.usesLocalOnlySquad(for: userId) {
            guard let userUUID = SquadUserIdentity.uuid(from: userId) else {
                throw SquadError.notInSquad
            }
            _ = try localDirectory.leaveSquad(userUUID: userUUID)
            store.save(.empty, userId: userId)
            NotificationCenter.default.post(name: .squadStateChanged, object: nil)
            return
        }

        let current = store.load(userId: userId)
        guard let squad = current.currentSquad else {
            throw SquadError.notInSquad
        }
        guard let userUUID = SquadUserIdentity.uuid(from: userId) else {
            throw SquadError.notInSquad
        }

        let isCaptain = squad.captainId == userUUID

        if isCaptain {
            let allMembers = try await backend.fetchMembers(squadId: squad.id)
            let others = allMembers.filter { $0.userId != userUUID }
            if others.isEmpty {
                // Last member — delete the squad; cascade removes everything.
                try await backend.deleteSquad(squadId: squad.id)
            } else {
                // Transfer captaincy to the longest-tenured remaining member
                // (fetchMembers returns rows ordered by joined_at ASC, so index 0
                //  is the longest-tenured).
                let newCaptain = others[0]
                try await backend.updateCaptain(squadId: squad.id, newCaptainId: newCaptain.userId)
                try await backend.deleteMember(squadId: squad.id, userId: userUUID)
            }
        } else {
            try await backend.deleteMember(squadId: squad.id, userId: userUUID)
        }

        var s = store.load(userId: userId)
        s.currentSquad = nil
        s.roster = []
        store.save(s, userId: userId)
        NotificationCenter.default.post(name: .squadStateChanged, object: nil)
    }

    // MARK: - T5.5 setAffinity

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
            sq = Squad(
                id: sq.id,
                name: sq.name,
                captainId: sq.captainId,
                affinityAxis: axis,
                affinitySetAt: setAt,
                inviteCode: sq.inviteCode,
                maxSize: sq.maxSize,
                squadStreakWeeks: sq.squadStreakWeeks,
                createdAt: sq.createdAt
            )
            s.currentSquad = sq
        }
        store.save(s, userId: userId)
        NotificationCenter.default.post(name: .squadStateChanged, object: nil)
        // TODO: SquadActivityService.record(.affinityChanged, ...) — Phase 6
    }

    // MARK: - state

    func state(userId: String) -> SquadState {
        store.load(userId: userId)
    }

    // MARK: - T5.5 aggregateBuildHexValues

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
