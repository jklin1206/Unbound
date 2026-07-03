import SwiftUI
import Charts

// MARK: - Verdict projection — the climb to Unbound
//
// The profile-built reveal ends with where the profile is headed: a 12-month
// rank projection seeded from the user's own commitment + frequency (the same
// curve the old standalone trajectory step drew, folded into the verdict so
// the reveal reads profile → baseline → path). Deliberately light: two
// curves, three axis names, one personalized caption. Axis order follows the
// real ladder — Unbound is the top rank, above Ascendant.

extension Step_Verdict {
    var projectionReveal: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L10n.onboarding("verdict.projection", defaultValue: "THE CLIMB"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text(L10n.onboarding("verdict.projection.window", defaultValue: "12 MO · PROJECTED"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(Color.unbound.accent)
            }

            projectionChart
                .frame(height: 168)

            HStack(spacing: 18) {
                projectionLegendItem(
                    color: Color.unbound.accent,
                    label: L10n.onboarding("verdict.projection.with", defaultValue: "With UNBOUND"),
                    dashed: false
                )
                projectionLegendItem(
                    color: Color.unbound.textTertiary,
                    label: L10n.onboarding("verdict.projection.alone", defaultValue: "On your own"),
                    dashed: true
                )
            }

            Text(L10n.onboardingFormat(
                "verdict.projection.caption",
                defaultValue: "Projected from your %dx/week commitment. Ranks are earned at the gates.",
                sessionsPerWeek
            ))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.unbound.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.50))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle.opacity(0.9), lineWidth: 1)
        )
    }

    private var projectionChart: some View {
        Chart {
            ForEach(projectionAlonePoints) { p in
                LineMark(
                    x: .value("Month", p.month),
                    y: .value("Rank", p.rank),
                    series: .value("Path", "On your own")
                )
                .foregroundStyle(Color.unbound.textTertiary)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 4]))
                .interpolationMethod(.monotone)
            }

            ForEach(projectionWithPoints) { p in
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
                        colors: [Color.unbound.accent.opacity(0.26), Color.unbound.accent.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 5, 7]) { value in
                AxisValueLabel {
                    Text(projectionAxisLabel(for: value.as(Int.self) ?? 0))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            (value.as(Int.self) ?? 0) == 7
                                ? Color.unbound.accent
                                : Color.unbound.textTertiary
                        )
                }
                AxisGridLine()
                    .foregroundStyle(Color.unbound.borderSubtle)
            }
        }
        .chartXAxis {
            AxisMarks(values: [0, 6, 12]) { value in
                AxisValueLabel {
                    Text(L10n.onboardingFormat("verdict.projection.month", defaultValue: "%dmo", value.as(Int.self) ?? 0))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                AxisGridLine()
                    .foregroundStyle(Color.unbound.borderSubtle)
            }
        }
        .chartYScale(domain: 0...7.35)
    }

    private func projectionLegendItem(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 7) {
            if dashed {
                HStack(spacing: 3) {
                    ForEach(0..<4) { _ in
                        Rectangle().fill(color).frame(width: 4, height: 2)
                    }
                }
                .frame(width: 22)
            } else {
                Rectangle().fill(color).frame(width: 22, height: 2)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.unbound.textSecondary)
        }
    }

    // MARK: Data

    struct ProjectionPoint: Identifiable {
        let id = UUID()
        let month: Int
        let rank: Double
    }

    private var projectionWithPoints: [ProjectionPoint] {
        (0...12).map { ProjectionPoint(month: $0, rank: projectedRank(at: $0)) }
    }

    private var projectionAlonePoints: [ProjectionPoint] {
        (0...12).map { month in
            let normalized = Double(month) / 12.0
            let earlyGain = 1 - exp(-normalized * 4.0)
            return ProjectionPoint(month: month, rank: earlyGain * projectionAloneCeiling)
        }
    }

    /// Slow base ramp, sigmoid compounding once logs/recovery/scans stack up,
    /// late breakout past the old ceiling — same shape the trajectory step used.
    private func projectedRank(at month: Int) -> Double {
        let t = Double(month) / 12.0
        let baseRamp = pow(t, 1.55) * 0.42
        let compounding = 1 / (1 + exp(-8.5 * (t - 0.54)))
        let lateBreakout = max(0, t - 0.68) * 1.35
        let raw = (baseRamp + compounding + lateBreakout) / 1.74
        return min(projectionCeiling, raw * projectionCeiling)
    }

    /// With-UNBOUND end state, seeded by commitment + frequency. Reaches past
    /// Unbound's line so the curve visually breaks upward, not asymptotes.
    private var projectionCeiling: Double {
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

    /// On-your-own end state: some early motivation gain, then plateau.
    private var projectionAloneCeiling: Double {
        max(0.65, min(1.55, 0.55 + Double(flow.commitment) / 10.0 * 0.9))
    }

    /// True ladder order (compressed — Vessel omitted for axis brevity):
    /// 0 Initiate … 5 Master, 6 Ascendant, 7 Unbound at the top.
    private func projectionAxisLabel(for value: Int) -> String {
        switch value {
        case 0: return L10n.onboarding("common.rank.initiate", defaultValue: "INITIATE").uppercased()
        case 5: return L10n.onboarding("common.rank.master", defaultValue: "MASTER").uppercased()
        default: return L10n.onboarding("common.rank.unbound", defaultValue: "UNBOUND").uppercased()
        }
    }
}
