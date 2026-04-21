import XCTest
@testable import UNBOUND

final class LocalProgramGeneratorDelegationTests: XCTestCase {

    /// The new entry point delegates to DeterministicProgramGenerator — same
    /// input should produce an equivalent 14-day program.
    func testNewEntryPointDelegatesToDeterministic() throws {
        let input = ProgramGeneratorInput(
            userId: "u-1",
            scanId: "s-1",
            analysisId: "a-1",
            archetype: .shredded,
            trainingStyle: .bodyweight,
            equipment: [.bodyweight],
            targetFrequency: .four,
            trainingDays: [.monday, .tuesday, .thursday, .friday],
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
        let direct = try DeterministicProgramGenerator.generate(input: input)
        let viaFacade = try LocalProgramGenerator.generate(input: input)

        // IDs and timestamps will differ (each call generates fresh UUIDs) —
        // compare shape only.
        XCTAssertEqual(direct.days.count, viaFacade.days.count)
        XCTAssertEqual(direct.archetype, viaFacade.archetype)
        XCTAssertEqual(direct.durationDays, viaFacade.durationDays)
        XCTAssertEqual(direct.nutritionPlan.dailyCalories, viaFacade.nutritionPlan.dailyCalories)
        XCTAssertEqual(
            direct.days.map { $0.isRestDay },
            viaFacade.days.map { $0.isRestDay }
        )
    }
}
