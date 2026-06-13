import Foundation

/// Pure accounting derivation for `GateVerdictView` (spec §6.6/§6.7). Pass and
/// fail both account every scored station (your numbers vs floors); fail turns
/// failed scored stations into named training targets. Unscored stations
/// (e.g. Gate III "Stoke the Fire") are excluded.
struct GateVerdictModel: Equatable {
    enum Outcome: Equatable { case passed, failed }
    struct StationRow: Identifiable, Equatable {
        let id: String; let title: String; let yours: String; let floor: String; let passed: Bool
    }

    let outcome: Outcome
    let stationRows: [StationRow]
    let standingBetween: [String]   // fail only: named training targets

    init(evaluation: OverallRankTrialEvaluation, world: GateWorld) {
        outcome = evaluation.passed ? .passed : .failed
        let scored = evaluation.stationResults.filter(\.isScored)
        stationRows = scored.map {
            .init(id: $0.id, title: $0.title, yours: "\($0.totalValue)",
                  floor: "\($0.required)", passed: $0.status == .passed)
        }
        standingBetween = evaluation.passed ? [] : scored
            .filter { $0.status != .passed }
            .map { "\($0.title): \($0.totalValue) of \($0.required)" }
    }
}
