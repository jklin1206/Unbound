// UNBOUNDTests/Models/LiftTierCriteriaTests.swift
import XCTest
@testable import UNBOUND

final class LiftTierCriteriaTests: XCTestCase {
    func testAllFourLiftsPresent() {
        XCTAssertEqual(LiftTierCriteria.table.count, 4)
        XCTAssertNotNil(LiftTierCriteria.table["bench press"])
        XCTAssertNotNil(LiftTierCriteria.table["back squat"])
        XCTAssertNotNil(LiftTierCriteria.table["deadlift"])
        XCTAssertNotNil(LiftTierCriteria.table["overhead press"])
    }

    func testEveryLiftCoversAllNineTiers() {
        for (lift, tiers) in LiftTierCriteria.table {
            XCTAssertEqual(tiers.count, 9, "\(lift) missing tiers")
            for tier in SkillTier.allCases {
                XCTAssertNotNil(tiers[tier], "\(lift) missing \(tier)")
            }
        }
    }

    func testThresholdsClimbMonotonically() {
        for (lift, tiers) in LiftTierCriteria.table {
            let weights: [Double] = SkillTier.allCases.compactMap {
                if case .weightKg(let w) = tiers[$0] { return w }
                return nil
            }
            XCTAssertEqual(weights.count, 9, "\(lift): non-weight criterion present")
            XCTAssertEqual(weights, weights.sorted(), "\(lift): thresholds not monotonic")
        }
    }
}
