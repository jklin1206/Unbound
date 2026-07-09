import Foundation
import Supabase

@MainActor
protocol FriendChallengeServiceProtocol: Sendable {
    func createChallenge(challengedId: UUID, kind: FriendChallenge.Kind, squadId: UUID, exerciseName: String?) async throws -> FriendChallenge
    func activeChallenges(userId: UUID) async -> [FriendChallenge]
    func challengeStats(squadId: UUID) async -> [UUID: FriendChallengeStats]
    func challengeStats(squadId: UUID, season: SquadSeason) async -> [UUID: FriendChallengeStats]
    func accept(_ challengeId: UUID) async throws
    func decline(_ challengeId: UUID) async throws
    func recordProgress(log: WorkoutLog, userId: String, sourceLogId: String) async
    func evaluateExpired() async
    func consumePendingOutcome() -> FriendChallenge?
}

extension FriendChallengeServiceProtocol {
    func challengeStats(squadId: UUID, season: SquadSeason) async -> [UUID: FriendChallengeStats] {
        await challengeStats(squadId: squadId)
    }

    /// Convenience for the common case (no exercise scope); `heaviestLift`
    /// callers must pass `exerciseName`.
    func createChallenge(challengedId: UUID, kind: FriendChallenge.Kind, squadId: UUID) async throws -> FriendChallenge {
        try await createChallenge(challengedId: challengedId, kind: kind, squadId: squadId, exerciseName: nil)
    }
}

@MainActor
final class FriendChallengeService: FriendChallengeServiceProtocol {
    static let shared = FriendChallengeService()
    private let backend: SquadBackendProtocol
    private let remoteBackendEnabled: Bool
    private let logger = LoggingService.shared
    private var localChallenges: [FriendChallenge] = []
    private var localProgressReceipts: Set<String> = []
    // Settled outcomes waiting for the FriendChallengeOutcomeToast to show them.
    // evaluateExpired runs on every foreground — often while the user is off the
    // Squad tab, where the transient `.friendChallengeExpired` publisher has no
    // mounted listener — so each outcome is buffered here and drained when the
    // toast next mounts. In-memory FIFO; the win/loss reward is paid at settle
    // (grantDuelWinArcsIfWon) independently of whether the toast is ever seen.
    private var pendingOutcomes: [FriendChallenge] = []

    init(
        backend: SquadBackendProtocol = SquadBackend.shared,
        remoteBackendEnabled: Bool = true
    ) {
        self.backend = backend
        self.remoteBackendEnabled = remoteBackendEnabled
    }

    // MARK: - Private Codable row
    //
    // Properties are camelCase: UnboundSupabase.dbDecoder converts the
    // snake_case JSON keys before matching, so a snake_case property never
    // matches and every fetch throws keyNotFound.

    private struct ChallengeRow: Codable {
        let id: UUID
        let challengerId: UUID
        let challengedId: UUID
        let squadId: UUID
        let challengeKind: String
        let exerciseName: String?
        let startedAt: Date
        let expiresAt: Date
        let winnerUserId: UUID?
        let acceptedAt: Date?
        let challengerProgress: Int
        let challengedProgress: Int

        func toModel() -> FriendChallenge? {
            guard let kind = FriendChallenge.Kind(rawValue: challengeKind) else { return nil }
            return FriendChallenge(
                id: id,
                challengerId: challengerId,
                challengedId: challengedId,
                squadId: squadId,
                kind: kind,
                exerciseName: exerciseName,
                startedAt: startedAt,
                expiresAt: expiresAt,
                acceptedAt: acceptedAt,
                challengerProgress: challengerProgress,
                challengedProgress: challengedProgress,
                winnerUserId: winnerUserId
            )
        }
    }

    private struct ChallengeInsert: Encodable {
        let challenger_id: String
        let challenged_id: String
        let squad_id: String
        let challenge_kind: String
        let exercise_name: String?
        let started_at: String
        let expires_at: String
    }

