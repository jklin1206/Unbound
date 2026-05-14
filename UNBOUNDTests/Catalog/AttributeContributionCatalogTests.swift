// UNBOUNDTests/Catalog/AttributeContributionCatalogTests.swift
//
// NOTE: This test target uses BUNDLE_LOADER (hosted tests within the app bundle).
// AttributeContributions.json is a main-app resource, so all JSON loading uses
// Bundle.main — not Bundle(for: self) which would look in the test bundle.
import XCTest
@testable import UNBOUND

@MainActor
final class AttributeContributionCatalogTests: XCTestCase {

    private func loadExercises() -> [String: [String: Double]]? {
        guard let url = Bundle.main.url(forResource: "AttributeContributions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exercises = raw["exercises"] as? [String: [String: Double]]
        else {
            return nil
        }
        return exercises
    }

    func testEveryCatalogEntrySumsToOne() {
        // Self-consistency: every entry in AttributeContributions.json
        // must have weights summing to 1.0 ± 0.01.
        guard let exercises = loadExercises() else {
            XCTFail("AttributeContributions.json failed to load from Bundle.main")
            return
        }
        XCTAssertGreaterThan(exercises.count, 50, "AttributeContributions.json should have ~58 entries")
        for (key, weights) in exercises {
            let sum = weights.values.reduce(0.0, +)
            XCTAssertEqual(sum, 1.0, accuracy: 0.01, "Exercise '\(key)' sum=\(sum)")
        }
    }

    func testEveryAttributeKeyAppearsInAtLeastOneVector() {
        guard let exercises = loadExercises() else {
            XCTFail("AttributeContributions.json failed to load from Bundle.main")
            return
        }
        var represented: Set<AttributeKey> = []
        for (_, weights) in exercises {
            for (axisName, w) in weights where w > 0 {
                if let key = AttributeKey(rawValue: axisName) {
                    represented.insert(key)
                }
            }
        }
        for key in AttributeKey.allCases {
            XCTAssertTrue(represented.contains(key),
                "AttributeKey '\(key)' never appears with weight > 0 in any vector.")
        }
    }

    func testAllJSONKeysAreSpaceLowercaseFormat() {
        // Guard against future snake_case regressions: every key must be
        // space-lowercase (no underscores, no uppercase).
        guard let exercises = loadExercises() else {
            XCTFail("AttributeContributions.json failed to load from Bundle.main")
            return
        }
        for key in exercises.keys {
            XCTAssertFalse(key.contains("_"),
                "Exercise key '\(key)' contains underscore — must use space-lowercase CatalogExercise.name format.")
            XCTAssertEqual(key, key.lowercased(),
                "Exercise key '\(key)' must be fully lowercase.")
        }
    }
}
