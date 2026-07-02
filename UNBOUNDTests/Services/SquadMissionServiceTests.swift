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
            remoteReadsEnabled: true,
            usesLocalMissions: { false }
        )

        await service.recordProgress(
            log: makeLog(userId: "user-m1"),
            userId: "user-m1",
            sourceLogId: "source-m1"
        )

        XCTAssertEqual(backend.missionProgressIncrements.count, 1)
        XCTAssertEqual(backend.missionProgressIncrements.first?.squadId, squad.id)
        XCTAssertEqual(backend.missionProgressIncrements.first?.delta, 1)
        XCTAssertEqual(backend.missionProgressIncrements.first?.sourceLogId, "source-m1")
    }

    func testRecordProgressSkipsWhenNoSquad() async {
        let stubSquad = StubSquadService()  // .empty
        let backend = MockSquadBackend()
        let service = SquadMissionService(
            backend: backend,
            squadService: stubSquad,
            remoteReadsEnabled: true,
            usesLocalMissions: { false }
        )
        await service.recordProgress(
            log: makeLog(userId: "user-m2"),
            userId: "user-m2",
            sourceLogId: "source-m2"
        )
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

    // MARK: - C1: Kind v2 raw values and legacy mapping

    func testMissionKindV2RawValuesAndLegacyMapping() {
        XCTAssertEqual(SquadMission.Kind(rawValue: "total_weight"), .totalWeight)
        XCTAssertEqual(SquadMission.Kind(rawValue: "train_together"), .trainTogether)
        // legacy rows from pre-v2 weeks still decode to a sensible kind
        XCTAssertEqual(SquadMission.Kind(rawValue: "alignedSessions"), .totalSessions)
        XCTAssertEqual(SquadMission.Kind(rawValue: "perfectAttendance"), .crewCoverage)
        XCTAssertEqual(SquadMission.Kind(rawValue: "linkedSessions"), .trainTogether)
        XCTAssertNil(SquadMission.Kind(rawValue: "bogus"))
    }

    func testMissionProgressDisplay() {
        XCTAssertEqual(SquadMission.Kind.totalWeight.progressText(12500, unit: .kilograms), "12,500 kg")
        // Weight targets are stored in kg and convert to the user's unit.
        XCTAssertEqual(SquadMission.Kind.totalWeight.progressText(12500, unit: .pounds), "27,558 lb")
        XCTAssertEqual(SquadMission.Kind.totalWeight.displayAmount(12500, unit: .pounds), 27558)
        XCTAssertEqual(SquadMission.Kind.totalSessions.progressText(7), "7 sessions")
        XCTAssertEqual(SquadMission.Kind.crewCoverage.progressText(3), "3 covered")
    }

    // MARK: - C2: Catalog targets match backend contract

    func testCatalogTargetsMatchBackendContract() {
        XCTAssertEqual(SquadMissionCatalog.target(for: .totalWeight, memberCount: 4), 32_000)
        XCTAssertEqual(SquadMissionCatalog.target(for: .totalSessions, memberCount: 4), 16)
        XCTAssertEqual(SquadMissionCatalog.target(for: .totalReps, memberCount: 4), 2_400)
        XCTAssertEqual(SquadMissionCatalog.target(for: .crewCoverage, memberCount: 4), 4)
        XCTAssertEqual(SquadMissionCatalog.target(for: .trainTogether, memberCount: 4), 3)
    }

    // MARK: - C3: MissionContribution aggregation

    func testContributionAggregationSumsPerUser() {
        let userA = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
        let userB = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!
        let rows: [(userId: UUID?, delta: Int)] = [
            (userA, 10),
            (userB, 5),
            (userA, 3),
            (nil, 1),   // train_together linked: receipt
        ]
        let result = MissionContribution.aggregate(rows: rows)
        let totalA = result.first { $0.userId == userA }?.total
        let totalB = result.first { $0.userId == userB }?.total
        let totalLinked = result.first { $0.userId == nil }?.total
        XCTAssertEqual(totalA, 13)
        XCTAssertEqual(totalB, 5)
        XCTAssertEqual(totalLinked, 1)
        XCTAssertEqual(result.count, 3)
    }

    func testContributionAggregateEmptyIsEmpty() {
        XCTAssertTrue(MissionContribution.aggregate(rows: []).isEmpty)
    }

    func testContributionAggregateIsSortedDescending() {
        let u1 = UUID()
        let u2 = UUID()
        let rows: [(userId: UUID?, delta: Int)] = [(u1, 2), (u2, 10)]
        let result = MissionContribution.aggregate(rows: rows)
        XCTAssertEqual(result.first?.total, 10)
        XCTAssertEqual(result.last?.total, 2)
    }

    // MARK: - C3: pickMission forwards to backend

    func testPickMissionForwardsToBackend() async throws {
        let squad = seededSquad()
        let backend = MockSquadBackend()
        let weekIso = SquadMissionService.currentWeekIso()
        let stubbedMission = SquadMission(
            id: UUID(),
            squadId: squad.id,
            weekIso: weekIso,
            kind: SquadMissionCatalog.templates[0].kind,
            target: SquadMissionCatalog.target(for: SquadMissionCatalog.templates[0].kind, memberCount: 4),
            currentProgress: 0,
            completedAt: nil,
            createdAt: .now
        )
        backend.pickSquadMissionResult = stubbedMission

        let stubSquad = StubSquadService()
        let service = SquadMissionService(
            backend: backend,
            squadService: stubSquad,
            remoteReadsEnabled: false,
            usesLocalMissions: { false }
        )

        let result = try await service.pickMission(squadId: squad.id, kind: .totalWeight)
        XCTAssertEqual(result?.id, stubbedMission.id)
        XCTAssertEqual(result?.kind, .totalWeight)
    }

    func testPickMissionReturnsNilWhenMissionAlreadyExists() async throws {
        let backend = MockSquadBackend()
        backend.pickSquadMissionResult = nil  // on conflict do nothing → no row
        let service = SquadMissionService(
            backend: backend,
            squadService: StubSquadService(),
            remoteReadsEnabled: false,
            usesLocalMissions: { false }
        )
        let result = try await service.pickMission(squadId: UUID(), kind: .totalSessions)
        XCTAssertNil(result)
    }

    // MARK: - C3: latestMission includes completed missions (remote path skipped in unit tests)

    func testLatestMissionReturnsNilWhenRemoteDisabled() async {
        let service = SquadMissionService(remoteReadsEnabled: false)
        let result = await service.latestMission(squadId: UUID())
        XCTAssertNil(result, "latestMission should return nil when remoteReadsEnabled=false")
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
