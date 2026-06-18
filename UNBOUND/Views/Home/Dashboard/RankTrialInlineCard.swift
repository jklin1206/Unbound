import SwiftUI

// MARK: - Home Trials chrome
//
// Supporting rows for the Home Trials section. The rank gate itself is the
// immersive NextGateCard "world" card (placed directly on Home — ENTER drops
// you into the trial, no detail-sheet repeat). These are the bits around it:
// the Trial Records entry that opens the full 8-gate list, and the locked state
// shown when there's no gate available yet.

struct HomeTrialRecordsRow: View {
    let passedGates: Int
    let totalGates: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "rosette")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.unbound.rankGold)
                Text("TRIAL RECORDS")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer(minLength: 0)
                Text("\(passedGates)/\(totalGates) GATES")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Trial records, \(passedGates) of \(totalGates) gates")
    }
}

struct HomeRankGateLockedRow: View {
    let detail: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.unbound.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("RANK TRIAL")
                        .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(detail)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rank trial, \(detail)")
    }
}
