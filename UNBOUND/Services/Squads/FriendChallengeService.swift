import Foundation
import Supabase

@MainActor
protocol FriendChallengeServiceProtocol: Sendable {
    func createChallenge(challengedId: UUID, kind: FriendChallenge.Kind, squadId: UUID) async throws -> FriendChallenge
    func activeChallenges(userId: UUID) async -> [FriendChallenge]
    func accept(_ challengeId: UUID) async throws
    func recordProgress(log: WorkoutLog, userId: String) async
    func evaluateExpired() async
}

@MainActor
final class FriendChallengeService: FriendChallengeServiceProtocol {
    static let shared = FriendChallengeService()
    private let backend: SquadBackendProtocol
    private let logger = LoggingService.shared

    init(backend: SquadBackendProtocol = SquadBackend.shared) {
        self.backend = backend
    }

    // MARK: - Private Codable row

    private struct ChallengeRow: Codable {
        let id: UUID
        let challenger_id: UUID
        let challenged_id: UUID
        let squad_id: UUID
        let challenge_kind: String
        let started_at: Date
        let expires_at: Date
        let winner_user_id: UUID?
        let accepted_at: Date?
        let challenger_progress: Int
        let challenged_progress: Int

        func toModel() -> FriendChallenge? {
            guard let kind = FriendChallenge.Kind(rawValue: challenge_kind) else { return nil }
            return FriendChallenge(
                id: id,
                challengerId: challenger_id,
                challengedId: challenged_id,
                squadId: squad_id,
                kind: kind,
                startedAt: started_at,
                expiresAt: expires_at,
                acceptedAt: accepted_at,
                challengerProgress: challenger_progress,
                challengedProgress: challenged_progress,
                winnerUserId: winner_user_id
            )
        }
    }

    private struct ChallengeInsert: Encodable {
        let challenger_id: String
        let challenged_id: String
        let squad_id: String
        let challenge_kind: String
        let started_at: String
        let expires_at: String
    }

    private struct AcceptPatch: Encodable {
        let accepted_at: String
    }

    // Separate patch structs so we never accidentally zero out the other side's progress.
    private struct ChallengerProgressPatch: Encodable {
        let challenger_progress: Int
    }
    private struct ChallengedProgressPatch: Encodable {
        let challenged_progress: Int
    }

    private struct WinnerPatch: Encodable {
        let winner_user_id: String
    }

    private var db: PostgrestClient { UnboundSupabase.client.schema("public") }
    private let iso = ISO8601DateFormatter()

    // MARK: - FriendChallengeServiceProtocol

    func createChallenge(
        challengedId: UUID,
        kind: FriendChallenge.Kind,
        squadId: UUID
    ) async throws -> FriendChallenge {
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

    func accept(_ challengeId: UUID) async throws {
        let patch = AcceptPatch(accepted_at: iso.string(from: Date()))
        try await db
            .from("friend_challenges")
            .update(patch)
            .eq("id", value: challengeId.uuidString)
            .execute()
        NotificationCenter.default.post(name: .friendChallengeAccepted, object: challengeId)
    }

    func recordProgress(log: WorkoutLog, userId: String) async {
        guard let uid = UUID(uuidString: userId) else { return }
        let active = await activeChallenges(userId: uid)
        guard !active.isEmpty else { return }

        for challenge in active {
            let isChallenger = challenge.challengerId.uuidString == userId
            switch challenge.kind {

            case .mostSessions:
                // +1 for this workout log
                await incrementProgress(
                    challengeId: challenge.id,
                    isChallenger: isChallenger,
                    current: isChallenger ? challenge.challengerProgress : challenge.challengedProgress,
                    delta: 1
                )

            case .noMissedDays:
                // Recompute streak from log dates. For now use the running progress
                // as a consecutive-day streak counter and +1 for today's log only
                // if it's a new calendar day vs the last log.
                // Full streak recomputation would require fetching all logs — deferred.
                await incrementProgress(
                    challengeId: challenge.id,
                    isChallenger: isChallenger,
                    current: isChallenger ? challenge.challengerProgress : challenge.challengedProgress,
                    delta: 1
                )

            case .firstToFinishTrial:
                // A capstone is detected by completedAt being non-nil and the log
                // having a capstone activity kind. Placeholder: if the log has no
                // exerciseEntries it's treated as a capstone completion (this is a
                // signal from the call-site in SquadActivityService).
                // Real detection would check TrialsState. Deferred.
                break

            case .mostAlignedSessions:
                // +1 if the log's RPE > 0 (proxy for an aligned effort — the real check
                // would be log.trialAxisTag == challenge's trial axis).
                // Deferred: requires WorkoutLog to carry axis metadata.
                if (log.overallRPE ?? 0) > 0 {
                    await incrementProgress(
                        challengeId: challenge.id,
                        isChallenger: isChallenger,
                        current: isChallenger ? challenge.challengerProgress : challenge.challengedProgress,
                        delta: 1
                    )
                }

            case .earlyRiser:
                // +1 if startedAt is before 8am in the local timezone
                let cal = Calendar.current
                let hour = cal.component(.hour, from: log.startedAt)
                if hour < 8 {
                    await incrementProgress(
                        challengeId: challenge.id,
                        isChallenger: isChallenger,
                        current: isChallenger ? challenge.challengerProgress : challenge.challengedProgress,
                        delta: 1
                    )
                }

            case .proteinGoal:
                // Nutrition tracking is out of scope. Log a warning and skip.
                logger.log(
                    "FriendChallengeService: proteinGoal progress deferred (nutrition tracking not in scope)",
                    level: .warning
                )
            }
        }
    }

    func evaluateExpired() async {
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
                let winnerId: UUID
                if challenge.challengerProgress > challenge.challengedProgress {
                    winnerId = challenge.challengerId
                } else if challenge.challengedProgress > challenge.challengerProgress {
                    winnerId = challenge.challengedId
                } else {
                    // Tie → challenger wins
                    winnerId = challenge.challengerId
                }
                let patch = WinnerPatch(winner_user_id: winnerId.uuidString)
                try await db
                    .from("friend_challenges")
                    .update(patch)
                    .eq("id", value: challenge.id.uuidString)
                    .execute()
                NotificationCenter.default.post(name: .friendChallengeExpired, object: challenge)
            }
        } catch {
            logger.log("FriendChallengeService.evaluateExpired error: \(error)", level: .warning)
        }
    }

    // MARK: - Private helpers

    private func incrementProgress(
        challengeId: UUID,
        isChallenger: Bool,
        current: Int,
        delta: Int
    ) async {
        let newValue = current + delta
        do {
            if isChallenger {
                let patch = ChallengerProgressPatch(challenger_progress: newValue)
                try await db
                    .from("friend_challenges")
                    .update(patch)
                    .eq("id", value: challengeId.uuidString)
                    .execute()
            } else {
                let patch = ChallengedProgressPatch(challenged_progress: newValue)
                try await db
                    .from("friend_challenges")
                    .update(patch)
                    .eq("id", value: challengeId.uuidString)
                    .execute()
            }
        } catch {
            logger.log(
                "FriendChallengeService.incrementProgress error: \(error)",
                level: .warning
            )
        }
    }
}
