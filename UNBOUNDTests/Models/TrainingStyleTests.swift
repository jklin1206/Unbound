import XCTest
@testable import UNBOUND

final class TrainingStyleTests: XCTestCase {
    func testShreddedDefaultsToBodyweight() {
        // Shredded (Saitama build) is the bodyweight/calisthenic-coded archetype.
        XCTAssertEqual(TrainingStyle.default(for: .shredded), .bodyweight)
    }

    func testHeavyDutyDefaultsToFreeWeights() {
        // HEAVYWEIGHT / Todo build is about heroic mass — heavy compounds.
        XCTAssertEqual(TrainingStyle.default(for: .heavyDuty), .freeWeights)
    }

    func testVTaperDefaultsToFreeWeights() {
        // V-TAPER / Toji build — compound lifts for wide frame + shoulders.
        XCTAssertEqual(TrainingStyle.default(for: .vTaper), .freeWeights)
    }

    func testLeanCutDefaultsToHybrid() {
        // SHREDDED (raw name leanCut) / Itadori build — athletic mix.
        XCTAssertEqual(TrainingStyle.default(for: .leanCut), .hybrid)
    }

    func testAllStylesHaveDisplayName() {
        for style in TrainingStyle.allCases {
            XCTAssertFalse(style.displayName.isEmpty)
        }
    }

    func testCodableRoundtrip() throws {
        let original: TrainingStyle = .hybrid
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TrainingStyle.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
