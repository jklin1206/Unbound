import XCTest
@testable import UNBOUND

final class SkillBlockRegionTaggerTests: XCTestCase {
    func testPullSkillMapsToPullAndCore() {
        let load = SkillBlockRegionTagger.regionLoad(for: "strict_pull_up")

        XCTAssertEqual(load[.pull], 1.0)
        XCTAssertEqual(load[.core], 0.3)
        XCTAssertEqual(load[.legs], 0)
    }

    func testMultiRegionSkillMapsAcrossRegions() {
        let load = SkillBlockRegionTagger.regionLoad(for: "muscle_up")

        XCTAssertEqual(load[.pull], 1.0)
        XCTAssertEqual(load[.shoulders], 0.5)
        XCTAssertEqual(load[.core], 0.3)
    }

    func testUnknownSkillGetsLowOtherLoad() {
        let load = SkillBlockRegionTagger.regionLoad(for: "anime_balance")

        XCTAssertEqual(load[.other("anime_balance")], 0.5)
    }
}