    private struct AcceptPatch: Encodable {
        let accepted_at: String
    }

    private struct ProgressIncrementParams: Encodable, Sendable {
        let p_challenge_id: String
        let p_delta: Int
        let p_source_log_id: String
    }

    private struct SettleChallengeParams: Encodable, Sendable {
        let p_challenge_id: String
    }

    private var db: PostgrestClient { UnboundSupabase.client.schema("public") }
    private let iso = ISO8601DateFormatter()

    // MARK: - FriendChallengeServiceProtocol

    func createChallenge(
        challengedId: UUID,
        kind: FriendChallenge.Kind,
        squadId: UUID,
        exerciseName: String? = nil
    ) async throws -> FriendChallenge {
        guard kind.isSupportedForCreation else {
            logger.log(
                "FriendChallengeService.createChallenge skipped unsupported kind: \(kind.rawValue)",
                level: .warning
            )
            throw SquadError.unsupportedChallengeKind
        }
        // Exercise-scoped kinds (heaviestLift) require a non-blank lift name; the
        // stored string is matched verbatim against logged exerciseName server-side.
        let trimmedExercise = exerciseName?.trimmingCharacters(in: .whitespaces)
        if kind.requiresExercisePick && (trimmedExercise ?? "").isEmpty {
            logger.log(
                "FriendChallengeService.createChallenge missing exercise for kind: \(kind.rawValue)",
                level: .warning
            )
            throw SquadError.unsupportedChallengeKind
        }
        let resolvedExercise = kind.requiresExercisePick ? trimmedExercise : nil
        guard remoteBackendEnabled else {
            throw SquadError.backendUnavailable
        }
        if let local = createLocalChallengeIfNeeded(
            challengedId: challengedId,
            kind: kind,
            squadId: squadId,
            exerciseName: resolvedExercise
        ) {
            return local
        }
        // Require auth so we can use auth.uid() as challenger_id
        guard let challengerIdStr = await UnboundSupabase.currentUserId else {
            throw SquadError.backendUnavailable
        }
        let now = Date()
        // Default duration: 7 days
        let expires = now.addingTimeInterval(7 * 24 * 3600)
        let insert = ChallengeInsert(
            challenger_id: challengerIdStr,
            challenged_id: challengedId.uuidString,
            squad_id: squadId.uuidString,
            challenge_kind: kind.rawValue,
            exercise_name: resolvedExercise,
            started_at: iso.string(from: now),
            expires_at: iso.string(from: expires)
        )
        let rows: [ChallengeRow]
        do {
            rows = try await db
                .from("friend_challenges")
                .insert(insert)
                .select()
                .execute()
                .value
        } catch {
            logger.log(
                "FriendChallengeService.createChallenge backend error: \(error)",
                level: .warning
            )
            throw SquadError.backendUnavailable
        }
        guard let row = rows.first, let model = row.toModel() else {
            throw SquadError.backendUnavailable
        }
        return model
    }

    func activeChallenges(userId: UUID) async -> [FriendChallenge] {
        let local = localChallenges.filter {
            $0.isActive && ($0.challengerId == userId || $0.challengedId == userId)
        }
        if currentUserUsesLocalChallenges {
            return local.sorted { $0.startedAt > $1.startedAt }
        }
        guard remoteBackendEnabled else { return [] }
        do {
            // Supabase-swift doesn't support OR filters directly in a single .or() call
            // for this SDK version; we fetch challenges where the user is challenger or
            // challenged using a raw filter. Fall back to two queries if the SDK lacks .or.
            let nowStr = iso.string(from: Date())
            // Challenges where user is challenger
            let asChallenger: [ChallengeRow] = try await db
                .from("friend_challenges")
                .select()
                .eq("challenger_id", value: userId.uuidString)
                .gt("expires_at", value: nowStr)
                .is("winner_user_id", value: nil)
                .execute()
                .value

            // Challenges where user is challenged
            let asChallenged: [ChallengeRow] = try await db
                .from("friend_challenges")
                .select()
                .eq("challenged_id", value: userId.uuidString)
                .gt("expires_at", value: nowStr)
                .is("winner_user_id", value: nil)
                .execute()
                .value

            // Deduplicate by id
            var seen = Set<UUID>()
            return (asChallenger + asChallenged)
                .compactMap { row -> FriendChallenge? in
                    guard !seen.contains(row.id) else { return nil }
                    seen.insert(row.id)
                    return row.toModel()
                }
        } catch {
            logger.log("FriendChallengeService.activeChallenges error: \(error)", level: .warning)
            return []
        }
    }

