import SwiftUI

struct OverallRankTrialReadinessCard: View {
    let readiness: OverallRankTrialReadiness
    let onStart: (OverallRankTrialDefinition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let definition = readiness.definition {
                VStack(alignment: .leading, spacing: 6) {
                    Text(definition.displayName.uppercased())
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("\(readiness.currentRank.displayName.uppercased()) -> \(definition.targetRank.displayName.uppercased())")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(definition.targetRank.rewardTextTint)
                }

                requirementList

                if let attempt = readiness.latestAttempt {
                    attemptRow(attempt)
                }

                if readiness.isReady {
                    Button {
                        onStart(definition)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11, weight: .black))
                            Text(readiness.status == .failed ? "RUN AGAIN" : "START TRIAL")
                                .font(Font.unbound.captionS.weight(.heavy))
                                .tracking(1.4)
                        }
                        .foregroundStyle(Color.unbound.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(definition.targetRank.rewardTextTint))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("overall-rank-trial-start")
                }
            } else {
                Text("CURRENT GATE CLEARED")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.success)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(statusTint.opacity(0.45), lineWidth: 1)
        )
        .accessibilityIdentifier("overall-rank-trial-readiness-card")
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "seal.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(statusTint)
            Text("OVERALL RANK TRIAL")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer(minLength: 0)
            Text(statusLabel)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(statusTint)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(statusTint.opacity(0.14)))
        }
    }

    @ViewBuilder
    private var requirementList: some View {
        let visible = readiness.missingRequirements.isEmpty
            ? Array(readiness.requirements.prefix(3))
            : Array(readiness.missingRequirements.prefix(4))

        VStack(spacing: 8) {
            ForEach(visible) { line in
                HStack(spacing: 10) {
                    Image(systemName: line.isMet ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(line.isMet ? Color.unbound.success : Color.unbound.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.label.uppercased())
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text("\(line.current) / \(line.required)")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.035))
                )
            }
        }
    }

    private func attemptRow(_ attempt: OverallRankTrialAttempt) -> some View {
        HStack(spacing: 8) {
            Image(systemName: attempt.passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(attempt.passed ? Color.unbound.success : Color.unbound.warnOrange)
            Text(attempt.passed ? "PASSED" : "FAILED")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(attempt.passed ? Color.unbound.success : Color.unbound.warnOrange)
            Spacer(minLength: 0)
            Text(attempt.completedAt, style: .date)
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    private var statusLabel: String {
        switch readiness.status {
        case .locked: return "LOCKED"
        case .ready: return "READY"
        case .attempted: return "ATTEMPTED"
        case .passed: return "PASSED"
        case .failed: return "FAILED"
        }
    }

    private var statusTint: Color {
        switch readiness.status {
        case .locked, .attempted:
            return Color.unbound.textTertiary
        case .ready:
            return readiness.targetRank?.rewardTextTint ?? Color.unbound.accent
        case .passed:
            return Color.unbound.success
        case .failed:
            return Color.unbound.warnOrange
        }
    }
}
