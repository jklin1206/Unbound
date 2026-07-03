import XCTest
@testable import UNBOUND

// BLOCKER 2 proof: a real finished workout (the canonical
// TrainingCompletionService path) advances squad-mission + friend-challenge
// progress exactly once per session, and a re-flush of the same session does
// not double-count.

@MainActor
private final class SpyMissionService: SquadMissionServiceProtocol {
    var recordCalls: [(logId: String, userId: String, sourceLogId: String)] = []
    func generateThisWeek(squadId: UUID) async throws -> SquadMission { throw SquadError.backendUnavailable }
    func currentMission(squadId: UUID) async -> SquadMission? { nil }
    func latestMission(squadId: UUID) async -> SquadMission? { nil }
    func recordProgress(log: WorkoutLog, userId: String, sourceLogId: String) async {
        recordCalls.append((log.id, userId, sourceLogId))
    }
    func evaluateCompletion(squadId: UUID) async {}
    func pickMission(squadId: UUID, kind: SquadMission.Kind) async throws -> SquadMission? { nil }
    func fetchMissionContributions(missionId: UUID) async throws -> [MissionContribution] { [] }
}

@MainActor
private final class SpyChallengeService: FriendChallengeServiceProtocol {
    var recordCalls: [(logId: String, userId: String, sourceLogId: String)] = []
    func createChallenge(challengedId: UUID, kind: FriendChallenge.Kind, squadId: UUID, exerciseName: String?) async throws -> FriendChallenge {
        throw SquadError.backendUnavailable
    }
    func activeChallenges(userId: UUID) async -> [FriendChallenge] { [] }
    func challengeStats(squadId: UUID) async -> [UUID: FriendChallengeStats] { [:] }
    func accept(_ challengeId: UUID) async throws {}
    func decline(_ challengeId: UUID) async throws {}
    func recordProgress(log: WorkoutLog, userId: String, sourceLogId: String) async {
        recordCalls.append((log.id, userId, sourceLogId))
    }
    func evaluateExpired() async {}
    func consumePendingOutcome() -> FriendChallenge? { nil }
}

@MainActor
private final class SpyActivityService: SquadActivityServiceProtocol {
    var recorded: [(kind: SquadActivityEntry.Kind, payload: SquadActivityPayload, userId: String)] = []
    func record(kind: SquadActivityEntry.Kind, payload: SquadActivityPayload, userId: String) async {
        recorded.append((kind, payload, userId))
    }
    func fetchRecent(userId: String) async throws -> [SquadActivityEntry] { [] }
    func handleLinkedSessionDetected(userId: String, participantDisplayNames: [String], baseSessionXP: Int) async {}
}

@MainActor
final class TrainingCompletionSquadProgressTests: XCTestCase {

    private func makeLog(id: String, userId: String) -> WorkoutLog {
        WorkoutLog(
            id: id,
            userId: userId,
            programId: "program",
            dayNumber: 1,
            plannedWorkoutName: "Session",
            startedAt: Date().addingTimeInterval(-1800),
            completedAt: Date(),
            exerciseEntries: [],
            overallNotes: nil,
            overallRPE: 7,
            durationMinutes: 30
        )
    }

    func testRecordsSquadProgressOncePerSession() async {
        let mission = SpyMissionService()
        let challenge = SpyChallengeService()
        let activity = SpyActivityService()
        let service = TrainingCompletionService(
            squadMission: mission,
            friendChallenge: challenge,
            squadActivity: activity
        )
        let log = makeLog(id: "perf-1", userId: "user-1")

        await service.recordSquadProgress(workoutLog: log, performanceLogId: "perf-1")

        XCTAssertEqual(mission.recordCalls.count, 1)
        XCTAssertEqual(mission.recordCalls.first?.logId, "perf-1")
        XCTAssertEqual(mission.recordCalls.first?.userId, "user-1")
        XCTAssertEqual(mission.recordCalls.first?.sourceLogId, "perf-1")
        XCTAssertEqual(challenge.recordCalls.count, 1)
        XCTAssertEqual(challenge.recordCalls.first?.logId, "perf-1")
        XCTAssertEqual(challenge.recordCalls.first?.sourceLogId, "perf-1")

        // The finished workout is shared to the squad feed exactly once.
        XCTAssertEqual(activity.recorded.count, 1)
        XCTAssertEqual(activity.recorded.first?.kind, .workoutCompleted)
        XCTAssertEqual(activity.recorded.first?.userId, "user-1")
        if case let .workoutCompleted(title, exerciseCount, durationMinutes) = activity.recorded.first?.payload {
            XCTAssertEqual(title, "Session")
            XCTAssertEqual(exerciseCount, 0)
            XCTAssertEqual(durationMinutes, 30)
        } else {
            XCTFail("Expected a workoutCompleted payload")
        }
    }

    func testReflushOfSameSessionDoesNotDoubleCount() async {
        let mission = SpyMissionService()
        let challenge = SpyChallengeService()
        let activity = SpyActivityService()
        let service = TrainingCompletionService(
            squadMission: mission,
            friendChallenge: challenge,
            squadActivity: activity
        )
        let log = makeLog(id: "perf-2", userId: "user-1")

        // Same performanceLog id flushed twice (e.g. retry / re-flush path).
        await service.recordSquadProgress(workoutLog: log, performanceLogId: "perf-2")
        await service.recordSquadProgress(workoutLog: log, performanceLogId: "perf-2")

        XCTAssertEqual(mission.recordCalls.count, 1, "Mission progress must not double-count a re-flush")
        XCTAssertEqual(challenge.recordCalls.count, 1, "Challenge progress must not double-count a re-flush")
        XCTAssertEqual(activity.recorded.count, 1, "Workout share must not double-post on a re-flush")
    }
}
