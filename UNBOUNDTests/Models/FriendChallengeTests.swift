import XCTest
@testable import UNBOUND

final class FriendChallengeTests: XCTestCase {
    private func makeLog(
        localStartHour: Int? = nil
    ) -> WorkoutLog {
        WorkoutLog(
            id: UUID().uuidString,
            userId: "user",
            programId: "program",
            dayNumber: 1,
            plannedWorkoutName: "Session",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_001_800),
            exerciseEntries: [],
            overallNotes: nil,
            overallRPE: 7,
            durationMinutes: 30,
            localStartHour: localStartHour
        )
    }

    func testCodableRoundtrip() throws {
        let c = FriendChallenge(
            id: UUID(),
            challengerId: UUID(),
            challengedId: UUID(),
            squadId: UUID(),
            kind: .mostSessions,
            exerciseName: nil,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            expiresAt: Date(timeIntervalSince1970: 1_700_604_800),
            acceptedAt: nil,
            challengerProgress: 3,
            challengedProgress: 2,
            winnerUserId: nil
        )
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(FriendChallenge.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testIsActiveTrueWhenNoWinnerAndNotExpired() {
        let c = FriendChallenge(
            id: UUID(), challengerId: UUID(), challengedId: UUID(), squadId: UUID(),
            kind: .mostSessions,
            exerciseName: nil,
            startedAt: .now.addingTimeInterval(-3600),
            expiresAt: .now.addingTimeInterval(3600),
            acceptedAt: .now,
            challengerProgress: 1,
            challengedProgress: 0,
            winnerUserId: nil
        )
        XCTAssertTrue(c.isActive)
        XCTAssertFalse(c.isExpired)
    }

    func testIsExpiredTrueAfterExpiry() {
        let c = FriendChallenge(
            id: UUID(), challengerId: UUID(), challengedId: UUID(), squadId: UUID(),
            kind: .mostSessions,
            exerciseName: nil,
            startedAt: .now.addingTimeInterval(-7200),
            expiresAt: .now.addingTimeInterval(-1),
            acceptedAt: .now.addingTimeInterval(-7000),
            challengerProgress: 2,
            challengedProgress: 3,
            winnerUserId: nil
        )
        XCTAssertTrue(c.isExpired)
        XCTAssertFalse(c.isActive)
    }

    func testIsPendingWhenNotAccepted() {
        let c = FriendChallenge(
            id: UUID(), challengerId: UUID(), challengedId: UUID(), squadId: UUID(),
            kind: .earlyRiser,
            exerciseName: nil,
            startedAt: .now,
            expiresAt: .now.addingTimeInterval(86400),
            acceptedAt: nil,
            challengerProgress: 0,
            challengedProgress: 0,
            winnerUserId: nil
        )
        XCTAssertTrue(c.isPending)
    }

    func testAllKindsHaveDisplayName() {
        for kind in FriendChallenge.Kind.allCases {
            XCTAssertFalse(kind.displayName.isEmpty)
            XCTAssertFalse(kind.subtitle.isEmpty)
        }
    }

    func testKindMenuIsAllReal() {
        XCTAssertEqual(
            Set(FriendChallenge.Kind.allCases),
            [.mostSessions, .earlyRiser, .mostWeight, .mostReps, .heaviestLift]
        )
        XCTAssertEqual(Set(FriendChallenge.Kind.creationOptions), Set(FriendChallenge.Kind.allCases))
        for kind in FriendChallenge.Kind.allCases {
            XCTAssertTrue(kind.isSupportedForCreation)
        }
    }

    func testHeaviestLiftRequiresExercise() {
        XCTAssertTrue(FriendChallenge.Kind.heaviestLift.requiresExercisePick)
        XCTAssertTrue(FriendChallenge.Kind.heaviestLift.usesMaxScore)
        XCTAssertFalse(FriendChallenge.Kind.mostWeight.requiresExercisePick)
        XCTAssertFalse(FriendChallenge.Kind.mostWeight.usesMaxScore)
    }

    func testLegacyKindRowsDecodeAsNilAndAreDropped() {
        // Historical pre-v2 kinds were never re-creatable, so any stored rows are
        // dropped rather than mapped.
        XCTAssertNil(FriendChallenge.Kind(rawValue: "proteinGoal"))
        XCTAssertNil(FriendChallenge.Kind(rawValue: "noMissedDays"))
        XCTAssertNil(FriendChallenge.Kind(rawValue: "firstToFinishTrial"))
        XCTAssertNil(FriendChallenge.Kind(rawValue: "mostAlignedSessions"))
    }

    func testProgressLabelFormatsPerKind() {
        XCTAssertEqual(FriendChallenge.Kind.mostSessions.progressLabel(for: 1), "1 session")
        XCTAssertEqual(FriendChallenge.Kind.mostSessions.progressLabel(for: 4), "4 sessions")
        XCTAssertEqual(FriendChallenge.Kind.mostWeight.progressLabel(for: 1250, unit: .kilograms), "1,250 kg")
        XCTAssertEqual(FriendChallenge.Kind.heaviestLift.progressLabel(for: 100, unit: .kilograms), "100 kg")
        // Weight scores are stored in kg and convert to the user's unit.
        XCTAssertEqual(FriendChallenge.Kind.mostWeight.progressLabel(for: 1250, unit: .pounds), "2,756 lb")
        XCTAssertEqual(FriendChallenge.Kind.heaviestLift.progressLabel(for: 100, unit: .pounds), "220 lb")
        XCTAssertEqual(FriendChallenge.Kind.mostReps.progressLabel(for: 60), "60 reps")
    }

    func testProgressPolicyDeltasAreExplicit() {
        var log = makeLog(localStartHour: 7)
        // Every supported kind signals +1 when the log qualifies; the server
        // computes the real weighted delta.
        XCTAssertEqual(FriendChallengeProgressPolicy.progressDelta(for: .mostSessions, log: log), 1)
        XCTAssertEqual(FriendChallengeProgressPolicy.progressDelta(for: .earlyRiser, log: log), 1)
        XCTAssertEqual(FriendChallengeProgressPolicy.progressDelta(for: .mostWeight, log: log), 1)
        XCTAssertEqual(FriendChallengeProgressPolicy.progressDelta(for: .mostReps, log: log), 1)
        XCTAssertEqual(FriendChallengeProgressPolicy.progressDelta(for: .heaviestLift, log: log), 1)

        // earlyRiser keeps its before-8am gate.
        log.localStartHour = 8
        XCTAssertEqual(FriendChallengeProgressPolicy.progressDelta(for: .earlyRiser, log: log), 0)
        // Non-time-gated kinds still signal regardless of the hour.
        XCTAssertEqual(FriendChallengeProgressPolicy.progressDelta(for: .mostWeight, log: log), 1)
    }
}
