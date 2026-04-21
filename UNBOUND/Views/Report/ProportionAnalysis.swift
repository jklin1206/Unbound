import SwiftUI

struct ProportionAnalysis: View {
    let proportions: ProportionData

    private struct ProportionItem {
        let label: String
        let value: String
        let progress: CGFloat
    }

    private var items: [ProportionItem] {
        var result: [ProportionItem] = []

        if let v = proportions.shoulderToWaistRatio {
            result.append(ProportionItem(
                label: "Shoulder-to-Waist",
                value: String(format: "%.2f", v),
                progress: CGFloat(min(v / 2.0, 1.0))
            ))
        }
        if let v = proportions.chestToWaistRatio {
            result.append(ProportionItem(
                label: "Chest-to-Waist",
                value: String(format: "%.2f", v),
                progress: CGFloat(min(v / 2.0, 1.0))
            ))
        }
        if let v = proportions.armToForearmRatio {
            result.append(ProportionItem(
                label: "Arm-to-Forearm",
                value: String(format: "%.2f", v),
                progress: CGFloat(min(v / 2.0, 1.0))
            ))
        }
        if let v = proportions.upperToLowerBodyBalance {
            let pct = Int(v * 100)
            result.append(ProportionItem(
                label: "Upper/Lower Balance",
                value: "\(pct)%",
                progress: CGFloat(min(v, 1.0))
            ))
        }
        if let v = proportions.leftRightSymmetry {
            let pct = Int(v * 100)
            result.append(ProportionItem(
                label: "Left/Right Symmetry",
                value: "\(pct)%",
                progress: CGFloat(min(v, 1.0))
            ))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Proportions")
                .font(.subheadline())
                .foregroundColor(.theme.textPrimary)

            HStack {
                Spacer()
                ScoreRing(score: proportions.overallProportionScore, maxScore: 100, size: 100)
                Spacer()
            }

            if items.isEmpty {
                Text("No proportion data available.")
                    .font(.caption())
                    .foregroundColor(.theme.textMuted)
            } else {
                VStack(spacing: 12) {
                    ForEach(items, id: \.label) { item in
                        proportionCard(item)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func proportionCard(_ item: ProportionItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.label)
                    .font(.bodyMedium(14))
                    .foregroundColor(.theme.textPrimary)
                Spacer()
                Text(item.value)
                    .font(.stat(14))
                    .foregroundColor(.theme.secondary)
            }
            AnimatedProgressBar(progress: item.progress, color: .theme.secondary)
        }
        .padding(14)
        .background(Color.theme.surfaceLight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
