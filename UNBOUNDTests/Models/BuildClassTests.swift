import XCTest
@testable import UNBOUND

final class BuildClassTests: XCTestCase {

    // MARK: - Shape → class mapping

    func testBalancedAthleteIsParagon() {
        let identity = BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete)
        XCTAssertEqual(identity.buildClass, .paragon)
        XCTAssertFalse(identity.isClassPath)
    }

    func testHybridAthleteIsVagabond() {
        let identity = BuildIdentity(primary: nil, secondary: nil, shape: .hybridAthlete)
        XCTAssertEqual(identity.buildClass, .vagabond)
    }

    func testEverySpecialistAxisMapsToADistinctClass() {
        let classes = AttributeKey.allCases.map { BuildClass.specialist(for: $0) }
        XCTAssertEqual(Set(classes).count, AttributeKey.allCases.count)
    }

    func testEveryHybridPairMapsToADistinctSymmetricClass() {
        var seen: Set<BuildClass> = []
        let axes = AttributeKey.allCases
        for i in axes.indices {
            for j in axes.indices where j > i {
                let forward = BuildClass.hybrid(axes[i], axes[j])
                let reverse = BuildClass.hybrid(axes[j], axes[i])
                XCTAssertEqual(forward, reverse, "hybrid(\(axes[i]), \(axes[j])) not symmetric")
                XCTAssertFalse(seen.contains(forward), "\(forward) reused across pairs")
                seen.insert(forward)
                // Hybrid classes never collide with shape or specialist classes.
                XCTAssertNotEqual(forward, .paragon)
                XCTAssertNotEqual(forward, .vagabond)
                for axis in axes {
                    XCTAssertNotEqual(forward, BuildClass.specialist(for: axis))
                }
            }
        }
        XCTAssertEqual(seen.count, 15)
    }

    func testLeanReadsAsPathOfTheSpecialistClass() {
        let identity = BuildIdentity(primary: .control, secondary: nil, shape: .lean)
        XCTAssertEqual(identity.buildClass, .monk)
        XCTAssertTrue(identity.isClassPath)
        XCTAssertEqual(identity.classDisplayName, "Path of the Monk")
    }

    func testSpecialistDisplayNameHasNoPathPrefix() {
        let identity = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        XCTAssertEqual(identity.classDisplayName, "Titan")
    }

    func testHybridDisplayName() {
        let identity = BuildIdentity(primary: .power, secondary: .control, shape: .hybrid)
        XCTAssertEqual(identity.classDisplayName, "Sword Saint")
    }

    // MARK: - Hold-window hysteresis

    private var defaults: UserDefaults!
    private var store: BuildClassStore!
    private let userId = "build-class-tests"

    private let titanIdentity = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
    private let monkIdentity = BuildIdentity(primary: .control, secondary: nil, shape: .specialist)
    private let paragonIdentity = BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete)

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "BuildClassTests")
        defaults.removePersistentDomain(forName: "BuildClassTests")
        store = BuildClassStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "BuildClassTests")
        super.tearDown()
    }

    private func days(_ n: Double, after date: Date) -> Date {
        date.addingTimeInterval(n * 24 * 60 * 60)
    }

    func testHeldIdentityFallsBackToLiveBeforeFirstObservation() {
        XCTAssertEqual(store.heldIdentity(userId: userId, live: titanIdentity), titanIdentity)
    }

    func testFirstObservationBootstrapsHold() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        store.observe(titanIdentity, userId: userId, at: start)
        XCTAssertEqual(store.heldIdentity(userId: userId, live: monkIdentity), titanIdentity)
    }

    func testDifferentReadingInsideWindowDoesNotChangeHold() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        store.observe(titanIdentity, userId: userId, at: start)
        store.observe(monkIdentity, userId: userId, at: days(1, after: start))
        store.observe(monkIdentity, userId: userId, at: days(10, after: start))
        XCTAssertEqual(store.heldIdentity(userId: userId, live: monkIdentity), titanIdentity)
    }

    func testDifferentReadingHeldPastWindowPromotes() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        store.observe(titanIdentity, userId: userId, at: start)
        store.observe(monkIdentity, userId: userId, at: days(1, after: start))
        store.observe(monkIdentity, userId: userId, at: days(1 + 22, after: start))
        XCTAssertEqual(store.heldIdentity(userId: userId, live: monkIdentity), monkIdentity)
    }

    func testDipBackToHeldResetsCandidateClock() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        store.observe(titanIdentity, userId: userId, at: start)
        store.observe(monkIdentity, userId: userId, at: days(1, after: start))
        // A reading back at the held identity clears the candidate…
        store.observe(titanIdentity, userId: userId, at: days(10, after: start))
        // …so a later return to the candidate starts a fresh clock.
        store.observe(monkIdentity, userId: userId, at: days(20, after: start))
        store.observe(monkIdentity, userId: userId, at: days(30, after: start))
        XCTAssertEqual(store.heldIdentity(userId: userId, live: monkIdentity), titanIdentity)
    }

    func testFlipToThirdShapeResetsCandidateClock() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        store.observe(titanIdentity, userId: userId, at: start)
        store.observe(monkIdentity, userId: userId, at: days(1, after: start))
        store.observe(paragonIdentity, userId: userId, at: days(10, after: start))
        store.observe(monkIdentity, userId: userId, at: days(20, after: start))
        // Only ~10 days on the fresh monk clock — held stays titan.
        store.observe(monkIdentity, userId: userId, at: days(30, after: start))
        XCTAssertEqual(store.heldIdentity(userId: userId, live: monkIdentity), titanIdentity)
    }

    func testPromotionIsStickyAfterwards() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        store.observe(titanIdentity, userId: userId, at: start)
        store.observe(monkIdentity, userId: userId, at: days(1, after: start))
        store.observe(monkIdentity, userId: userId, at: days(25, after: start))
        // Now held = monk; a single titan reading must not flip it back.
        store.observe(titanIdentity, userId: userId, at: days(26, after: start))
        XCTAssertEqual(store.heldIdentity(userId: userId, live: titanIdentity), monkIdentity)
    }
}
