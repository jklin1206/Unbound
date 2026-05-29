import XCTest
@testable import UNBOUND

// BLOCKER 2 proof: a real finished workout (the canonical
// TrainingCompletionService path) advances squad-mission + friend-challenge
// progress exactly once per session, and a re-flush of the same session does
// not double-count.

@MainActor
private final class SpyMissionService: SquadMissionServiceProtocol {
    var recordCalls: [(logId: String, userId: String)] = []
    func generateThisWeek(squadId: UUID) async throws -> SquadMission { throw SquadError.backendUnavailable }
    func currentMission(squadId: UUID) async -> SquadMission? { nil }
    func recordProgress(log: WorkoutLog, userId: String) async {
        recordCalls.append((log.id, userId))
    }
    func evaluateCompletion(squadId: UUID) async {}
}

@MainActor
private final class SpyChallengeService: FriendChallengeServiceProtocol {
    var recordCalls: [(logId: String, userId: String)] = []
    func createChallenge(challengedId: UUID, kind: FriendChallenge.Kind, squadId: UUID) async throws -> FriendChallenge {
        throw SquadError.backendUnavailable
    }
    func activeChallenges(userId: UUID) async -> [FriendChallenge] { [] }
    func accept(_ challengeId: UUID) async throws {}
    func recordProgress(log: WorkoutLog, userId: String) async {
        recordCalls.append((log.id, userId))
    }
    func evaluateExpired() async {}
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
        let service = TrainingCompletionService(squadMission: mission, friendChallenge: challenge)
        let log = makeLog(id: "perf-1", userId: "user-1")

        await service.recordSquadProgress(workoutLog: log, performanceLogId: "perf-1")

        XCTAssertEqual(mission.recordCalls.count, 1)
        XCTAssertEqual(mission.recordCalls.first?.logId, "perf-1")
        XCTAssertEqual(mission.recordCalls.first?.userId, "user-1")
        XCTAssertEqual(challenge.recordCalls.count, 1)
        XCTAssertEqual(challenge.recordCalls.first?.logId, "perf-1")
    }

    func testReflushOfSameSessionDoesNotDoubleCount() async {
        let mission = SpyMissionService()
        let challenge = SpyChallengeService()
        let service = TrainingCompletionService(squadMission: mission, friendChallenge: challenge)
        let log = makeLog(id: "perf-2", userId: "user-1")

        // Same performanceLog id flushed twice (e.g. retry / re-flush path).
        await service.recordSquadProgress(workoutLog: log, performanceLogId: "perf-2")
        await service.recordSquadProgress(workoutLog: log, performanceLogId: "perf-2")

        XCTAssertEqual(mission.recordCalls.count, 1, "Mission progress must not double-count a re-flush")
        XCTAssertEqual(challenge.recordCalls.count, 1, "Challenge progress must not double-count a re-flush")
    }
}
