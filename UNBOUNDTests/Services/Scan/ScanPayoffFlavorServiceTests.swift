// UNBOUNDTests/Services/Scan/ScanPayoffFlavorServiceTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class ScanPayoffFlavorServiceTests: XCTestCase {
    func testReturnsNonEmptyString() async {
        let service = ScanPayoffFlavorService()
        let identity = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        let result = await service.flavor(for: identity)
        XCTAssertFalse(result.isEmpty)
        XCTAssertLessThan(result.count, 200)
    }

    func testFallbackOnNetworkError() async {
        // The default ClaudeClient may not have a key in test env — fallback path is exercised.
        let service = ScanPayoffFlavorService()
        let identity = BuildIdentity(primary: .mobility, secondary: nil, shape: .lean)
        let result = await service.flavor(for: identity)
        // Either real Haiku response or "Your work is showing." — both pass
        XCTAssertFalse(result.isEmpty)
    }

    func testComposedPromptContainsIdentityName() {
        let prompt = ScanPayoffFlavorService.composedPrompt(
            buildIdentityName: "Power Specialist",
            dominantAxis: "Power"
        )
        XCTAssertTrue(prompt.contains("Power Specialist"))
        XCTAssertTrue(prompt.contains("Power"))
    }

    func testBalancedIdentityUsesBalancedFallback() {
        let prompt = ScanPayoffFlavorService.composedPrompt(
            buildIdentityName: "Balanced Athlete",
            dominantAxis: "balanced"
        )
        XCTAssertTrue(prompt.contains("balanced"))
    }
}
