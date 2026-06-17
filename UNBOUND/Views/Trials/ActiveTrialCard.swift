import SwiftUI

// MARK: - ActiveTrialCard
//
// Shows the current active Binding Vow in the Home contextualStack with its
// in-context seal affordance: a tap-to-log row that increments toward the
// target and seals the vow at target via WeeklyVowsService.logVowProgress.
// Every lane self-reports the same way.

struct ActiveTrialCard: View {
    let trial: Trial

    @EnvironmentObject private var services: ServiceContainer

    /// Self-report tally + outstanding vow debt, kept in sync after each tap so
    /// the card reflects progress without a full state reload.
    @State private var progressCount: Int = 0
    @State private var debtXP: Int = 0

    private var card: TrialCard { trial.chosenCard }
    private var tint: Color { card.lane.tintColor }
    private var isSealed: Bool { trial.capstoneState == .completed }

    /// Days remaining in the vow week (weekStart + 7).
    private var daysLeftText: String {
        let weekEnd = trial.weekStart.addingTimeInterval(7 * 86_400)
        let days = Calendar.current.dateComponents([.day], from: Date(), to: weekEnd).day ?? 0
        if days <= 0 { return "FINAL DAY" }
        if days == 1 { return "1 DAY LEFT" }
        return "\(days) DAYS LEFT"
    }

    /// The stake at risk this week: win on a clear, debt on a break.
    private var stakesText: String { "+\(card.bet.winXP) / −\(card.bet.oweXP) XP" }

    private var progressFraction: Double {
        guard card.target.count > 0 else { return 0 }
        return min(1, Double(progressCount) / Double(card.target.count))
    }

    var body: some View {
        cardContent
            .onAppear(perform: refreshState)
            .accessibilityIdentifier("weeklyVow.activeCard")
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Active Binding Vow")
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                WeeklyVowProofAsset(lane: card.lane, tint: tint, compact: true)
                    .frame(width: 54, height: 54)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(card.lane.displayLabel)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(tint)
                            .lineLimit(1)

                        Text(card.bet.displayLabel)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(Color.unbound.textTertiary)
                            .lineLimit(1)
                    }

                    Text(card.displayName)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    HStack(spacing: 7) {
                        Text("VOW")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(Color.unbound.textTertiary)
                            .lineLimit(1)
                        Text(card.target.displayText.uppercased())
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.64)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 0)
            }

            affordance
            debtStrip
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
        )
    }

    // MARK: - Affordance

    @ViewBuilder
    private var affordance: some View {
        if isSealed {
            sealedRow
        } else {
            VStack(spacing: 10) {
                metaLine
                vowLogRow
                progressMeter
            }
        }
    }

    /// Days-left this week + the stake at risk — the week framing the bare log
    /// row was missing.
    private var metaLine: some View {
        HStack(spacing: 7) {
            Image(systemName: "hourglass")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
            Text(daysLeftText)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer(minLength: 0)
            Text(stakesText)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// Slim progress track mirroring the count toward target.
    private var progressMeter: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.unbound.surfaceElevated)
                Capsule()
                    .fill(tint)
                    .frame(width: max(5, geo.size.width * progressFraction))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }

    /// Outstanding broken-vow debt. Surfaced calmly (attention, not alarm) with
    /// the reassurance that training pays it down — never negging.
    @ViewBuilder
    private var debtStrip: some View {
        if debtXP > 0 {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.forward.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.unbound.warnOrange)
                Text("VOW DEBT")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.warnOrange)
                Text("\(debtXP) XP")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                Spacer(minLength: 0)
                Text("clears as you train")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.unbound.warnOrange.opacity(0.10))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Vow debt \(debtXP) XP, clears as you train.")
        }
    }

    private var sealedRow: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.unbound.success)
            Text("VOW SEALED THIS WEEK")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.success)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.success.opacity(0.12))
        )
    }

    /// Self-report: each tap logs one toward target; the service seals the vow
    /// once the tally reaches the target count.
    private var vowLogRow: some View {
        Button(action: logProgress) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                Text("LOG \(card.target.noun.uppercased())")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Text("\(progressCount)/\(card.target.count)")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.unbound.surfaceElevated.opacity(0.9))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log one \(card.target.noun). \(progressCount) of \(card.target.count) so far.")
    }

    // MARK: - Actions

    private func refreshState() {
        guard let userId = services.auth.currentUserId else { return }
        progressCount = services.trials.vowProgressCount(userId: userId)
        debtXP = services.trials.state(userId: userId).pendingVowDebtXP
    }

    private func logProgress() {
        guard let userId = services.auth.currentUserId else { return }
        UnboundHaptics.tick()
        Task { @MainActor in
            await services.trials.logVowProgress(userId: userId)
            refreshState()
        }
    }
}

// MARK: - ActiveVowSheet
//
// Bottom sheet wrapper for the active vow, presented from the Home Binding Vow
// command. Surfaces the vow's blurb and the in-context seal affordance.

struct ActiveVowSheet: View {
    let trial: Trial

    @Environment(\.dismiss) private var dismiss

    private var card: TrialCard { trial.chosenCard }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("BINDING VOW")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)

                ActiveTrialCard(trial: trial)

                Text(card.blurb)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineSpacing(2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        VStack(spacing: 16) {
            ActiveTrialCard(
                trial: Trial(
                    id: "weekly-vow-W20-fuel",
                    userId: "preview",
                    weekStart: Date(),
                    chosenCard: TrialCard(
                        id: "weekly-vow-W20-fuel",
                        lane: .fuel,
                        bet: .medium,
                        displayName: "Fuel Anchor",
                        blurb: "Hit your fuel anchors this week.",
                        target: VowTarget(count: 3, noun: "fuel anchor")
                    ),
                    capstoneState: .windowOpen
                )
            )
            ActiveTrialCard(
                trial: Trial(
                    id: "weekly-vow-W20-recovery",
                    userId: "preview",
                    weekStart: Date(),
                    chosenCard: TrialCard(
                        id: "weekly-vow-W20-recovery",
                        lane: .recovery,
                        bet: .small,
                        displayName: "Iron Reset",
                        blurb: "A low-day reset for clean recovery.",
                        target: VowTarget(count: 1, noun: "recovery reset")
                    ),
                    capstoneState: .windowOpen
                )
            )
        }
        .padding(20)
        .environmentObject(ServiceContainer.mock)
    }
}
