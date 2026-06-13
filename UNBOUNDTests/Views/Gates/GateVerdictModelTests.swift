import XCTest
@testable import UNBOUND

final class GateVerdictModelTests: XCTestCase {
    private func result(_ id: String, status: OverallRankTrialStationStatus,
                        total: Int, required: Int, scored: Bool = true) -> OverallRankTrialStationResult {
        .init(id: id, title: id, category: .push, movementId: "m", required: required,
              qualifyingSetsRequired: 1, qualifyingSetsCompleted: status == .passed ? 1 : 0,
              totalValue: total, failedQualityFlags: [], status: status, failureReason: nil, isScored: scored)
    }

    func testPassedAccountsEveryScoredStation() {
        let eval = OverallRankTrialEvaluation(definitionId: "g", passed: true, stationResults: [
            result("a", status: .passed, total: 20, required: 15),
            result("stoke", status: .missing, total: 0, required: 0, scored: false)
        ])
        let model = GateVerdictModel(evaluation: eval, world: GateWorldCatalog.world(for: .firstLight))
        XCTAssertEqual(model.outcome, .passed)
        XCTAssertEqual(model.stationRows.map(\.id), ["a"])   // unscored "stoke" excluded
        XCTAssertTrue(model.standingBetween.isEmpty)
    }

    func testFailedSurfacesNamedTargetsFromFailedScoredStations() {
        let eval = OverallRankTrialEvaluation(definitionId: "g", passed: false, stationResults: [
            result("push", status: .passed, total: 18, required: 18),
            result("pull", status: .failed, total: 2, required: 3)
        ])
        let model = GateVerdictModel(evaluation: eval, world: GateWorldCatalog.world(for: .theForging))
        XCTAssertEqual(model.outcome, .failed)
        XCTAssertEqual(model.standingBetween.count, 1)
        XCTAssertTrue(model.standingBetween[0].contains("pull"))
    }
}
