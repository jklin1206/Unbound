import XCTest
@testable import UNBOUND

final class ProgramDayFuelSummaryTests: XCTestCase {
    func test_trainingDay_producesKcalAndProteinText() {
        let text = ProgramDayFuelSummary.text(kcal: 2850, proteinGrams: 180, isRestDay: false)
        XCTAssertEqual(text, "2850 kcal · 180g protein")
    }
    func test_restDay_hasNoNumbers() {
        let text = ProgramDayFuelSummary.text(kcal: 2200, proteinGrams: 160, isRestDay: true)
        XCTAssertEqual(text, "rest day")
    }
}
