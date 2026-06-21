import SwiftUI
import UIKit

extension ProgramRankExerciseDetailView {
    private func summaryTile(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoS.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(cardBackground(cornerRadius: 12, tint: tint.opacity(0.16)))
    }

    func oneRepMaxRail(_ definition: MovementDefinition) -> some View {
        let config = weightRulerConfig(allowsBodyweight: definition.rankTemplate == .weightedBodyweight)
        let tick = Binding<Int>(
            get: { config.tick(for: selectedWeightDisplay) },
            set: { selectedWeightDisplay = config.value(for: $0) }
        )
        let isAddedLoad = definition.rankTemplate == .weightedBodyweight
        let title = isAddedLoad ? "Added 1RM" : "1RM"
        let value = isAddedLoad ? addedLoadSummary : formatDisplayWeight(selectedWeightDisplay)

        return ProgramRankMetricRuler(
            title: title,
            valueText: value,
            range: config.range,
            value: tick,
            format: { config.formatValue($0, using: weightUnit, isAddedLoad: isAddedLoad) },
            tickLabel: { config.tickLabel($0) },
            majorEvery: config.majorEvery,
            tickSpacing: 13
        )
    }

    func repsRail(limit: Int) -> some View {
        ProgramRankMetricRuler(
            title: "Reps",
            valueText: "\(selectedReps)",
            range: 1...limit,
            value: $selectedReps,
            unitLabel: "REPS",
            format: { "\($0)" },
            tickLabel: { "\($0)" },
            majorEvery: limit > 40 ? 10 : 5,
            tickSpacing: 15
        )
    }

    func secondsRail(title: String) -> some View {
        let step = 5
        let maxTick = 1_200 / step
        let tick = Binding<Int>(
            get: { min(max(Int((Double(selectedSeconds) / Double(step)).rounded()), 1), maxTick) },
            set: { selectedSeconds = max(1, min($0, maxTick)) * step }
        )
        let majorEvery = title == "Hold Time" ? 6 : 12

        return ProgramRankMetricRuler(
            title: title,
            valueText: ProgramRankExerciseFormatter.seconds(selectedSeconds),
            range: 1...maxTick,
            value: tick,
            format: { ProgramRankExerciseFormatter.seconds($0 * step) },
            tickLabel: { ProgramRankExerciseFormatter.seconds($0 * step) },
            majorEvery: majorEvery,
            tickSpacing: 12
        )
    }

    var addedLoadSummary: String {
        selectedWeightDisplay > 0 ? "+\(formatDisplayWeight(selectedWeightDisplay))" : "Bodyweight only"
    }

    func detailSection<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Font.unbound.bodyS.weight(.heavy))
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textTertiary)
                    if let subtitle {
                        Text(subtitle)
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardBackground(cornerRadius: CGFloat, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.unbound.surface)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(tint, lineWidth: 1)
        }
    }
}