    func challengeStats(squadId: UUID) async -> [UUID: FriendChallengeStats] {
        await challengeStats(squadId: squadId, season: .current())
    }

    func challengeStats(squadId: UUID, season: SquadSeason) async -> [UUID: FriendChallengeStats] {
        let local = stats(from: localChallenges.filter { $0.squadId == squadId }, season: season.interval)
        if currentUserUsesLocalChallenges {
            return local
        }
        guard remoteBackendEnabled else { return local }
        do {
            let rows: [ChallengeRow] = try await db
                .from("friend_challenges")
                .select()
                .eq("squad_id", value: squadId.uuidString)
                .execute()
                .value
            return stats(from: rows.compactMap { $0.toModel() }, season: season.interval)
        } catch {
            logger.log("FriendChallengeService.challengeStats error: \(error)", level: .warning)
            return local
        }
    }

    func accept(_ challengeId: UUID) async throws {
        if let index = localChallenges.firstIndex(where: { $0.id == challengeId }) {
            localChallenges[index].acceptedAt = Date()
            NotificationCenter.default.post(name: .friendChallengeAccepted, object: challengeId)
            return
        }
        guard remoteBackendEnabled else {
            throw SquadError.backendUnavailable
        }
        let patch = AcceptPatch(accepted_at: iso.string(from: Date()))
        try await db
            .from("friend_challenges")
            .update(patch)
            .eq("id", value: challengeId.uuidString)
            .execute()
        NotificationCenter.default.post(name: .friendChallengeAccepted, object: challengeId)
    }

    /// Decline a pending challenge (as the challenged user) or withdraw one
    /// (as the challenger). RLS only permits the DELETE while the challenge is
    /// unaccepted and unsettled, so an accepted duel can't be abandoned.
    func decline(_ challengeId: UUID) async throws {
        if let index = localChallenges.firstIndex(where: { $0.id == challengeId }) {
            localChallenges.remove(at: index)
            NotificationCenter.default.post(name: .friendChallengeDeclined, object: challengeId)
            return
        }
        guard remoteBackendEnabled else {
            throw SquadError.backendUnavailable
        }
        try await db
            .from("friend_challenges")
            .delete()
            .eq("id", value: challengeId.uuidString)
            .execute()
        NotificationCenter.default.post(name: .friendChallengeDeclined, object: challengeId)
    }

    func recordProgress(log: WorkoutLog, userId: String, sourceLogId: String) async {
        guard let uid = UUID(uuidString: userId) ?? SquadUserIdentity.uuid(from: userId) else { return }
        let active = await activeChallenges(userId: uid)
        guard !active.isEmpty else { return }

        for challenge in active {
            let isChallenger = challenge.challengerId == uid
            let delta = FriendChallengeProgressPolicy.progressDelta(for: challenge.kind, log: log)
            guard delta > 0 else { continue }
            await incrementProgress(
                challengeId: challenge.id,
                isChallenger: isChallenger,
                delta: delta,
                sourceLogId: sourceLogId
            )
        }
    }

