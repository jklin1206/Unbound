import XCTest
@testable import UNBOUND

/// Regression lock for the Heaviest Lift duel picker.
///
/// The duel matches server-side against the `exerciseName` strings that logging
/// writes — which are `MovementDefinition.displayName` / `ExerciseCatalog`
/// display names (e.g. "Barbell Back Squat", "Conventional Deadlift"). If the
/// picker ever offers a string that is NOT a real catalog display name, the
/// duel silently scores 0. These tests make a catalog rename break loudly
/// instead of failing silently in production.
final class FriendChallengeLiftOptionsTests: XCTestCase {

    /// Every offered lift must be an actual catalog `displayName`. This is the
    /// exact string the matcher compares against (lower/trim on both sides).
    func testEveryHeaviestLiftOptionIsARealCatalogDisplayName() {
        let catalogDisplayNames = Set(MovementCatalog.definitions.map { $0.displayName })

        XCTAssertFalse(
            FriendChallengeCreateSheet.heaviestLiftOptions.isEmpty,
            "Heaviest-lift picker resolved to an empty list — every canonical key failed to resolve."
        )

        for option in FriendChallengeCreateSheet.heaviestLiftOptions {
            XCTAssertTrue(
                catalogDisplayNames.contains(option),
                "Heaviest-lift option \"\(option)\" is not a real catalog displayName; the duel would silently score 0."
            )
        }
    }

    /// Guards the derivation itself: a canonical key being dropped/renamed in the
    /// catalog must surface as a count mismatch, not a silently shorter list.
    func testEveryCuratedCanonicalKeyResolves() {
        // The mirror of the private canonical-key list. Kept in sync deliberately
        // so a catalog key removal trips this assertion.
        let curatedKeys = [
            "back squat",
            "front squat",
            "bench press",
            "incline bench press",
            "overhead press",
            "deadlift",
            "romanian deadlift",
            "trap bar deadlift",
            "bent-over row",
            "weighted pullup",
            "hip thrust",
            "barbell curl"
        ]

        for key in curatedKeys {
            XCTAssertNotNil(
                ExerciseCatalog.exercise(named: key),
                "Curated heaviest-lift key \"\(key)\" no longer exists in ExerciseCatalog."
            )
        }

        XCTAssertEqual(
            FriendChallengeCreateSheet.heaviestLiftOptions.count,
            curatedKeys.count,
            "A curated heaviest-lift key failed to resolve to a displayName — catalog renamed or removed an entry."
        )
    }
}
