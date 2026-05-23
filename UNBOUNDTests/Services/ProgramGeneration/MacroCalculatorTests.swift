import XCTest
@testable import UNBOUND

final class MacroCalculatorTests: XCTestCase {

    // A 25yo male, 80kg, 180cm, training 4x/wk sits in ~2600-3200 kcal TDEE territory.
    // The formula (Mifflin-St Jeor + activity 1.55) should produce something reasonable.
    func testMaintenanceReasonableRange() {
        let m = MacroCalculator.macros(
            weightKg: 80, heightCm: 180, age: 25, sex: .male,
            frequency: .four, cutMode: false
        )
        XCTAssertGreaterThan(m.calories, 2500)
        XCTAssertLessThan(m.calories, 3300)
    }

    // Same female baseline is ~10–15% lower than male.
    func testFemaleIsLowerThanMale() {
        let male = MacroCalculator.macros(weightKg: 80, heightCm: 180, age: 25, sex: .male, frequency: .four, cutMode: false)
        let female = MacroCalculator.macros(weightKg: 80, heightCm: 180, age: 25, sex: .female, frequency: .four, cutMode: false)
        XCTAssertLessThan(female.calories, male.calories)
    }

    // Cut mode should reduce calories by ~15%.
    func testCutIs15PercentLower() {
        let base = MacroCalculator.macros(weightKg: 80, heightCm: 180, age: 25, sex: .male, frequency: .four, cutMode: false)
        let cut  = MacroCalculator.macros(weightKg: 80, heightCm: 180, age: 25, sex: .male, frequency: .four, cutMode: true)
        let ratio = Double(cut.calories) / Double(base.calories)
        XCTAssertEqual(ratio, 0.85, accuracy: 0.01)
    }

    // Protein bumps on cut (preserves lean mass during deficit).
    func testProteinBumpsOnCut() {
        let base = MacroCalculator.macros(weightKg: 80, heightCm: 180, age: 25, sex: .male, frequency: .four, cutMode: false)
        let cut  = MacroCalculator.macros(weightKg: 80, heightCm: 180, age: 25, sex: .male, frequency: .four, cutMode: true)
        XCTAssertGreaterThan(cut.proteinG, base.proteinG)
    }

    // 1.8 g/kg maintenance, 2.2 g/kg cut. Exact for 80kg: 144 vs 176.
    func testProteinTargetsExact() {
        let base = MacroCalculator.macros(weightKg: 80, heightCm: 180, age: 25, sex: .male, frequency: .four, cutMode: false)
        let cut  = MacroCalculator.macros(weightKg: 80, heightCm: 180, age: 25, sex: .male, frequency: .four, cutMode: true)
        XCTAssertEqual(base.proteinG, 144)   // 80 * 1.8
        XCTAssertEqual(cut.proteinG, 176)    // 80 * 2.2
    }

    // Higher frequency → more calories (activity factor climbs).
    func testFrequencyLadder() {
        let c3 = MacroCalculator.macros(weightKg: 80, heightCm: 180, age: 25, sex: .male, frequency: .three, cutMode: false).calories
        let c6 = MacroCalculator.macros(weightKg: 80, heightCm: 180, age: 25, sex: .male, frequency: .six,   cutMode: false).calories
        XCTAssertGreaterThan(c6, c3)
    }

    // Carbs + fat shouldn't fall to zero or negative even at small intakes.
    func testNeverNegativeMacros() {
        let m = MacroCalculator.macros(weightKg: 50, heightCm: 160, age: 60, sex: .female, frequency: .three, cutMode: true)
        XCTAssertGreaterThanOrEqual(m.carbsG, 0)
        XCTAssertGreaterThanOrEqual(m.fatG, 0)
    }
}