    func evaluateExpired() async {
        evaluateExpiredLocalChallenges()
        if currentUserUsesLocalChallenges { return }
        guard remoteBackendEnabled else { return }
        let nowStr = iso.string(from: Date())
        do {
            // Fetch all expired challenges with no winner
            let rows: [ChallengeRow] = try await db
                .from("friend_challenges")
                .select()
                .lt("expires_at", value: nowStr)
                .is("winner_user_id", value: nil)
                .execute()
                .value

            for row in rows {
                guard let challenge = row.toModel() else { continue }
                let updated: [ChallengeRow] = try await UnboundSupabase.client
                    .rpc(
                        "settle_friend_challenge",
                        params: SettleChallengeParams(p_challenge_id: challenge.id.uuidString)
                    )
                    .execute()
                    .value
                guard let settled = updated.first?.toModel() else { continue }
                finalizeSettledChallenge(settled)
            }
        } catch {
            logger.log("FriendChallengeService.evaluateExpired error: \(error)", level: .warning)
        }

        await reconcileSettledWins()
    }

    /// A duel can be settled by EITHER participant's device. When the loser
    /// foregrounds first, its settle pass names the winner remotely but the
    /// winner's device never runs `finalizeSettledChallenge` (the row no longer
    /// matches the winnerless settle query) — so every settle pass also fetches
    /// challenges this user has WON and pays/buffers any the ledger says were
    /// never granted. `grant(_:sourceId:)` dedups on the challenge's stable
    /// sourceId, so the reward and its outcome moment land exactly once no
    /// matter which device settled or how many foregrounds re-run this.
    private func reconcileSettledWins() async {
        guard let userId = AuthService.shared.currentUserId,
              let me = SquadUserIdentity.uuid(from: userId) else { return }
        do {
            let rows: [ChallengeRow] = try await db
                .from("friend_challenges")
                .select()
                .eq("winner_user_id", value: me.uuidString)
                .order("expires_at", ascending: false)
                .limit(100)
                .execute()
                .value
            for row in rows {
                guard let settled = row.toModel() else { continue }
                if grantDuelWinArcsIfWon(settled) {
                    pendingOutcomes.append(settled)
                    NotificationCenter.default.post(name: .friendChallengeExpired, object: settled)
                }
            }
        } catch {
            logger.log("FriendChallengeService.reconcileSettledWins error: \(error)", level: .warning)
        }
    }

    /// Pop the oldest buffered outcome for the toast to display, or nil when the
    /// buffer is empty. FIFO so multiple settled duels are shown in order.
    func consumePendingOutcome() -> FriendChallenge? {
        pendingOutcomes.isEmpty ? nil : pendingOutcomes.removeFirst()
    }

    // MARK: - Private helpers

    /// Shared settle epilogue used by both the remote and local paths: pay the
    /// winner (idempotent), buffer the outcome for the toast, then broadcast
    /// `.friendChallengeExpired` so open squad surfaces refresh.
    private func finalizeSettledChallenge(_ settled: FriendChallenge) {
        grantDuelWinArcsIfWon(settled)
        pendingOutcomes.append(settled)
        NotificationCenter.default.post(name: .friendChallengeExpired, object: settled)
    }

    /// Pay the 120-Arc duel-win reward when the signed-in user is the winner of a
    /// settled challenge. Idempotent: CurrencyWalletStore ledger-dedups by the
    /// challenge's stable sourceId, so the reward pays exactly once no matter how
    /// many foregrounds re-run the settle pass. Mirrors claimMissionReward's grant.
    /// Returns true only when this call actually paid (a fresh, undeduped win).
    @discardableResult
    private func grantDuelWinArcsIfWon(_ settled: FriendChallenge) -> Bool {
        guard let userId = AuthService.shared.currentUserId,
              let me = SquadUserIdentity.uuid(from: userId),
              settled.winnerUserId == me
        else { return false }
        CurrencyWalletStore.shared.bind(userId: userId)
        return CurrencyWalletStore.shared.grant(
            SquadRewardPolicy.duelWinArcs,
            sourceId: SquadRewardPolicy.duelSourceId(settled.id)
        )
    }

