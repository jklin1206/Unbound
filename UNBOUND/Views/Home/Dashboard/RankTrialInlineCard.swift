import SwiftUI

// MARK: - RankTrialInlineCard
//
// The rank-gate trial as a card on the Home feed (in the Trials band), parallel
// to the active vow card. Shows the target trial + how close the gate is, with
// an ENTER button when ready. Tapping the card opens the full requirement
// details (RankInfoSheet) — the checklist lives there, not inline.

struct RankTrialInlineCard: View {
    let readiness: OverallRankTrialReadiness
    /// Short status token (READY / RETRY / "2/3"), from the Home command logic.
    let statusText: String
    let tint: Color
    let onEnter: () -> Void
    let onDetails: () -> Void

    private var trialTitle: String {
        "\(readiness.targetRank?.displayName ?? "Rank") Trial"
    }

    private var proofLine: String {
        let met = readiness.requirements.filter(\.isMet).count
        let total = max(1, readiness.requirements.count)
        if readiness.isReady { return "All proofs met" }
        let left = max(0, total - met)
        let noun = left == 1 ? "proof" : "proofs"
        return "\(left) \(noun) left"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
                .contentShape(Rectangle())
                .onTapGesture(perform: onDetails)

            if readiness.isReady {
                enterButton
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumGlassCard(cornerRadius: 20, tint: tint)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rank trial")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "key.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 54, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.12))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("RANK TRIAL")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                    Text(statusText)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                }

                Text(trialTitle)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(proofLine)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    private var enterButton: some View {
        Button(action: onEnter) {
            HStack(spacing: 8) {
                Text("ENTER TRIAL")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(Color.unbound.bg)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Enter the \(trialTitle)")
    }
}
