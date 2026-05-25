import XCTest
@testable import UNBOUND

final class CheckpointSummarizerTests: XCTestCase {
    func testFreeTextProducesStructuredSignalsThenValidatorComputesBias() async {
        let nutrition = NutritionTargetCalculator().calculate(
            input: .init(bodyweightKilograms: 80, hardSessionLoggedWithin24Hours: true)
        )

        let result = await LocalCheckpointSummarizer().summarize(
            CheckpointSummaryInput(
                freeText: "Felt fresh overall. Lats are weak and I want pull-up work.",
                standardsCheck: CheckpointStandardsCheck(attemptedCount: 4, clearedCount: 4),
                nutrition: nutrition,
                missedSessionSignal: .onTrack
            )
        )

        XCTAssertEqual(result.signals.recoveryStateHint, .wellRecovered)
        XCTAssertEqual(result.signals.weakRegions, [.lats])
        XCTAssertEqual(result.signals.skillFocusHints, ["strict_pull_up"])
        XCTAssertEqual(result.signals.nutrition, nutrition)
        XCTAssertEqual(result.signals.loadAdjustmentBias ?? .nan, 0.17, accuracy: 0.0001)
        XCTAssertTrue(result.narrative.contains("Arc note"))
    }

    func testEmptyTextFallsBackSafely() async {
        let result = await LocalCheckpointSummarizer().summarize(
            CheckpointSummaryInput(
                freeText: "",
                standardsCheck: .none,
                nutrition: nil,
                missedSessionSignal: .softCheckIn
            )
        )

        XCTAssertNil(result.signals.recoveryStateHint)
        XCTAssertEqual(result.signals.weakRegions, [])
        XCTAssertEqual(result.signals.skillFocusHints, [])
        XCTAssertEqual(result.signals.loadAdjustmentBias ?? .nan, -0.08, accuracy: 0.0001)
        XCTAssertFalse(result.narrative.isEmpty)
    }

    func testValidatorIgnoresAttemptedExternalBias() {
        let result = CheckpointValidator().validate(
            CheckpointValidationInput(
                draft: CheckpointSignalDraft(
                    recoveryStateHint: .normal,
                    attemptedLoadAdjustmentBias: 0.9
                ),
                standardsCheck: .none,
                missedSessionSignal: .onTrack
            )
        )

        XCTAssertEqual(result.ignoredAttemptedLoadAdjustmentBias, 0.9)
        XCTAssertEqual(result.signals.loadAdjustmentBias ?? .nan, 0, accuracy: 0.0001)
    }
}
