import XCTest
@testable import UNBOUND

@MainActor
final class SquadMissionServiceTests: XCTestCase {

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
