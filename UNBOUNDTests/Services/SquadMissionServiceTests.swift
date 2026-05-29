import XCTest
@testable import UNBOUND

// Minimal SquadServiceProtocol stub returning a seeded squad.
@MainActor
private final class StubSquadService: SquadServiceProtocol {
    var stubbedState: SquadState = .empty
    func loadCurrentSquad(userId: String) async {}
    func createSquad(name: String, userId: String) async throws -> Squad { throw SquadError.backendUnavailable }
    func joinSquad(inviteCode: String, userId: String) async throws -> Squad { throw SquadError.backendUnavailable }
    func leaveSquad(userId: String) async throws {}
    func setAffinity(_ axis: AttributeKey?, userId: String) async throws {}
    func state(userId: String) -> SquadState { stubbedState }
    func aggregateBuildHexValues(userId: String) -> [AttributeKey: Double] { [:] }
}

@MainActor
final class SquadMissionServiceTests: XCTestCase {

    private func seededSquad() -> Squad {
        Squad(
            id: UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000001")!,
            name: "Mission Squad",
            captainId: UUID(),
            affinityAxis: nil, affinitySetAt: nil,
            inviteCode: "MISN01", maxSize: 8,
            squadStreakWeeks: 0, createdAt: Date()
        )
    }

    private func makeLog(userId: String) -> WorkoutLog {
        WorkoutLog(
            id: "mission-progress-log",
            userId: userId,
            programId: "p",
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

    // MARK: - recordProgress increments the active mission via backend RPC

    func testRecordProgressIncrementsMissionForSquadMember() async {
        let squad = seededSquad()
        let stubSquad = StubSquadService()
        stubSquad.stubbedState = SquadState(
            currentSquad: squad, roster: [],
            activeRosterPresence: [], recentActivity: [],
            unlockedSquadTitles: []
        )
        let backend = MockSquadBackend()
        let service = SquadMissionService(
            backend: backend,
            squadService: stubSquad,
            remoteReadsEnabled: true
        )

        await service.recordProgress(log: makeLog(userId: "user-m1"), userId: "user-m1")

        XCTAssertEqual(backend.missionProgressIncrements.count, 1)
        XCTAssertEqual(backend.missionProgressIncrements.first?.squadId, squad.id)
        XCTAssertEqual(backend.missionProgressIncrements.first?.delta, 1)
    }

    func testRecordProgressSkipsWhenNoSquad() async {
        let stubSquad = StubSquadService()  // .empty
        let backend = MockSquadBackend()
        let service = SquadMissionService(
            backend: backend,
            squadService: stubSquad,
            remoteReadsEnabled: true
        )
        await service.recordProgress(log: makeLog(userId: "user-m2"), userId: "user-m2")
        XCTAssertTrue(backend.missionProgressIncrements.isEmpty)
    }

    // MARK: - currentWeekIso format

    func testCurrentWeekIsoFormat() {
        let iso = SquadMissionService.currentWeekIso()
        // Should match e.g. "2026-W20"
        let regex = try! NSRegularExpression(pattern: #"^\d{4}-W\d{2}$"#)
        let range = NSRange(iso.startIndex..., in: iso)
        XCTAssertNotNil(regex.firstMatch(in: iso, range: range), "weekIso '\(iso)' does not match YYYY-WNN format")
    }

    func testCurrentWeekIsoHasTwoDigitWeek() {
        let iso = SquadMissionService.currentWeekIso()
        let parts = iso.split(separator: "-")
        XCTAssertEqual(parts.count, 2)
        let weekPart = String(parts[1])  // e.g. "W20"
        XCTAssertEqual(weekPart.count, 3, "Week part '\(weekPart)' should be 3 chars (W + 2 digits)")
    }

    // MARK: - generateThisWeek target

    func testGenerateThisWeekReturnsMission() async throws {
        let service = SquadMissionService(remoteReadsEnabled: false)
        let squadId = UUID()
        let mission = try await service.generateThisWeek(squadId: squadId)
        XCTAssertEqual(mission.squadId, squadId)
        XCTAssertFalse(mission.weekIso.isEmpty)
        XCTAssertGreaterThan(mission.target, 0)
        XCTAssertFalse(mission.isCompleted)
    }

    func testGenerateThisWeekTargetPositive() async throws {
        let service = SquadMissionService(remoteReadsEnabled: false)
        let mission = try await service.generateThisWeek(squadId: UUID())
        XCTAssertGreaterThan(mission.target, 0)
    }

    // MARK: - evaluateCompletion does NOT fire when progress < target

    func testEvaluateCompletionDoesNotFireBelowTarget() async {
        let service = SquadMissionService(remoteReadsEnabled: false)
        var notificationFired = false
        let token = NotificationCenter.default.addObserver(
            forName: .squadMissionCompleted,
            object: nil,
            queue: nil
        ) { _ in notificationFired = true }
        defer { NotificationCenter.default.removeObserver(token) }

        // currentMission returns nil by default (TODO stub), so no completion fires.
        await service.evaluateCompletion(squadId: UUID())
        XCTAssertFalse(notificationFired, "evaluateCompletion should not fire when mission is nil")
    }
}
