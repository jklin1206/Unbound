import XCTest
@testable import UNBOUND

@MainActor
final class TitleGrantsTests: XCTestCase {

    private let userId = "title-grants-tests"

    private func profile(levels: [AttributeKey: Int]) -> AttributeProfile {
        var profile = AttributeProfile.empty(userId: userId, at: Date(timeIntervalSince1970: 0))
        for (key, level) in levels {
            profile.set(key, AttributeValue(
                xp: AttributeLevelCurve.xpRequired(forLevel: level),
                lastContributionAt: Date(timeIntervalSince1970: 0)
            ))
        }
        return profile
    }

    // MARK: - Entitlement

    func testInitiateWithEmptyProfileEarnsOnlyTheFirstRankTitle() {
        let titles = TitleGrants.entitledTitles(confirmedRank: .initiate, profile: profile(levels: [:]))
        XCTAssertEqual(titles, [TitleID.rank(.initiate)])
    }

    func testConfirmedRankEntitlesEveryRankTitleUpToIt() {
        let titles = TitleGrants.entitledTitles(confirmedRank: .forged, profile: profile(levels: [:]))
        XCTAssertEqual(titles, [
            TitleID.rank(.initiate), TitleID.rank(.novice),
            TitleID.rank(.apprentice), TitleID.rank(.forged)
        ])
    }

    func testAxisAtTheBarEarnsItsClassTitle() {
        let barLevel = barLevel(for: TitleGrants.axisTitleBar)
        let titles = TitleGrants.entitledTitles(
            confirmedRank: .initiate,
            profile: profile(levels: [.power: barLevel])
        )
        XCTAssertTrue(titles.contains(TitleID.axis(.power)))
        XCTAssertFalse(titles.contains(TitleID.axis(.control)))
    }

    func testAxisJustBelowTheBarEarnsNothing() {
        let barLevel = barLevel(for: TitleGrants.axisTitleBar)
        let titles = TitleGrants.entitledTitles(
            confirmedRank: .initiate,
            profile: profile(levels: [.power: barLevel - 1])
        )
        XCTAssertFalse(titles.contains(TitleID.axis(.power)))
    }

    /// Lowest level whose attribute rank is `tier`, anchored to the real
    /// threshold table rather than hardcoded numbers.
    private func barLevel(for tier: RankTier) -> Int {
        (0...AttributeLevelCurve.maxLevel).first {
            AttributeLevelCurve.rankTitle(forLevel: $0) >= tier
        } ?? AttributeLevelCurve.maxLevel
    }

    // MARK: - Quiet vs announced unlocks

    func testQuietUnlockGrantsWithoutAnnouncing() {
        let defaults = UserDefaults(suiteName: "TitleGrantsTests")!
        defaults.removePersistentDomain(forName: "TitleGrantsTests")
        let service = WeeklyVowsService(store: WeeklyVowsStore(defaults: defaults))

        var announced: [TitleID] = []
        let observer = NotificationCenter.default.addObserver(
            forName: .titleUnlocked, object: nil, queue: nil
        ) { note in
            if let id = note.object as? TitleID { announced.append(id) }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
            defaults.removePersistentDomain(forName: "TitleGrantsTests")
        }

        service.unlockTitle(.rank(.novice), userId: userId, announce: false)
        XCTAssertTrue(service.state(userId: userId).unlockedTitles.contains(.rank(.novice)))
        XCTAssertTrue(announced.isEmpty)

        // Announced unlock fires once; the repeat is a no-op either way.
        service.unlockTitle(.axis(.power), userId: userId)
        service.unlockTitle(.axis(.power), userId: userId)
        XCTAssertEqual(announced, [TitleID.axis(.power)])

        // A quiet grant that already happened stays silent when re-announced.
        service.unlockTitle(.rank(.novice), userId: userId)
        XCTAssertEqual(announced, [TitleID.axis(.power)])
    }

    // MARK: - Naming

    func testRankTitleNames() {
        XCTAssertEqual(TitleCatalog.displayName(for: .rank(.initiate)), "The Unwritten")
        XCTAssertEqual(TitleCatalog.displayName(for: .rank(.unbound)), "Gatebreaker")
    }

    func testAxisTitleNamesAreTheClassNames() {
        for key in AttributeKey.allCases {
            XCTAssertEqual(
                TitleCatalog.displayName(for: .axis(key)),
                BuildClass.specialist(for: key).displayName
            )
        }
    }

    func testCatalogListsRankThenAxisTitlesUniquely() {
        XCTAssertEqual(TitleCatalog.all.count, RankTier.allCases.count + AttributeKey.allCases.count)
        let names = TitleCatalog.all.map { TitleCatalog.displayName(for: $0) }
        XCTAssertEqual(Set(names).count, names.count)
    }
}
