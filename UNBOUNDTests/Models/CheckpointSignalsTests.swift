import XCTest
@testable import UNBOUND

final class CheckpointSignalsTests: XCTestCase {
    func testCodableRoundTripClampsBiasAndNormalizesCollections() throws {
        let signals = CheckpointSignals(
            loadAdjustmentBias: 3.25,
            recoveryStateHint: .wellRecovered,
            weakRegions: [.lats, .lats, .chest],
            skillFocusHints: ["pp.pullup", " ", "pp.pullup", "hs.wall-handstand-30"],
            nutrition: NutritionContext(
                bodyweightKilograms: 80,
                protein: .init(minGrams: 130, maxGrams: 175, recommendedGrams: 145, displayText: "130-175g protein"),
                hydration: .init(liters: 2.8, displayText: "2.8L hydration"),
                trainingFuel: .hardSession,
                usesGenericFallback: false
            ),
            freeTextSummary: "  Strong pull work, shoulder fatigue late.  "
        )

        let data = try JSONEncoder().encode(signals)
        let decoded = try JSONDecoder().decode(CheckpointSignals.self, from: data)

        XCTAssertEqual(decoded.loadAdjustmentBias, 1.0)
        XCTAssertEqual(decoded.weakRegions, [.lats, .chest])
        XCTAssertEqual(decoded.skillFocusHints, ["pp.pullup", "hs.wall-handstand-30"])
        XCTAssertEqual(decoded.freeTextSummary, "Strong pull work, shoulder fatigue late.")
    }

    func testCheckpointOutcomeRoundTripCompletedAndSkipped() throws {
        let completed = CheckpointOutcome.completed(
            CheckpointSignals(recoveryStateHint: .normal, weakRegions: [.quads])
        )
        let completedData = try JSONEncoder().encode(completed)
        let completedDecoded = try JSONDecoder().decode(CheckpointOutcome.self, from: completedData)
        XCTAssertEqual(completedDecoded, completed)
        XCTAssertFalse(completedDecoded.wasSkipped)

        let skipped = CheckpointOutcome.skipped
        let skippedData = try JSONEncoder().encode(skipped)
        let skippedDecoded = try JSONDecoder().decode(CheckpointOutcome.self, from: skippedData)
        XCTAssertEqual(skippedDecoded, skipped)
        XCTAssertTrue(skippedDecoded.wasSkipped)
    }
}
