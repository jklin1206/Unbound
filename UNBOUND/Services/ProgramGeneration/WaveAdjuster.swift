import Foundation

struct WaveAdjustment: Identifiable, Hashable, Sendable {
    var id: String
    var dayNumber: Int
    var category: ProgramRationale.ReasonCategory
    var regionScope: ProgramBodyRegion?
    var reason: ProgramRationale.Decision
}

struct WaveAdjustmentResult {
    var program: TrainingProgram
    var adjustments: [WaveAdjustment]
    var didApply: Bool
}

enum WaveAdjuster {
    static func applyIfNeeded(
        program: TrainingProgram,
        asOf date: Date = Date(),
        appliedAdjustmentIDs: Set<String> = [],
        calendar: Calendar = .current
    ) -> WaveAdjustmentResult {
        guard let arc = program.currentArc,
              let dayNumber = arc.dayNumber(asOf: date, calendar: calendar),
              dayNumber >= Arc.waveLengthDays + 1
        else {
            return WaveAdjustmentResult(program: program, adjustments: [], didApply: false)
        }

        let adjustmentID = "\(arc.id):wave2:start"
        guard !appliedAdjustmentIDs.contains(adjustmentID) else {
            return WaveAdjustmentResult(program: program, adjustments: [], didApply: false)
        }

        var adjustments: [WaveAdjustment] = []
        for day in program.days where !day.isRestDay && day.savedWorkoutId == nil {
            guard let workout = day.workout else { continue }
            let load = RegionFatigueBudget.regionLoad(for: workout)
            guard let primary = load.loads.max(by: { $0.value < $1.value })?.key else { continue }
            let reason = ProgramRationale.Decision(
                category: .loadRaised,
                regionScope: primary,
                inputSummary: "Wave 2 starts on Arc day \(dayNumber). \(day.label) is still engine-owned.",
                revertible: true
            )
            let adjustment = WaveAdjustment(
                id: "\(adjustmentID):\(day.dayNumber)",
                dayNumber: day.dayNumber,
                category: .loadRaised,
                regionScope: primary,
                reason: reason
            )
            if !appliedAdjustmentIDs.contains(adjustment.id) {
                adjustments.append(adjustment)
            }
        }

        return WaveAdjustmentResult(
            program: program,
            adjustments: adjustments,
            didApply: !adjustments.isEmpty
        )
    }

    static func revert(
        adjustmentID: String,
        in appliedAdjustmentIDs: Set<String>
    ) -> Set<String> {
        var updated = appliedAdjustmentIDs
        updated.remove(adjustmentID)
        return updated
    }
}
