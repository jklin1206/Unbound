import XCTest
@testable import UNBOUND

final class LocalizationTests: XCTestCase {
    func testTypedKeysHaveEnglishFallbacks() {
        for key in L10n.Key.allCases {
            let fallback = L10n.string(key, defaultValue: "")
            XCTAssertFalse(fallback.isEmpty, "Missing English fallback for \(key.rawValue)")
            XCTAssertNotEqual(fallback, key.rawValue, "Localization returned key for \(key.rawValue)")
        }
    }

    func testAppErrorUsesLocalizedFallback() {
        XCTAssertEqual(
            AppError.networkNoConnection.errorDescription,
            "No internet connection. Please check your network and try again."
        )
        XCTAssertEqual(
            AppError.networkNoConnection.recoverySuggestion,
            "Connect to Wi-Fi or enable cellular data."
        )
    }

    func testOnboardingAnswerCatalogsHaveEnglishFallbacks() {
        var keys: [String] = []

        keys += Gender.allCases.map { onboardingAnswerKey(group: "gender", id: $0.rawValue, field: "displayName") }
        keys += BodyType.allCases.flatMap { answer in
            [
                onboardingAnswerKey(group: "bodyType", id: answer.rawValue, field: "displayName"),
                onboardingAnswerKey(group: "bodyType", id: answer.rawValue, field: "subtitle")
            ]
        }
        keys += Experience.allCases.map { onboardingAnswerKey(group: "experience", id: $0.rawValue, field: "displayName") }
        keys += Frequency.allCases.flatMap { answer in
            [
                onboardingAnswerKey(group: "frequency", id: answer.rawValue, field: "displayName"),
                onboardingAnswerKey(group: "frequency", id: answer.rawValue, field: "subtitle")
            ]
        }
        keys += TargetFrequency.allCases.flatMap { answer in
            [
                onboardingAnswerKey(group: "targetFrequency", id: answer.rawValue, field: "displayName"),
                onboardingAnswerKey(group: "targetFrequency", id: answer.rawValue, field: "subtitle")
            ]
        }
        keys += Equipment.allCases.map { onboardingAnswerKey(group: "equipment", id: $0.rawValue, field: "displayName") }
        keys += ExerciseStyle.allCases.flatMap { answer in
            [
                onboardingAnswerKey(group: "exerciseStyle", id: answer.rawValue, field: "displayName"),
                onboardingAnswerKey(group: "exerciseStyle", id: answer.rawValue, field: "subtitle")
            ]
        }
        keys += Obstacle.allCases.map { onboardingAnswerKey(group: "obstacle", id: $0.rawValue, field: "displayName") }
        keys += SessionLength.allCases.map { onboardingAnswerKey(group: "sessionLength", id: $0.rawValue, field: "displayName") }
        keys += PriorAttempt.allCases.map { onboardingAnswerKey(group: "priorAttempt", id: $0.rawValue, field: "displayName") }
        keys += Goal.allCases.flatMap { answer in
            [
                onboardingAnswerKey(group: "goal", id: answer.rawValue, field: "displayName"),
                onboardingAnswerKey(group: "goal", id: answer.rawValue, field: "subtitle")
            ]
        }
        keys += TargetArea.allCases.map { onboardingAnswerKey(group: "targetArea", id: $0.rawValue, field: "displayName") }
        keys += Motivation.allCases.map { onboardingAnswerKey(group: "motivation", id: $0.rawValue, field: "displayName") }

        for key in keys {
            let fallback = L10n.string(key, defaultValue: "")
            XCTAssertFalse(fallback.isEmpty, "Missing English fallback for \(key)")
            XCTAssertNotEqual(fallback, key, "Localization returned key for \(key)")
        }
    }

    func testAttributeCatalogsHaveEnglishFallbacks() {
        let fields = [
            "displayName",
            "shortCode",
            "trainsCopy",
            "buildVocab",
            "leanSuffix",
            "taglinePhrase"
        ]
        let keys = AttributeKey.allCases.flatMap { attribute in
            fields.map { field in "attribute.\(attribute.rawValue).\(field)" }
        }

        for key in keys {
            let fallback = L10n.string(key, defaultValue: "")
            XCTAssertFalse(fallback.isEmpty, "Missing English fallback for \(key)")
            XCTAssertNotEqual(fallback, key, "Localization returned key for \(key)")
        }
    }

    func testOnboardingScreenKeysHaveEnglishFallbacks() {
        let keys = [
            "onboarding.resultsSnapshot.title",
            "onboarding.planReady.title",
            "onboarding.obstacleFix.consistency.title",
            "onboarding.verdict.dayZero",
            "onboarding.verdict.profile.body",
            "onboarding.verdict.dossier.narrative"
        ]

        for key in keys {
            let fallback = L10n.string(key, defaultValue: "")
            XCTAssertFalse(fallback.isEmpty, "Missing English fallback for \(key)")
            XCTAssertNotEqual(fallback, key, "Localization returned key for \(key)")
        }

        XCTAssertEqual(
            L10n.onboardingFormat("common.level", defaultValue: "LVL %d", 3),
            "LVL 3"
        )
    }

    private func onboardingAnswerKey(group: String, id: String, field: String) -> String {
        "onboarding.answer.\(group).\(id).\(field)"
    }
}
