import XCTest
@testable import UNBOUND

final class CheckpointValidatorTests: XCTestCase {
    func testAccumulatedRecoveryAndSoftCheckInCreateNegativeBias() {
        let result = CheckpointValidator().validate(
            CheckpointValidationInput(
                draft: CheckpointSignalDraft(recoveryStateHint: .accumulated),
                missedSessionSignal: .softCheckIn
            )
        )

        XCTAssertEqual(result.signals.loadAdjustmentBias ?? .nan, -0.24, accuracy: 0.0001)
    }

    func testAttemptedExternalLoadBiasIsIgnoredAndComputedDeterministically() {
        let result = CheckpointValidator().validate(
            CheckpointValidationInput(
                draft: CheckpointSignalDraft(
                    recoveryStateHint: .wellRecovered,
                    attemptedLoadAdjustmentBias: 99
                ),
                standardsCheck: CheckpointStandardsCheck(attemptedCount: 4, clearedCount: 4),
                missedSessionSignal: .onTrack
            )
        )

        XCTAssertEqual(result.ignoredAttemptedLoadAdjustmentBias, 99)
        XCTAssertEqual(result.signals.loadAdjustmentBias ?? .nan, 0.17, accuracy: 0.0001)
    }

    func testNormalizeClampsOutOfBoundsBias() {
        let normalized = CheckpointValidator().normalize(
            CheckpointSignals(loadAdjustmentBias: -9, weakRegions: [.chest, .chest])
        )

        XCTAssertEqual(normalized.loadAdjustmentBias, -1.0)
        XCTAssertEqual(normalized.weakRegions, [.chest])
    }

    func testUnknownWeakRegionStringsAreDropped() {
        let result = CheckpointValidator().validate(
            CheckpointValidationInput(
                draft: CheckpointSignalDraft(
                    recoveryStateHint: .normal,
                    weakRegionIDs: ["lats", "Lower Back", "space lasers", "quads", "lats"]
                )
            )
        )

        XCTAssertEqual(result.signals.weakRegions, [.lats, .lowerBack, .quads])
        XCTAssertEqual(result.droppedWeakRegionIDs, ["space lasers"])
    }

    func testMissedSessionSignalUsesRollingMissRatioThresholds() {
        XCTAssertEqual(MissedSessionSignal.fromScheduledSessions(scheduled: 4, missed: 0), .onTrack)
        XCTAssertEqual(MissedSessionSignal.fromScheduledSessions(scheduled: 4, missed: 1), .softCheckIn)
        XCTAssertEqual(MissedSessionSignal.fromScheduledSessions(scheduled: 5, missed: 4), .resetRecommended)
    }
}
