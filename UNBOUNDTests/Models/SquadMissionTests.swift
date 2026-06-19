import XCTest
@testable import UNBOUND

final class SquadMissionTests: XCTestCase {
    func testCodableRoundtrip() throws {
        let m = SquadMission(
            id: UUID(),
            squadId: UUID(),
            weekIso: "2026-W20",
            kind: .totalSessions,
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
            kind: .totalSessions, target: 10, currentProgress: 3,
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

    func testCatalogMatchesServerSimpleHashFixtures() throws {
        // Fixtures computed against 5-template catalog (mod 5), identical hash fn.
        // Recompute if templates array order changes.
        let cases: [(id: String, week: String, members: Int, kind: SquadMission.Kind, target: Int)] = [
            ("00000000-0000-0000-0000-000000000001", "2026-W23", 4, .totalSessions, 16),
            ("11111111-1111-1111-1111-111111111111", "2026-W23", 3, .totalSessions, 12),
            ("9f4d8610-13fa-42e0-81b3-32a79a9e4c0f", "2026-W01", 5, .trainTogether, 3),
            ("9f4d8610-13fa-42e0-81b3-32a79a9e4c0f", "2026-W02", 5, .crewCoverage, 5),
            ("00000000-0000-0000-0000-000000000007", "2026-W23", 9, .trainTogether, 3),
        ]

        for testCase in cases {
            let id = try XCTUnwrap(UUID(uuidString: testCase.id))
            let generated = SquadMissionCatalog.generate(
                squadId: id,
                weekIso: testCase.week,
                memberCount: testCase.members
            )
            XCTAssertEqual(generated.kind, testCase.kind, "\(testCase.id) \(testCase.week)")
            XCTAssertEqual(generated.target, testCase.target, "\(testCase.id) \(testCase.week)")
        }
    }
}
