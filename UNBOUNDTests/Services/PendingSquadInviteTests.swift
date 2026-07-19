// UNBOUNDTests/Services/PendingSquadInviteTests.swift
import XCTest
@testable import UNBOUND

final class PendingSquadInviteTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: PendingSquadInvite!

    // A fixed wall-clock anchor so TTL math is deterministic (no Date() drift).
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        suiteName = "PendingSquadInviteTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = PendingSquadInvite(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Store: persist

    func testSaveAndReadRoundtrip() {
        store.save(code: "ABC123", now: t0)
        XCTAssertEqual(store.pendingCode(now: t0), "ABC123")
    }

    func testEmptyWhenNothingSaved() {
        XCTAssertNil(store.pendingCode(now: t0))
    }

    func testSaveNormalizesToJoinCodeShape() {
        // Lowercase, non-alphanumeric, and >6 chars all normalize away.
        store.save(code: "ab-c1 2x9", now: t0)
        XCTAssertEqual(store.pendingCode(now: t0), "ABC12X")
    }

    func testNonCodeInputIsIgnored() {
        store.save(code: "   ", now: t0)
        XCTAssertNil(store.pendingCode(now: t0))
        store.save(code: "!!!", now: t0)
        XCTAssertNil(store.pendingCode(now: t0))
    }

    // MARK: - Store: TTL expiry

    func testWithinTTLReturnsCode() {
        store.save(code: "ABC123", now: t0)
        // Exactly at the TTL boundary still counts as fresh.
        let atBoundary = t0.addingTimeInterval(PendingSquadInvite.timeToLive)
        XCTAssertEqual(store.pendingCode(now: atBoundary), "ABC123")
    }

    func testExpiredReturnsNil() {
        store.save(code: "ABC123", now: t0)
        let pastTTL = t0.addingTimeInterval(PendingSquadInvite.timeToLive + 1)
        XCTAssertNil(store.pendingCode(now: pastTTL))
    }

    func testExpiredEntryIsClearedOnRead() {
        store.save(code: "ABC123", now: t0)
        // A stale read past the TTL must purge the entry so it can't resurface
        // even if a later read happens to fall back inside the original window.
        _ = store.pendingCode(now: t0.addingTimeInterval(PendingSquadInvite.timeToLive + 1))
        XCTAssertNil(store.pendingCode(now: t0))
    }

    // MARK: - Store: clear-on-consume

    func testClearRemovesPending() {
        store.save(code: "ABC123", now: t0)
        store.clear()
        XCTAssertNil(store.pendingCode(now: t0))
    }

    // MARK: - Store: overwrite-with-newer

    func testNewerSaveOverwritesOlder() {
        store.save(code: "AAAAAA", now: t0)
        let later = t0.addingTimeInterval(60)
        store.save(code: "BBBBBB", now: later)
        XCTAssertEqual(store.pendingCode(now: later), "BBBBBB")
    }

    func testNewerSaveResetsTTLWindow() {
        store.save(code: "AAAAAA", now: t0)
        // Re-tapping a fresh link late in the first window restarts the clock,
        // so the invite is actionable for a full TTL from the newer tap.
        let later = t0.addingTimeInterval(PendingSquadInvite.timeToLive - 10)
        store.save(code: "BBBBBB", now: later)
        let wellAfterFirstWindow = t0.addingTimeInterval(PendingSquadInvite.timeToLive + 100)
        XCTAssertEqual(store.pendingCode(now: wellAfterFirstWindow), "BBBBBB")
    }

    // MARK: - Parser: valid links

    func testParsesValidLink() {
        XCTAssertEqual(code("https://unboundbtr.com/squad/ABC123"), "ABC123")
    }

    func testHostCaseInsensitive() {
        XCTAssertEqual(code("https://UNBOUNDBTR.COM/squad/ABC123"), "ABC123")
    }

    func testWwwPrefixAccepted() {
        XCTAssertEqual(code("https://www.unboundbtr.com/squad/ABC123"), "ABC123")
    }

    func testSquadSegmentCaseInsensitive() {
        XCTAssertEqual(code("https://unboundbtr.com/Squad/ABC123"), "ABC123")
        XCTAssertEqual(code("https://unboundbtr.com/SQUAD/ABC123"), "ABC123")
    }

    func testLowercaseCodeNormalizedToUppercase() {
        XCTAssertEqual(code("https://unboundbtr.com/squad/abc123"), "ABC123")
    }

    func testOverlongCodeTruncatedToSix() {
        // Mirrors JoinSquadSheet's 6-char cap.
        XCTAssertEqual(code("https://unboundbtr.com/squad/ABCDEFGH"), "ABCDEF")
    }

    func testTrailingSlashTolerated() {
        // A trailing slash is the same link, not an extra path component.
        XCTAssertEqual(code("https://unboundbtr.com/squad/ABC123/"), "ABC123")
    }

    // MARK: - Parser: rejections

    func testWrongHostRejected() {
        XCTAssertNil(code("https://evil.com/squad/ABC123"))
        XCTAssertNil(code("https://notunboundbtr.com/squad/ABC123"))
        // A lookalike subdomain that isn't the bare host or www. is rejected.
        XCTAssertNil(code("https://unboundbtr.com.evil.com/squad/ABC123"))
        XCTAssertNil(code("https://app.unboundbtr.com/squad/ABC123"))
    }

    func testExtraPathComponentsRejected() {
        XCTAssertNil(code("https://unboundbtr.com/squad/ABC123/extra"))
        XCTAssertNil(code("https://unboundbtr.com/squad/ABC123/extra/more"))
    }

    func testMissingCodeRejected() {
        XCTAssertNil(code("https://unboundbtr.com/squad/"))
        XCTAssertNil(code("https://unboundbtr.com/squad"))
    }

    func testNonSquadPathRejected() {
        XCTAssertNil(code("https://unboundbtr.com/team/ABC123"))
        XCTAssertNil(code("https://unboundbtr.com/"))
    }

    func testCodeThatNormalizesToEmptyRejected() {
        XCTAssertNil(code("https://unboundbtr.com/squad/%20%20"))
        XCTAssertNil(code("https://unboundbtr.com/squad/---"))
    }

    func testNonWebSchemeWithoutHostRejected() {
        XCTAssertNil(code("unbound:squad/ABC123"))
    }

    // MARK: - Helpers

    private func code(_ string: String) -> String? {
        guard let url = URL(string: string) else {
            XCTFail("Could not build URL from \(string)")
            return nil
        }
        return SquadInviteLink.inviteCode(from: url)
    }
}
