import XCTest
@testable import UNBOUND

// MIGRATION (Phase 2e): ProgramGeneratorInput.archetype replaced by buildIdentity.
// SplitLookup.split now takes buildIdentity:. Tests updated accordingly.

final class RationaleBuilderTests: XCTestCase {

    func testIncludesFrequencyAndSplit() {
        let input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        let split = SplitLookup.split(buildIdentity: input.buildIdentity, frequency: input.targetFrequency)
        let bias = WeakPointBiaser.bias(from: input.focusAreas)
        let rationale = RationaleBuilder.build(input: input, bias: bias, split: split)

        let summaries = rationale.decisions.map(\.inputSummary).joined(separator: " | ").lowercased()
        XCTAssertTrue(summaries.contains("4 days"),
                      "Expected frequency mention; got: \(summaries)")
    }

    func testIncludesTrainingDayList() {
        let input = makeInput(frequency: .three, trainingDays: [.monday, .wednesday, .friday])
        let split = SplitLookup.split(buildIdentity: input.buildIdentity, frequency: input.targetFrequency)
        let rationale = RationaleBuilder.build(input: input, bias: [:], split: split)
        let summaries = rationale.decisions.map(\.inputSummary).joined(separator: " | ").lowercased()
        XCTAssertTrue(summaries.contains("mon") && summaries.contains("wed") && summaries.contains("fri"))
    }

    func testMentionsBodyweightWhenStyleIsBodyweight() {
        var input = makeInput(frequency: .three, trainingDays: [.monday, .wednesday, .friday])
        input.trainingStyle = .bodyweight
        let split = SplitLookup.split(buildIdentity: input.buildIdentity, frequency: input.targetFrequency)
        let rationale = RationaleBuilder.build(input: input, bias: [:], split: split)
        let joined = rationale.decisions.flatMap { [$0.inputSummary, $0.decisionApplied] }
            .joined(separator: " | ").lowercased()
        XCTAssertTrue(joined.contains("bodyweight"),
                      "Expected bodyweight mention when style is .bodyweight; got: \(joined)")
    }

    func testBiasMentionedWhenFocusAreasExist() {
        var input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        input.focusAreas = [
            FocusArea(muscleGroup: .shoulders, priority: 1, rationale: "narrow", suggestedFocus: "side delts"),
            FocusArea(muscleGroup: .back, priority: 2, rationale: "flat", suggestedFocus: "rows")
        ]
        let split = SplitLookup.split(buildIdentity: input.buildIdentity, frequency: input.targetFrequency)
        let bias = WeakPointBiaser.bias(from: input.focusAreas)
        let rationale = RationaleBuilder.build(input: input, bias: bias, split: split)
        let joined = rationale.decisions.map(\.inputSummary).joined(separator: " | ").lowercased()
        XCTAssertTrue(joined.contains("shoulders") && joined.contains("back"),
                      "Expected both flagged groups in rationale; got: \(joined)")
    }

    func testBiasNotMentionedWhenFocusAreasEmpty() {
        let input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        let split = SplitLookup.split(buildIdentity: input.buildIdentity, frequency: input.targetFrequency)
        let rationale = RationaleBuilder.build(input: input, bias: [:], split: split)
        let joined = rationale.decisions.map(\.inputSummary).joined(separator: " | ").lowercased()
        XCTAssertFalse(joined.contains("scan flagged"))
    }

    func testMentionsCutWhenCutModeActive() {
        var input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        input.cutModeActive = true
        let split = SplitLookup.split(buildIdentity: input.buildIdentity, frequency: input.targetFrequency)
        let rationale = RationaleBuilder.build(input: input, bias: [:], split: split)
        let joined = rationale.decisions.map(\.decisionApplied).joined(separator: " | ").lowercased()
        XCTAssertTrue(joined.contains("deficit") || joined.contains("cut"),
                      "Expected cut-related copy; got: \(joined)")
    }

    func testHeadlineAndSummaryNonEmpty() {
        let input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        let split = SplitLookup.split(buildIdentity: input.buildIdentity, frequency: input.targetFrequency)
        let rationale = RationaleBuilder.build(input: input, bias: [:], split: split)
        XCTAssertFalse(rationale.headline.isEmpty)
        XCTAssertFalse(rationale.summaryCopy.isEmpty)
    }

    // MARK: — helper

    // MIGRATION: was archetype: .shredded — now control specialist (equivalent calisthenic identity)
    private func makeInput(frequency: TargetFrequency, trainingDays: Set<Weekday>) -> ProgramGeneratorInput {
        ProgramGeneratorInput(
            userId: "u-1",
            scanId: "s-1",
            analysisId: "a-1",
            buildIdentity: BuildIdentity(primary: .control, secondary: nil, shape: .specialist),
            trainingStyle: .bodyweight,
            equipment: [.bodyweight],
            targetFrequency: frequency,
            trainingDays: trainingDays,
            experience: .current,
            focusAreas: [],
            cutModeActive: false,
            trainingFeedbackMode: .quick,
            progressionStates: [:],
            previousBlock: nil,
            weightKg: 75,
            heightCm: 178,
            age: 24,
            sex: .male,
            blockStartDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
