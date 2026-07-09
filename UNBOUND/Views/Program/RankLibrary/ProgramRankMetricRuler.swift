import SwiftUI
import UIKit

struct ProgramRankMetricRuler: View {
    let title: String
    let valueText: String
    let range: ClosedRange<Int>
    @Binding var value: Int
    var unitLabel: String = ""
    var format: (Int) -> String
    var tickLabel: (Int) -> String
    var majorEvery: Int
    var tickSpacing: CGFloat = 14
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(Font.unbound.bodyS.weight(.heavy))
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer(minLength: 8)
                Text(valueText)
                    .font(Font.unbound.bodyS.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .monospacedDigit()
            }

            RulerPicker(
                range: range,
                value: $value,
                unitLabel: unitLabel,
                format: format,
                tickLabel: tickLabel,
                majorEvery: majorEvery,
                tickSpacing: tickSpacing
            )

            if let caption {
                Text(caption)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ProgramRankWeightRulerConfig {
    let start: Double
    let end: Double
    let step: Double
    let majorDisplayIncrement: Double

    var range: ClosedRange<Int> {
        0...max(0, Int(((end - start) / step).rounded()))
    }

    var majorEvery: Int {
        max(1, Int((majorDisplayIncrement / step).rounded()))
    }

    func tick(for value: Double) -> Int {
        let rawTick = Int(((value - start) / step).rounded())
        return min(max(rawTick, range.lowerBound), range.upperBound)
    }

    func value(for tick: Int) -> Double {
        let clamped = min(max(tick, range.lowerBound), range.upperBound)
        let rawValue = start + Double(clamped) * step
        return (rawValue * 100).rounded() / 100
    }

    func formatValue(
        _ tick: Int,
        using unit: TrainingWeightUnit,
        isAddedLoad: Bool
    ) -> String {
        let displayValue = value(for: tick)
        if isAddedLoad, displayValue <= 0 {
            return "BW"
        }
        let prefix = isAddedLoad && displayValue > 0 ? "+" : ""
        return "\(prefix)\(WeightPlatePolicy.formatDisplayValue(displayValue))\(unit.shortLabel)"
    }

    func tickLabel(_ tick: Int) -> String {
        let displayValue = value(for: tick)
        if displayValue <= 0 { return "BW" }
        return WeightPlatePolicy.formatDisplayValue(displayValue)
    }
}
