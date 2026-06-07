import SwiftUI

struct OperatorReadyStation: Identifiable {
    let index: Int
    let block: TrainingBlock

    var id: String { block.id }
    var laneNumber: Int { index + 1 }
    var laneLabel: String { OperatorText.twoDigit(laneNumber) }

    var prescription: TrainingBlockPrescription? {
        block.prescriptions.first
    }

    var title: String {
        block.title
            .replacingOccurrences(of: "Station \(laneNumber) ", with: "")
            .replacingOccurrences(of: "Lane \(laneNumber) ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var exerciseName: String {
        prescription?.exerciseName ?? title
    }

    var targetText: String {
        guard let prescription else { return "Official lane" }
        return "\(prescription.sets)x \(prescription.displayTargetText)"
    }

    var restText: String {
        guard let seconds = prescription?.restSeconds, seconds > 0 else { return "Reset on command" }
        return "\(OperatorText.mmss(seconds)) reset"
    }

    var movementDefinition: MovementDefinition? {
        guard let prescription else { return nil }
        return MovementCatalog.resolvedTrainingMovement(
            name: prescription.exerciseName,
            movementId: prescription.movementId,
            rankStandardMovementId: prescription.rankStandardMovementId
        )?.exact
    }

    var metricKind: TrainingMetricKind? {
        prescription?.target.metricKind
    }

    var isTimed: Bool {
        switch metricKind {
        case .holdSeconds, .durationSeconds, .distanceMeters, .calories:
            return true
        case .reps, .none:
            return false
        }
    }

    var gaugeValue: Double {
        let base = Double(min(1.0, 0.34 + (Double(index + 1) * 0.13)))
        return isTimed ? min(1.0, base + 0.12) : base
    }

    var fallbackIcon: String {
        OperatorIcon.icon(for: block.kind)
    }
}

struct OperatorReadinessScanner: View {
    let stations: [OperatorReadyStation]
    let tint: Color
    let isLive: Bool

    var body: some View {
        ZStack {
            OperatorScannerShell()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.surface.opacity(0.98),
                            Color.unbound.bg.opacity(0.92),
                            tint.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(OperatorScannerShell().stroke(tint.opacity(0.38), lineWidth: 1.2))

            VStack(spacing: 8) {
                Text("CAL")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(tint)

                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(tint.opacity(index == 0 ? 0.56 : 0.2), lineWidth: index == 0 ? 1.4 : 1)
                            .scaleEffect(0.42 + CGFloat(index) * 0.28)
                    }

                    ForEach(Array(stations.prefix(6).enumerated()), id: \.element.id) { offset, station in
                        Circle()
                            .fill(scannerDotColor(for: station))
                            .frame(width: station.isTimed ? 8 : 6, height: station.isTimed ? 8 : 6)
                            .offset(dotOffset(offset: offset, count: min(stations.count, 6)))
                    }

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, tint.opacity(isLive ? 0.78 : 0.24), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 2, height: 90)
                        .rotationEffect(.degrees(isLive ? 28 : -34))
                        .shadow(color: tint.opacity(isLive ? 0.45 : 0.15), radius: 12)
                }
                .frame(height: 112)

                HStack(spacing: 4) {
                    ForEach(0..<max(1, min(stations.count, 8)), id: \.self) { index in
                        Capsule()
                            .fill(index % 3 == 0 ? Color.rewardTeal.opacity(0.85) : tint.opacity(0.42))
                            .frame(width: index % 3 == 0 ? 14 : 8, height: 3)
                    }
                }
            }
            .padding(.vertical, 14)
        }
    }

    private func scannerDotColor(for station: OperatorReadyStation) -> Color {
        station.isTimed ? Color.unbound.coachCyan : tint
    }

    private func dotOffset(offset: Int, count: Int) -> CGSize {
        let angle = (Double(offset) / Double(max(1, count))) * Double.pi * 2 - Double.pi / 2
        let radius: Double = offset.isMultiple(of: 2) ? 34 : 22
        return CGSize(width: CGFloat(cos(angle) * radius), height: CGFloat(sin(angle) * radius))
    }
}

struct OperatorGaugeStrip: View {
    let stations: [OperatorReadyStation]
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            OperatorReadinessGauge(
                value: readinessScore,
                label: "READINESS",
                tint: tint,
                icon: "scope"
            )
            OperatorReadinessGauge(
                value: timedScore,
                label: "CLOCK",
                tint: Color.unbound.coachCyan,
                icon: "timer"
            )
            OperatorReadinessGauge(
                value: spreadScore,
                label: "LANES",
                tint: Color.rewardTeal,
                icon: "rectangle.split.3x1"
            )
        }
    }

    private var readinessScore: Double {
        guard !stations.isEmpty else { return 0.2 }
        return min(1.0, 0.42 + Double(stations.count) * 0.08)
    }

    private var timedScore: Double {
        guard !stations.isEmpty else { return 0.18 }
        return min(1.0, 0.24 + Double(stations.filter(\.isTimed).count) / Double(stations.count))
    }

    private var spreadScore: Double {
        min(1.0, 0.32 + Double(Set(stations.compactMap(\.metricKind)).count) * 0.18)
    }
}

struct OperatorReadinessGauge: View {
    let value: Double
    let label: String
    let tint: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1)
            }
            .foregroundStyle(tint)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.bg.opacity(0.9))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.72), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * CGFloat(min(max(value, 0), 1))))
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
        )
    }
}

struct OperatorReadyLaneRow: View {
    let station: OperatorReadyStation
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            OperatorLaneBeacon(label: station.laneLabel, tint: station.isTimed ? Color.unbound.coachCyan : tint)
                .frame(width: 42, height: 58)

            if let definition = station.movementDefinition {
                ExerciseVisualView(definition: definition, size: .thumbnail)
                    .frame(width: 56, height: 50)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: station.fallbackIcon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 56, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.unbound.surfaceElevated)
                    )
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(station.title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1)
                    .foregroundStyle(station.isTimed ? Color.unbound.coachCyan : tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(station.exerciseName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("\(station.targetText) / \(station.restText)")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .layoutPriority(1)

            OperatorLaneMicroGauge(value: station.gaugeValue, tint: station.isTimed ? Color.unbound.coachCyan : tint)
                .frame(width: 24, height: 48)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            OperatorLanePlateShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.surface.opacity(0.98),
                            Color.unbound.surfaceElevated.opacity(0.86)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(OperatorLanePlateShape().stroke((station.isTimed ? Color.unbound.coachCyan : tint).opacity(0.26), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

struct OperatorMetricPip: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Font.unbound.monoM.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1)
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(width: 58, height: 48)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tint.opacity(0.28), lineWidth: 1)
        )
    }
}
