import XCTest
@testable import UNBOUND

final class VowBankPoolTests: XCTestCase {
    func testEveryLaneHasCardsAtEveryBet() {
        for lane in VowLane.allCases {
            for bet in VowBet.allCases {
                let matches = VowBankPool.all.filter { $0.lane == lane && $0.bet == bet }
                XCTAssertFalse(matches.isEmpty, "No card for \(lane)/\(bet)")
            }
        }
    }

    func testTemplateIdsAreUnique() {
        let ids = VowBankPool.all.map(\.templateId)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testCopyIsBrandSafe() {
        // Brand guardrail: no "limiter/weak link/restriction" negging language.
        let banned = ["limiter", "weak link", "restriction", "holding you back", "trial", "challenge"]
        for template in VowBankPool.all {
            let blob = (template.displayName + " " + template.blurb).lowercased()
            for word in banned {
                XCTAssertFalse(blob.contains(word), "Banned copy '\(word)' in \(template.templateId)")
            }
        }
    }

    func testFuelTargetsAreCountBased() {
        for template in VowBankPool.all where template.lane == .fuel {
            XCTAssertGreaterThanOrEqual(template.target.count, 1)
        }
    }
}
