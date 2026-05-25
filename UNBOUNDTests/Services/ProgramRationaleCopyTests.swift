import XCTest
@testable import UNBOUND

final class ProgramRationaleCopyTests: XCTestCase {
    func testEveryReasonCategoryHasCopyAndIcon() {
        for category in ProgramRationale.ReasonCategory.allCases {
            XCTAssertFalse(ProgramRationaleCopy.text(for: category, region: .pull).isEmpty, "\(category)")
            XCTAssertFalse(ProgramRationaleCopy.icon(for: category).isEmpty, "\(category)")
        }
    }

    func testDecisionEncodesNewFieldsButDecodesLegacyPayload() throws {
        let decision = ProgramRationale.Decision(
            category: .skillBlockInserted,
            regionScope: .pull,
            inputSummary: "Skill focus selected.",
            revertible: true
        )
        let encoded = try JSONEncoder().encode(decision)
        let decoded = try JSONDecoder().decode(ProgramRationale.Decision.self, from: encoded)

        XCTAssertEqual(decoded.reasonCategory, .skillBlockInserted)
        XCTAssertEqual(decoded.regionScope, .pull)
        XCTAssertTrue(decoded.revertible)

        let legacy = """
        {"inputSummary":"Old","decisionApplied":"Still works","iconSystemName":"sparkles"}
        """.data(using: .utf8)!
        let legacyDecoded = try JSONDecoder().decode(ProgramRationale.Decision.self, from: legacy)

        XCTAssertNil(legacyDecoded.reasonCategory)
        XCTAssertFalse(legacyDecoded.revertible)
    }
}
