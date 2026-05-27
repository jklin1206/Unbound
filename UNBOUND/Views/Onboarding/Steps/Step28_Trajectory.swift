import SwiftUI
import Charts

// MARK: - Step 28: Projected trajectory
//
// Two-line chart showing the user's projected rank progression:
//   - "With UNBOUND"    violet, climbing smoothly over 12 months
//   - "Without"          bone-white dim, essentially flat / plateauing
//
// The visual contrast is the sell: your trajectory IS different with the app.
// Based on the user's commitment + target frequency — more committed users
// see a steeper violet curve, while the flat line stays flat regardless.

struct Step28_Trajectory: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var animatedFraction: CGFloat = 0

    var body: some View {
        OnboardingScaffold(
            title: L10n.onboarding("trajectory.title", defaultValue: "Here's what changes."),
            subtitle: L10n.onboarding("trajectory.subtitle", defaultValue: "One path keeps repeating. One path starts climbing."),
            progress: progress,
            primaryTitle: L10n.onboarding("trajectory.primary", defaultValue: "See my arc"),
            hudStep: .trajectory,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(alignment: .leading, spacing: 16) {
                chartCard
                sellCard
                calloutCard
            }
        }
    }

    // MARK: Chart card

    private var chartCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(L10n.onboarding("trajectory.chart.title", defaultValue: "RANK OVER TIME"))
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Spacer()
                    Text(L10n.onboarding("trajectory.chart.duration", defaultValue: "12 months"))
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                Chart {
                    // Without — dim flat line / gentle rise
                    ForEach(withoutPoints) { p in
                        LineMark(
                            x: .value("Month", p.month),
                            y: .value("Rank", p.rank),
                            series: .value("Path", "Without")
                        )
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 4]))
                        .interpolationMethod(.monotone)
                    }

                    // With UNBOUND — violet climb
                    ForEach(withPoints) { p in
                        LineMark(
                            x: .value("Month", p.month),
                            y: .value("Rank", p.rank),
                            series: .value("Path", "With UNBOUND")
                        )
                        .foregroundStyle(Color.unbound.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Month", p.month),
                            y: .value("Rank", p.rank),
                            series: .value("Path", "With UNBOUND")
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.unbound.accent.opacity(0.28),
                                    Color.unbound.accent.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 1, 2, 3, 4, 5]) { value in
                        AxisValueLabel {
                            Text(axisRankLabel(for: value.as(Int.self) ?? 0))
                                .font(Font.unbound.captionS.monospaced())
                                .foregroundStyle(
                                    (value.as(Int.self) ?? 0) == 5
                                        ? Color.unbound.ember
                                        : Color.unbound.textTertiary
                                )
                        }
                        AxisGridLine()
                            .foregroundStyle(Color.unbound.borderSubtle)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: [0, 3, 6, 9, 12]) { value in
                        AxisValueLabel {
                            Text(L10n.onboardingFormat("trajectory.chart.month", defaultValue: "%dmo", value.as(Int.self) ?? 0))
                                .font(Font.unbound.captionS)
                                .foregroundStyle(Color.unbound.textTertiary)
                        }
                        AxisGridLine()
                            .foregroundStyle(Color.unbound.borderSubtle)
                    }
                }
                .chartYScale(domain: 0...6.0)
                .frame(height: 240)

                legend
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 20) {
            legendItem(color: Color.unbound.accent, label: L10n.onboarding("trajectory.legend.withUnbound", defaultValue: "With UNBOUND"), dashed: false)
            legendItem(color: Color.unbound.textTertiary, label: L10n.onboarding("trajectory.legend.alone", defaultValue: "On your own"), dashed: true)
        }
    }

    private func legendItem(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 8) {
            if dashed {
                HStack(spacing: 3) {
                    ForEach(0..<4) { _ in
                        Rectangle()
                            .fill(color)
                            .frame(width: 4, height: 2)
                    }
                }
                .frame(width: 22)
            } else {
                Rectangle()
                    .fill(color)
                    .frame(width: 22, height: 2)
            }
            Text(label)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
        }
    }

    // MARK: Callout

    private var calloutCard: some View {
        UnboundCard {
            HStack(spacing: 14) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.unbound.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.onboardingFormat("trajectory.projected", defaultValue: "Projected: %@", rankGapText))
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(L10n.onboarding("trajectory.callout.body", defaultValue: "That's a real difference. The plan is yours if you want it."))
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var rankGapText: String {
        let withEnd = rankLabel(for: Int(commitmentSlope.rounded()))
        let withoutEnd = rankLabel(for: Int(withoutSlope.rounded()))
        return L10n.onboardingFormat("trajectory.rankGap", defaultValue: "%@ with UNBOUND vs. %@ without", withEnd, withoutEnd)
    }

    // MARK: Sell card

    /// Most apps treat the top badge as a cap. UNBOUND treats the top tier
    /// as a milestone, not a ceiling. This card is the verbal half of the
    /// uncapped graph.
    private var sellCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.unbound.ember)
                    Text(L10n.onboarding("trajectory.sell.title", defaultValue: "WHY THE ARC KEEPS CLIMBING"))
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.ember)
                }
                Text(L10n.onboarding("trajectory.sell.body", defaultValue: "Most apps stop at a badge. UNBOUND keeps tracking real feats — muscle-up, front lever, one-arm pushup — so progress stays visible after the first big unlock."))
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Data

    private struct Point: Identifiable {
        let id = UUID()
        let month: Int
        let rank: Double
    }

    private var withPoints: [Point] {
        let slope = commitmentSlope
        return (0...12).map { month in
            let normalized = Double(month) / 12.0
            let eased = 1 - pow(1 - normalized, 1.8)
            return Point(month: month, rank: eased * slope)
        }
    }

    private var withoutPoints: [Point] {
        let slope = withoutSlope
        return (0...12).map { month in
            // Linear-ish flat line — you make *some* progress alone but the
            // curve caps out fast (lack of structure, inconsistency).
            let normalized = Double(month) / 12.0
            let value = normalized * slope * 0.55
            return Point(month: month, rank: value)
        }
    }

    /// With-UNBOUND end-state rank. The ceiling is intentionally beyond the
    /// ordinary band so the violet curve keeps climbing through the badge.
    /// Higher commitment + higher target frequency = steeper climb.
    private var commitmentSlope: Double {
        let base = Double(flow.commitment) / 10.0 * 3.6
        let freqBoost: Double = {
            switch flow.targetFrequency {
            case .three: return 0.4
            case .four: return 0.8
            case .five: return 1.2
            case .six: return 1.6
            case nil: return 0.6
            }
        }()
        return min(5.5, base + freqBoost)
    }

    /// Without-UNBOUND end-state. Capped low because grinding alone without
    /// structure plateaus fast regardless of motivation.
    private var withoutSlope: Double {
        max(0.5, min(1.8, Double(flow.commitment) / 10.0 * 1.5))
    }

    private func rankLabel(for value: Int) -> String {
        switch value {
        case 0: return "Initiate"
        case 1: return "Novice"
        case 2: return "Apprentice"
        case 3: return "Forged"
        case 4: return "Veteran"
        case 5: return "Master"
        default: return "Ascendant"
        }
    }

    private func axisRankLabel(for value: Int) -> String {
        switch value {
        case 0: return "INIT"
        case 1: return "NOV"
        case 2: return "APP"
        case 3: return "FORG"
        case 4: return "VET"
        case 5: return "MAS"
        default: return "ASC"
        }
    }
}

#Preview {
    Step28_PreviewHarness()
}

private struct Step28_PreviewHarness: View {
    @State var vm: OnboardingFlowViewModel = {
        let v = OnboardingFlowViewModel()
        v.commitment = 8
        v.targetFrequency = .four
        return v
    }()
    var body: some View {
        Step28_Trajectory(flow: vm, progress: 0.93, onBack: {}, onContinue: {})
    }
}
