// UNBOUNDTests/Services/LinkedSessionEvaluatorTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class LinkedSessionEvaluatorTests: XCTestCase {

    private var mockXP: MockSessionXPService!

    override func setUp() {
        super.setUp()
        mockXP = MockSessionXPService()
    }

    // MARK: - Tests

    func testAppliesTwentyPercentOfSessionXP() async {
        await LinkedSessionEvaluator.applyLinkedXPBonus(
            userId: "user1",
            sessionXPDelta: 100,
            service: mockXP
        )

        XCTAssertEqual(mockXP.bonusCalls.count, 1)
        // 20% of 100 = 20. No affinity previously applied → net = 20.
        XCTAssertEqual(mockXP.bonusCalls[0].amount, 20)
    }

    func testRoundsCorrectlyForSmallXP() async {
        await LinkedSessionEvaluator.applyLinkedXPBonus(
            userId: "user1",
            sessionXPDelta: 7,
            service: mockXP
        )

        // 7 × 0.20 = 1.4 → Int truncation → 1
        XCTAssertEqual(mockXP.bonusCalls.count, 1)
        XCTAssertEqual(mockXP.bonusCalls[0].amount, 1)
    }

    func testReasonStringIsLinkedSession() async {
        await LinkedSessionEvaluator.applyLinkedXPBonus(
            userId: "user1",
            sessionXPDelta: 50,
            service: mockXP
        )

        XCTAssertEqual(mockXP.bonusCalls.count, 1)
        XCTAssertEqual(mockXP.bonusCalls[0].reason, "linkedSession")
    }
}
