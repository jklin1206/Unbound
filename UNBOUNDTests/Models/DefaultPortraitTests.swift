import XCTest
@testable import UNBOUND

/// Locks the default-portrait variant resolution and the asset-name strings.
/// The raw values must match the bundled imageset names - a rename on either
/// side silently orphans the art and every no-photo avatar falls back to the
/// letter circle.
final class DefaultPortraitTests: XCTestCase {

    func testAssetNamesMatchBundledImagesets() {
        XCTAssertEqual(DefaultPortrait.masculine.rawValue, "profile_avatar_default_m")
        XCTAssertEqual(DefaultPortrait.feminine.rawValue, "profile_avatar_default_f")
    }

    func testStatedGenderWins() {
        XCTAssertEqual(DefaultPortrait.resolve(gender: .female, biologicalSex: .male), .feminine)
        XCTAssertEqual(DefaultPortrait.resolve(gender: .male, biologicalSex: .female), .masculine)
    }

    func testBiologicalSexFallsBackWhenGenderUnstated() {
        XCTAssertEqual(DefaultPortrait.resolve(gender: nil, biologicalSex: .female), .feminine)
        XCTAssertEqual(DefaultPortrait.resolve(gender: .unspecified, biologicalSex: .female), .feminine)
        XCTAssertEqual(DefaultPortrait.resolve(gender: nil, biologicalSex: .male), .masculine)
    }

    func testUnknownEverythingDefaultsMasculine() {
        XCTAssertEqual(DefaultPortrait.resolve(gender: nil, biologicalSex: nil), .masculine)
        XCTAssertEqual(DefaultPortrait.resolve(gender: .unspecified, biologicalSex: nil), .masculine)
    }
}
