import XCTest
@testable import UNBOUND

// MIGRATION (Phase 2e): SplitLookup.split now takes buildIdentity: BuildIdentity.
// Tests updated to pass equivalent BuildIdentity values.
// Calisthenic path = control specialist (was .shredded).
// Weights path = any non-control identity (was .vTaper / .heavyDuty / .leanCut).

final class SplitLookupTests: XCTestCase {

    // Convenience builders for readable test code.
    private static let controlSpecialist = BuildIdentity(primary: .control, secondary: nil, shape: .specialist)
    private static let powerHybrid       = BuildIdentity(primary: .power, secondary: nil, shape: .hybrid)
    private static let powerSpecialist   = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
    private static let balancedAthlete   = BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete)

    // Target frequency has cases .three / .four / .five / .six
    // numericCount must map cleanly to Int for schedule planning.
    func testTargetFrequencyNumericCount() {
        XCTAssertEqual(TargetFrequency.three.numericCount, 3)
        XCTAssertEqual(TargetFrequency.four.numericCount, 4)
        XCTAssertEqual(TargetFrequency.five.numericCount, 5)
        XCTAssertEqual(TargetFrequency.six.numericCount, 6)
    }

    // Control specialist (was .shredded) is the calisthenic/bodyweight-coded identity.
    func testControlSpecialistThreeDayIsFullBodyTriple() {
        let split = SplitLookup.split(buildIdentity: Self.controlSpecialist, frequency: .three)
        XCTAssertEqual(split.trainingDayTemplates, [.fullBody, .fullBody, .fullBody])
    }

    func testControlSpecialistFiveIsPPLSkillWeakPoint() {
        let split = SplitLookup.split(buildIdentity: Self.controlSpecialist, frequency: .five)
        XCTAssertEqual(split.trainingDayTemplates, [.push, .pull, .legs, .skill, .weakPoint])
    }

    // Weight-training identities share the non-calisthenic split table.
    func testPowerHybridFourIsUpperLowerTwice() {
        let split = SplitLookup.split(buildIdentity: Self.powerHybrid, frequency: .four)
        XCTAssertEqual(split.trainingDayTemplates, [.upper, .lower, .upper, .lower])
    }

    func testPowerSpecialistSixIsPPLPPL() {
        let split = SplitLookup.split(buildIdentity: Self.powerSpecialist, frequency: .six)
        XCTAssertEqual(split.trainingDayTemplates, [.push, .pull, .legs, .push, .pull, .legs])
    }

    func testBalancedAthleteThreeIsUpperLowerFull() {
        let split = SplitLookup.split(buildIdentity: Self.balancedAthlete, frequency: .three)
        XCTAssertEqual(split.trainingDayTemplates, [.upper, .lower, .fullBody])
    }

    // Every (buildIdentity, frequency) pair must yield a split whose training-day
    // count matches the frequency. This guards against any drift in the table.
    func testSplitCountAlwaysMatchesFrequency() {
        let identities: [BuildIdentity] = [
            Self.controlSpecialist,
            Self.powerHybrid,
            Self.powerSpecialist,
            Self.balancedAthlete
        ]
        let frequencies: [TargetFrequency] = [.three, .four, .five, .six]
        for identity in identities {
            for f in frequencies {
                let split = SplitLookup.split(buildIdentity: identity, frequency: f)
                XCTAssertEqual(split.trainingDayTemplates.count, f.numericCount,
                               "\(identity.displayName) + \(f) should yield \(f.numericCount) templates, got \(split.trainingDayTemplates.count)")
                XCTAssertFalse(split.trainingDayTemplates.contains(.rest),
                               "Split shouldn't contain rest days — those are scheduled separately")
            }
        }
    }
}
