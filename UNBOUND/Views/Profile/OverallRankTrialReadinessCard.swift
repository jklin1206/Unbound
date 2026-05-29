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
                    Text("\(readiness.currentRank.displayName.uppercased()) -> \(definition.targetRank.displayName.uppercased()) RANK GATE")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(definition.targetRank.rewardTextTint)
                    Text(readiness.isReady ? "Qualified." : "Finish the missing proofs.")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                trialSummary

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
            Text("TRIAL QUALIFICATION")
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
    private var trialSummary: some View {
        if let resolved = readiness.resolvedTrial {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "scope")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(statusTint)
                    Text(resolved.selectedLoadout.displayName.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Spacer(minLength: 0)
                    Text("\(resolved.stations.count) STATIONS")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(statusTint)
                }

                Text(categorySummary(resolved))
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(readiness.blockerSummary ?? resolved.nextPrepAction)
                    .font(Font.unbound.captionS.weight(.semibold))
                    .foregroundStyle(readiness.blockerSummary == nil ? Color.unbound.textPrimary : Color.unbound.warnOrange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(statusTint.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(statusTint.opacity(0.18), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var requirementList: some View {
        let metCount = readiness.requirements.filter(\.isMet).count
        let ordered = readiness.requirements.sorted { lhs, rhs in
            if lhs.isMet != rhs.isMet { return !lhs.isMet && rhs.isMet }
            return lhs.label < rhs.label
        }

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("QUALIFICATIONS")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer(minLength: 0)
                Text("\(metCount)/\(readiness.requirements.count)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(statusTint)
            }

            ForEach(ordered) { line in
                HStack(spacing: 10) {
                    Image(systemName: line.isMet ? "checkmark.circle.fill" : requirementIcon(for: line.kind))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(line.isMet ? Color.unbound.success : statusTint.opacity(0.78))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.label.uppercased())
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text(requirementProgressText(line))
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(line.isMet ? Color.white.opacity(0.028) : statusTint.opacity(0.09))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(line.isMet ? Color.clear : statusTint.opacity(0.22), lineWidth: 1)
                )
            }
        }
    }

    private func categorySummary(_ resolved: ResolvedRankTrial) -> String {
        resolved.categoriesTested.map(\.displayName).joined(separator: " / ")
    }

    private func requirementIcon(for kind: OverallRankTrialRequirementKind) -> String {
        switch kind {
        case .overallLevel: return "chart.line.uptrend.xyaxis"
        case .rank: return "seal.fill"
        case .equipment: return "backpack.fill"
        }
    }

    private func requirementProgressText(_ line: OverallRankTrialRequirementLine) -> String {
        let current = line.current.isEmpty ? "None set" : line.current
        let required = line.required.isEmpty ? "None required" : line.required
        return "Current: \(current)  •  Required: \(required)"
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
