import SwiftUI

// MARK: - ActiveTrialCard
//
// Shows the current active trial in the Home contextualStack. Displays:
//   - Trial theme tag + kind badge
//   - Trial display name
//   - Capstone progress bar (0-1 fraction)
//   - Capstone state (pending / window open / completed)

struct ActiveTrialCard: View {
    let trial: Trial

    private var card: TrialCard { trial.chosenCard }
    private var tint: Color { card.theme.tintColor }

    /// 0.0 = not started, 1.0 = complete.
    /// For now: pending=0, windowOpen=0.5, completed=1.0, missed=0.
    private var capstoneProgress: Double {
        switch trial.capstoneState {
        case .pending:    return 0.0
        case .windowOpen: return 0.5
        case .completed:  return 1.0
        case .missed:     return 0.0
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── Header row ─────────────────────────────────────────
            HStack(spacing: 8) {
                Text(card.theme.displayLabel)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(tint.opacity(0.14)))
                    .overlay(Capsule().strokeBorder(tint.opacity(0.30), lineWidth: 1))

                Text("ACTIVE TRIAL")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textTertiary)

                Spacer(minLength: 0)

                capstonePill
            }

            // ── Trial name ─────────────────────────────────────────
            Text(card.displayName)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            // ── Blurb ──────────────────────────────────────────────
            Text(card.blurb)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(2)
                .lineSpacing(2)

            // ── Capstone progress bar ──────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("CAPSTONE — \(card.capstone.displayName.uppercased())")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Spacer(minLength: 0)
                    Text(capstoneStateLabel)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(tint)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [tint, tint.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, proxy.size.width * capstoneProgress))
                            .shadow(color: tint.opacity(0.35), radius: 6)
                    }
                }
                .frame(height: 5)
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: capstoneProgress)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.10), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.30), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    @ViewBuilder
    private var capstonePill: some View {
        if trial.capstoneState == .completed {
            HStack(spacing: 5) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                Text("DONE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
            }
            .foregroundStyle(Color.unbound.success)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.unbound.success.opacity(0.14)))
        } else if trial.capstoneState == .windowOpen {
            Text("SAT–SUN")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(tint)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(tint.opacity(0.14)))
        }
    }

    private var capstoneStateLabel: String {
        switch trial.capstoneState {
        case .pending:    return "MON–FRI"
        case .windowOpen: return "OPEN"
        case .completed:  return "COMPLETE"
        case .missed:     return "MISSED"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        ActiveTrialCard(
            trial: Trial(
                id: "trial-W20-aligned",
                userId: "preview",
                weekStart: Date(),
                chosenCard: TrialCard(
                    id: "trial-W20-aligned",
                    kind: .aligned,
                    theme: .axis(.power),
                    displayName: "Power Focus",
                    blurb: "Double down on heavy compound work this week.",
                    capstone: TrialCapstone(displayName: "Top-Set PR", description: "Hit a squat or deadlift PR.", evaluation: .manualClaim)
                ),
                capstoneState: .windowOpen
            )
        )
        .padding(20)
    }
}