    private func incrementProgress(
        challengeId: UUID,
        isChallenger: Bool,
        delta: Int,
        sourceLogId: String
    ) async {
        if let index = localChallenges.firstIndex(where: { $0.id == challengeId }) {
            let receiptKey = "\(challengeId.uuidString):\(sourceLogId)"
            guard !localProgressReceipts.contains(receiptKey) else { return }
            localProgressReceipts.insert(receiptKey)
            if isChallenger {
                localChallenges[index].challengerProgress += delta
            } else {
                localChallenges[index].challengedProgress += delta
            }
            return
        }
        guard remoteBackendEnabled else { return }
        do {
            try await UnboundSupabase.client
                .rpc(
                    "increment_friend_challenge_progress",
                    params: ProgressIncrementParams(
                        p_challenge_id: challengeId.uuidString,
                        p_delta: delta,
                        p_source_log_id: sourceLogId
                    )
                )
                .execute()
        } catch {
            logger.log(
                "FriendChallengeService.incrementProgress error: \(error)",
                level: .warning
            )
        }
    }

    private var currentUserUsesLocalChallenges: Bool {
        guard let userId = AuthService.shared.currentUserId else { return false }
        return SquadUserIdentity.usesLocalOnlySquad(for: userId)
    }

    private func createLocalChallengeIfNeeded(
        challengedId: UUID,
        kind: FriendChallenge.Kind,
        squadId: UUID,
        exerciseName: String?
    ) -> FriendChallenge? {
        guard currentUserUsesLocalChallenges,
              let userId = AuthService.shared.currentUserId,
              let challengerId = SquadUserIdentity.uuid(from: userId)
        else { return nil }

        let now = Date()
        let challenge = FriendChallenge(
            id: UUID(),
            challengerId: challengerId,
            challengedId: challengedId,
            squadId: squadId,
            kind: kind,
            exerciseName: exerciseName,
            startedAt: now,
            expiresAt: now.addingTimeInterval(7 * 24 * 3600),
            acceptedAt: nil,
            challengerProgress: 0,
            challengedProgress: 0,
            winnerUserId: nil
        )
        localChallenges.insert(challenge, at: 0)
        return challenge
    }

    #if DEBUG
    /// Test-only: seed a local challenge so expiry/winner logic can be exercised
    /// without a backend. Not compiled into release builds.
    func _seedLocalChallengeForTesting(_ challenge: FriendChallenge) {
        localChallenges.insert(challenge, at: 0)
    }
    #endif

    private func evaluateExpiredLocalChallenges() {
        for index in localChallenges.indices where localChallenges[index].isExpired && localChallenges[index].winnerUserId == nil {
            let challenge = localChallenges[index]
            localChallenges[index].winnerUserId = challenge.challengedProgress > challenge.challengerProgress
                ? challenge.challengedId
                : challenge.challengerId
            finalizeSettledChallenge(localChallenges[index])
        }
    }

    private func stats(from challenges: [FriendChallenge], season: DateInterval) -> [UUID: FriendChallengeStats] {
        var result: [UUID: FriendChallengeStats] = [:]
        func update(_ userId: UUID, _ body: (inout FriendChallengeStats) -> Void) {
            var stats = result[userId] ?? .empty
            body(&stats)
            result[userId] = stats
        }

        for challenge in challenges {
            if let winner = challenge.winnerUserId {
                update(winner) {
                    $0.wins += 1
                    if season.contains(challenge.expiresAt) || season.contains(challenge.startedAt) {
                        $0.seasonWins += 1
                    }
                }
            }
            if challenge.isActive {
                update(challenge.challengerId) { $0.activeCount += 1 }
                update(challenge.challengedId) { $0.activeCount += 1 }
            }
            if challenge.isPending {
                update(challenge.challengedId) { $0.pendingCount += 1 }
            }
        }
        return result
    }
}
