import XCTest
@testable import UNBOUND

/// Proves the BadgeService ↔ BadgeCatalog contract: the set of ids the
/// service can award must equal the set of ids the catalog defines. Any
/// drift means either a badge unlock silently fails to hydrate
/// (awarded ∉ catalog) or a catalog entry is unreachable (orphan).
@MainActor
final class BadgeCatalogReconciliationTests: XCTestCase {

    private var awardable: Set<String> { BadgeService.awardableIds }
    private var catalog: Set<String> { Set(BadgeCatalog.byId.keys) }

    /// Direction 1: every awardable id must exist in the catalog, else the
    /// award fails `BadgeCatalog.byId[id]` lookup and never hydrates.
    func testEveryAwardableIdIsInCatalog() {
        let missing = awardable.subtracting(catalog).sorted()
        XCTAssertTrue(
            missing.isEmpty,
            "Awarded but NOT in catalog (will silently fail to hydrate): \(missing)"
        )
    }

    /// Direction 2: every catalog id must be reachable by some award trigger,
    /// else it is a permanently-locked orphan in the gallery.
    func testEveryCatalogIdIsAwardable() {
        let orphans = catalog.subtracting(awardable).sorted()
        XCTAssertTrue(
            orphans.isEmpty,
            "Catalog entries no award path can unlock (orphans): \(orphans)"
        )
    }

    /// Full set equality, both directions in one assertion.
    func testCatalogAndAwardableSetsAreEqual() {
        XCTAssertEqual(
            catalog, awardable,
            "BadgeCatalog and BadgeService.awardableIds are out of sync"
        )
    }

    /// Guards the byId map against duplicate ids collapsing entries.
    func testCatalogHasNoDuplicateIds() {
        XCTAssertEqual(
            BadgeCatalog.all.count, catalog.count,
            "BadgeCatalog.all contains duplicate ids"
        )
    }
}
