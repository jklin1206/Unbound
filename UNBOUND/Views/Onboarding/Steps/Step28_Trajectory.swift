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
            title: L10n.onboarding("trajectory.title", defaultValue: "The path bends upward."),
            subtitle: L10n.onboarding("trajectory.subtitle", defaultValue: "Progress is slow until consistency starts compounding. Then the climb stops looking linear."),
            progress: progress,
            primaryTitle: L10n.onboarding("trajectory.primary", defaultValue: "Show me proof"),
            hudStep: .trajectory,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(alignment: .leading, spacing: 12) {
                chartCard
                sellCard
                calloutCard
            }
        }
    }

    // MARK: Chart card

    private var chartCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L10n.onboarding("trajectory.chart.title", defaultValue: "RANK OVER TIME"))
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Spacer()
                    Text(L10n.onboarding("trajectory.chart.duration", defaultValue: "12 months · projected"))
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
                    AxisMarks(values: [0, 1, 2, 3, 4, 5, 6, 7]) { value in
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
                .chartYScale(domain: 0...7.35)
                .frame(height: 204)

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
                    Text(L10n.onboarding("trajectory.callout.body", defaultValue: "The first months build the base. The later months show the gap."))
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var rankGapText: String {
        let withEnd = rankLabel(for: Int(commitmentCeiling.rounded()))
        let withoutEnd = rankLabel(for: Int(withoutCeiling.rounded()))
        return L10n.onboardingFormat("trajectory.rankGap", defaultValue: "%@ with UNBOUND vs. %@ without", withEnd, withoutEnd)
    }

    // MARK: Sell card

    /// Most apps treat the top badge as a cap. UNBOUND treats the top tier
    /// as a milestone, not a ceiling. This card is the verbal half of the
    /// uncapped graph.
    private var sellCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.unbound.ember)
                    Text(L10n.onboarding("trajectory.sell.title", defaultValue: "WHY IT SHOOTS UP LATER"))
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.ember)
                }
                Text(L10n.onboarding("trajectory.sell.body", defaultValue: "Early sessions teach the system your baseline. Once your logs, recovery, and scans stack up, the targets get sharper and rank movement accelerates."))
                    .font(Font.unbound.bodyS)
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
        return (0...12).map { month in
            Point(month: month, rank: projectedRank(at: month))
        }
    }

    private var withoutPoints: [Point] {
        return (0...12).map { month in
            let normalized = Double(month) / 12.0
            let earlyGain = 1 - exp(-normalized * 4.0)
            let value = earlyGain * withoutCeiling
            return Point(month: month, rank: value)
        }
    }

    private func projectedRank(at month: Int) -> Double {
        let t = Double(month) / 12.0
        let baseRamp = pow(t, 1.55) * 0.42
        let compounding = 1 / (1 + exp(-8.5 * (t - 0.54)))
        let lateBreakout = max(0, t - 0.68) * 1.35
        let raw = (baseRamp + compounding + lateBreakout) / 1.74
        return min(commitmentCeiling, raw * commitmentCeiling)
    }

    /// With-UNBOUND end-state rank. The ceiling intentionally reaches beyond
    /// Master so the curve can visually break upward after consistency compounds.
    private var commitmentCeiling: Double {
        let base = 4.95 + Double(flow.commitment) / 10.0 * 1.35
        let freqBoost: Double = {
            switch flow.targetFrequency {
            case .three: return 0.25
            case .four: return 0.55
            case .five: return 0.82
            case .six: return 1.05
            case nil: return 0.45
            }
        }()
        return min(7.25, base + freqBoost)
    }

    /// Without-UNBOUND end-state. Some early motivation gain, then plateau.
    private var withoutCeiling: Double {
        max(0.65, min(1.55, 0.55 + Double(flow.commitment) / 10.0 * 0.9))
    }

    private func rankLabel(for value: Int) -> String {
        switch value {
        case 0: return "Initiate"
        case 1: return "Novice"
        case 2: return "Apprentice"
        case 3: return "Forged"
        case 4: return "Veteran"
        case 5: return "Master"
        case 6: return "Unbound"
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
        case 6: return "UNB"
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
