import XCTest
@testable import UNBOUND

final class SplitLookupTests: XCTestCase {
    // Target frequency has cases .three / .four / .five / .six
    // numericCount must map cleanly to Int for schedule planning.
    func testTargetFrequencyNumericCount() {
        XCTAssertEqual(TargetFrequency.three.numericCount, 3)
        XCTAssertEqual(TargetFrequency.four.numericCount, 4)
        XCTAssertEqual(TargetFrequency.five.numericCount, 5)
        XCTAssertEqual(TargetFrequency.six.numericCount, 6)
    }

    // `.shredded` is the calisthenic/bodyweight-coded archetype (Saitama build).
    func testShreddedThreeDayIsFullBody() {
        let split = SplitLookup.split(archetype: .shredded, frequency: .three)
        XCTAssertEqual(split.trainingDayTemplates, [.fullBody, .fullBody, .fullBody])
    }

    func testShreddedFiveIsPPLSkillWeakPoint() {
        let split = SplitLookup.split(archetype: .shredded, frequency: .five)
        XCTAssertEqual(split.trainingDayTemplates, [.push, .pull, .legs, .skill, .weakPoint])
    }

    // Weight-training archetypes (vTaper/heavyDuty/leanCut) share one split table.
    func testVTaperFourIsUpperLowerTwice() {
        let split = SplitLookup.split(archetype: .vTaper, frequency: .four)
        XCTAssertEqual(split.trainingDayTemplates, [.upper, .lower, .upper, .lower])
    }

    func testHeavyDutySixIsPPLPPL() {
        let split = SplitLookup.split(archetype: .heavyDuty, frequency: .six)
        XCTAssertEqual(split.trainingDayTemplates, [.push, .pull, .legs, .push, .pull, .legs])
    }

    func testLeanCutThreeIsUpperLowerFull() {
        let split = SplitLookup.split(archetype: .leanCut, frequency: .three)
        XCTAssertEqual(split.trainingDayTemplates, [.upper, .lower, .fullBody])
    }

    // Every (archetype, frequency) pair must yield a split whose training-day
    // count matches the frequency. This guards against any drift in the table.
    func testSplitCountAlwaysMatchesFrequency() {
        let archetypes: [Archetype] = [.shredded, .vTaper, .heavyDuty, .leanCut]
        let frequencies: [TargetFrequency] = [.three, .four, .five, .six]
        for a in archetypes {
            for f in frequencies {
                let split = SplitLookup.split(archetype: a, frequency: f)
                XCTAssertEqual(split.trainingDayTemplates.count, f.numericCount,
                               "\(a) + \(f) should yield \(f.numericCount) templates, got \(split.trainingDayTemplates.count)")
                XCTAssertFalse(split.trainingDayTemplates.contains(.rest),
                               "Split shouldn't contain rest days — those are scheduled separately")
            }
        }
    }
}
