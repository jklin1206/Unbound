import XCTest
@testable import UNBOUND

final class CheckpointSummarizerTests: XCTestCase {
    func testCheckedInputsProduceStructuredSignalsThenValidatorComputesBias() async {
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

        XCTAssertNil(result.signals.recoveryStateHint)
        XCTAssertEqual(result.signals.weakRegions, [])
        XCTAssertEqual(result.signals.skillFocusHints, [])
        XCTAssertEqual(result.signals.nutrition, nutrition)
        XCTAssertEqual(result.signals.loadAdjustmentBias ?? .nan, 0.05, accuracy: 0.0001)
        XCTAssertTrue(result.narrative.contains("Your note"))
    }

    func testFreeTextDoesNotDriveTrainingSignals() async {
        let result = await LocalCheckpointSummarizer().summarize(
            CheckpointSummaryInput(
                freeText: "Shoulder pain, lats weak, want handstand and pull-up work.",
                standardsCheck: .none,
                nutrition: nil,
                missedSessionSignal: .onTrack
            )
        )

        XCTAssertNil(result.signals.recoveryStateHint)
        XCTAssertEqual(result.signals.weakRegions, [])
        XCTAssertEqual(result.signals.skillFocusHints, [])
        XCTAssertEqual(result.signals.loadAdjustmentBias ?? .nan, 0, accuracy: 0.0001)
        XCTAssertTrue(result.narrative.contains("Your note"))
    }

    func testPainCheckboxDrivesRecoverySignalAndBias() async {
        let result = await LocalCheckpointSummarizer().summarize(
            CheckpointSummaryInput(
                freeText: "",
                standardsCheck: CheckpointStandardsCheck(
                    attemptedCount: 2,
                    clearedCount: 1,
                    painFlagged: true
                ),
                nutrition: nil,
                missedSessionSignal: .onTrack
            )
        )

        XCTAssertEqual(result.signals.recoveryStateHint, .flagged)
        XCTAssertEqual(result.signals.loadAdjustmentBias ?? .nan, -0.48, accuracy: 0.0001)
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

    func testAIRecapFallsBackWhenNetworkDisabled() async {
        let generator = AIMonthlyCheckpointRecapGenerator(networkEnabled: false)
        let signals = CheckpointSignals(loadAdjustmentBias: 0.05)
        let recap = await generator.recap(
            input: CheckpointSummaryInput(
                freeText: "The month felt steady.",
                standardsCheck: CheckpointStandardsCheck(attemptedCount: 3, clearedCount: 3),
                nutrition: nil,
                missedSessionSignal: .onTrack
            ),
            signals: signals
        )

        XCTAssertNotNil(recap)
        XCTAssertTrue(recap?.contains("Training changes still come from validated rules") == true)
    }

    func testAIRecapPromptStatesTrainingBoundary() {
        let prompt = AIMonthlyCheckpointRecapGenerator.composedPrompt(
            input: CheckpointSummaryInput(
                freeText: "I felt strong but busy.",
                standardsCheck: CheckpointStandardsCheck(attemptedCount: 2, clearedCount: 2),
                nutrition: nil,
                missedSessionSignal: .softCheckIn
            ),
            signals: CheckpointSignals(loadAdjustmentBias: -0.03)
        )

        XCTAssertTrue(prompt.contains("approved facts"))
        XCTAssertTrue(prompt.contains("Do not create or imply new training decisions"))
    }
}
