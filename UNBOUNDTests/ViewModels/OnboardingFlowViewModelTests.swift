import XCTest
@testable import UNBOUND

@MainActor
final class OnboardingFlowViewModelFeedbackDefaultTests: XCTestCase {

    func testCurrentExperienceDefaultsToQuick() {
        let flow = OnboardingFlowViewModel()
        flow.experience = .current
        let fields = flow.buildFirestorePayload()
        XCTAssertEqual(fields["trainingFeedbackMode"] as? String, "quick")
    }

    func testNeverExperienceDefaultsToSilent() {
        let flow = OnboardingFlowViewModel()
        flow.experience = .never
        let fields = flow.buildFirestorePayload()
        XCTAssertEqual(fields["trainingFeedbackMode"] as? String, "silent")
    }

    func testNoExperienceWritesNoFeedbackMode() {
        let flow = OnboardingFlowViewModel()
        flow.experience = nil
        let fields = flow.buildFirestorePayload()
        XCTAssertNil(fields["trainingFeedbackMode"])
    }
}
