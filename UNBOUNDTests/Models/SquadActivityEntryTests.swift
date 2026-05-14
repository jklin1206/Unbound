import XCTest
@testable import UNBOUND

final class SquadActivityEntryTests: XCTestCase {
    func testTrialCompletedRoundtrip() throws {
        let entry = makeEntry(
            kind: .trialCompleted,
            payload: .trialCompleted(trialName: "Power Focus", theme: .axis(.power))
        )
        try roundtrip(entry)
    }

    func testTitleUnlockedRoundtrip() throws {
        let entry = makeEntry(
            kind: .titleUnlocked,
            payload: .titleUnlocked(titleId: TitleID(path: .axis(.power), tier: .bronze))
        )
        try roundtrip(entry)
    }

    func testLinkedSessionRoundtrip() throws {
        let entry = makeEntry(
            kind: .linkedSession,
            payload: .linkedSession(participantUserIds: [UUID(), UUID()], durationMinutes: 47)
        )
        try roundtrip(entry)
    }

    func testMemberJoinedRoundtrip() throws {
        let entry = makeEntry(
            kind: .memberJoined,
            payload: .memberJoined(memberDisplayName: "Maya")
        )
        try roundtrip(entry)
    }

    func testAffinityChangedRoundtrip() throws {
        let entry = makeEntry(
            kind: .affinityChanged,
            payload: .affinityChanged(newAxis: .mobility, byDisplayName: "Marcus")
        )
        try roundtrip(entry)
    }

    func testAffinityChangedNilAxisRoundtrip() throws {
        let entry = makeEntry(
            kind: .affinityChanged,
            payload: .affinityChanged(newAxis: nil, byDisplayName: "Marcus")
        )
        try roundtrip(entry)
    }

    func testSquadStreakExtendedRoundtrip() throws {
        let entry = makeEntry(
            kind: .squadStreakExtended,
            payload: .squadStreakExtended(weeks: 12)
        )
        try roundtrip(entry)
    }

    func testSystemEventNilUserIdRoundtrip() throws {
        let entry = SquadActivityEntry(
            id: UUID(), squadId: UUID(), userId: nil,
            kind: .squadStreakExtended,
            payload: .squadStreakExtended(weeks: 4),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try roundtrip(entry)
        // Verify the decoded entry also has nil userId.
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(SquadActivityEntry.self, from: data)
        XCTAssertNil(decoded.userId, "System event userId must decode as nil")
    }

    // MARK: helpers
    private func makeEntry(kind: SquadActivityEntry.Kind, payload: SquadActivityPayload) -> SquadActivityEntry {
        SquadActivityEntry(
            id: UUID(), squadId: UUID(), userId: UUID(),
            kind: kind, payload: payload,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func roundtrip(_ entry: SquadActivityEntry) throws {
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(SquadActivityEntry.self, from: data)
        XCTAssertEqual(decoded, entry)
    }
}
