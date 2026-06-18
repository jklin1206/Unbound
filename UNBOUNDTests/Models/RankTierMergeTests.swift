import XCTest
@testable import UNBOUND

// Phase 1 of the rank-vocabulary consolidation: RankTitle (String) + SkillTier
// (Int) merged into one `RankTier`. These tests lock the tolerant Codable so no
// on-disk migration is needed — legacy Int blobs (skill tiers, cosmetic highest)
// AND legacy String blobs (trial progress, incl. "honed") must still decode.

final class RankTierMergeTests: XCTestCase {

    private let dec = JSONDecoder()
    private let enc = JSONEncoder()

    // MARK: Aliases are the same type

    func testAliasesAreTheSameType() {
        XCTAssertTrue(SkillTier.self == RankTier.self)
        XCTAssertTrue(RankTitle.self == RankTier.self)
        XCTAssertEqual(SkillTier.veteran, RankTitle.veteran)
        XCTAssertEqual(RankTier.veteran.rawValue, 4)
        XCTAssertEqual(RankTier.veteran.ordinal, 5)   // 1-based, former RankTitle.ordinal
    }

    // MARK: Decode legacy forms

    func testDecodesLegacyIntForm() throws {
        // Former SkillTier persisted as Int (perSkill, cosmetic highest).
        // Positions are stable across the 2026-06 crown rename: 7 = Ascendant,
        // 8 = Unbound (the peak).
        XCTAssertEqual(try dec.decode(RankTier.self, from: Data("4".utf8)), .veteran)
        XCTAssertEqual(try dec.decode(RankTier.self, from: Data("0".utf8)), .initiate)
        XCTAssertEqual(try dec.decode(RankTier.self, from: Data("7".utf8)), .ascendant)
        XCTAssertEqual(try dec.decode(RankTier.self, from: Data("8".utf8)), .unbound)
    }

    func testDecodesLegacyStringForm() throws {
        // Former RankTitle persisted as the case-name String (trial progress).
        XCTAssertEqual(try dec.decode(RankTier.self, from: Data("\"veteran\"".utf8)), .veteran)
    }

    func testLegacyCrownTokensKeepTheirOldMeanings() throws {
        // Stored crown tokens predate the 2026-06 rename: "ascendant" was the
        // PEAK (now .unbound) and "unbound" was tier 7 (now .ascendant). A
        // legacy peak save must NOT demote, and a legacy tier-7 save must NOT
        // get promoted.
        XCTAssertEqual(try dec.decode(RankTier.self, from: Data("\"ascendant\"".utf8)), .unbound)
        XCTAssertEqual(try dec.decode(RankTier.self, from: Data("\"unbound\"".utf8)), .ascendant)
        XCTAssertEqual(RankTier.fromLegacyToken("ascendant"), .unbound)
        XCTAssertEqual(RankTier.fromLegacyToken("unbound"), .ascendant)
    }

    func testCrownCaseNamesMatchDisplayNames() {
        // The point of the rename: case name, token, and display name agree.
        XCTAssertEqual(RankTier.unbound.rawValue, 8)
        XCTAssertEqual(RankTier.unbound.displayName, "Unbound")
        XCTAssertEqual(RankTier.unbound.token, "unbound")
        XCTAssertEqual(RankTier.ascendant.rawValue, 7)
        XCTAssertEqual(RankTier.ascendant.displayName, "Ascendant")
        XCTAssertEqual(RankTier.ascendant.token, "ascendant")
    }

    func testDecodesHonedAlias() throws {
        // Historical "honed" → Master.
        XCTAssertEqual(try dec.decode(RankTier.self, from: Data("\"honed\"".utf8)), .master)
    }

    func testDecodesLegacyLetterFallback() {
        XCTAssertEqual(RankTier.fromLegacyToken("B"), .master)
        XCTAssertEqual(RankTier.fromLegacyToken("S"), .unbound)    // S = peak
        XCTAssertEqual(RankTier.fromLegacyToken("A"), .ascendant)  // A = tier 7
        XCTAssertEqual(RankTier.fromLegacyToken("E"), .initiate)
    }

    func testUnknownStringFallsBackToInitiate() throws {
        XCTAssertEqual(try dec.decode(RankTier.self, from: Data("\"garbage\"".utf8)), .initiate)
    }

    // MARK: Encode is the stable Int rawValue; round-trips

    func testEncodesRawValueAndRoundTrips() throws {
        // Int positions are rename-proof (the String form is legacy-only, with
        // inverted crown meanings — encoding tokens again would corrupt crowns).
        for tier in RankTier.allCases {
            let data = try enc.encode(tier)
            XCTAssertEqual(String(data: data, encoding: .utf8), "\(tier.rawValue)")
            XCTAssertEqual(try dec.decode(RankTier.self, from: data), tier)
        }
    }

    // MARK: Real persisted shapes

    /// A struct field typed `RankTitle` (e.g. OverallRankTrialProgress.highestPassedRank)
    /// must decode from old String JSON and re-encode stably.
    func testStructFieldRoundTripsFromLegacyString() throws {
        struct Holder: Codable, Equatable { var rank: RankTitle }
        let fromOld = try dec.decode(Holder.self, from: Data("{\"rank\":\"vessel\"}".utf8))
        XCTAssertEqual(fromOld.rank, .vessel)
        let reEncoded = try dec.decode(Holder.self, from: enc.encode(fromOld))
        XCTAssertEqual(reEncoded, fromOld)
    }

    /// A `[String: SkillTier]` (UserSkillTierState.perSkill) must decode from old
    /// Int JSON.
    func testPerSkillDictDecodesFromLegacyInts() throws {
        let map = try dec.decode([String: SkillTier].self, from: Data("{\"pp.pullup\":4,\"cal.pushup\":2}".utf8))
        XCTAssertEqual(map["pp.pullup"], .veteran)
        XCTAssertEqual(map["cal.pushup"], .apprentice)
    }

    // MARK: Math + asset stability

    func testComparableAndRawMathIntact() {
        XCTAssertTrue(RankTier.novice < RankTier.master)
        XCTAssertEqual([RankTier.forged, .unbound, .initiate].max(), .unbound)
        XCTAssertEqual(RankTier.master.rawValue - RankTier.novice.rawValue, 4)
    }

    func testAssetNamesStable() {
        XCTAssertEqual(RankTier.veteran.assetName, "rank_title_veteran")
        // Post-rename: the peak's assets live under the *_unbound names (the
        // gold art was moved into those files in the same commit).
        XCTAssertEqual(RankTier.unbound.assetName, "rank_title_unbound")
        XCTAssertEqual(RankTier.ascendant.token, "ascendant")
    }
}
