import XCTest
@testable import UNBOUND

final class SquadMissionTests: XCTestCase {
    func testCodableRoundtrip() throws {
        let m = SquadMission(
            id: UUID(),
            squadId: UUID(),
            weekIso: "2026-W20",
            kind: .alignedSessions,
            target: 24,
            currentProgress: 8,
            completedAt: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(m)
        let decoded = try JSONDecoder().decode(SquadMission.self, from: data)
        XCTAssertEqual(decoded, m)
    }

    func testProgressFraction() {
        var m = SquadMission(
            id: UUID(), squadId: UUID(), weekIso: "2026-W20",
            kind: .alignedSessions, target: 10, currentProgress: 3,
            completedAt: nil, createdAt: .now
        )
        XCTAssertEqual(m.progressFraction, 0.3, accuracy: 0.01)
        XCTAssertFalse(m.isCompleted)
        m.completedAt = .now
        XCTAssertTrue(m.isCompleted)
    }

    func testAllKindsHaveDisplayName() {
        for kind in SquadMission.Kind.allCases {
            XCTAssertFalse(kind.displayName.isEmpty)
            XCTAssertFalse(kind.subtitle.isEmpty)
        }
    }
}
