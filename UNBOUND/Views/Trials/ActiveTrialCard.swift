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

    /// Self-report tally, kept in sync after each tap so the card reflects
    /// progress without a full state reload.
    @State private var progressCount: Int = 0
    /// Whether the once-a-day log is still available today.
    @State private var canLogToday: Bool = true

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

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(card.lane.displayLabel)
                            .foregroundStyle(tint)
                        Text("·")
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(card.bet.displayLabel)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .lineLimit(1)

                    Text(card.displayName)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .layoutPriority(1)

                Spacer(minLength: 0)
            }

            affordance
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumGlassCard(cornerRadius: 20, tint: tint)
    }

    // MARK: - Affordance

    @ViewBuilder
    private var affordance: some View {
        if isSealed {
            sealedRow
        } else {
            VStack(spacing: 10) {
                progressRow
                metaLine
                if canLogToday {
                    vowLogRow
                } else {
                    loggedTodayRow
                }
            }
        }
    }

    /// Once-a-day gate hit — a calm "come back tomorrow" state.
    private var loggedTodayRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.unbound.success)
            Text("LOGGED TODAY")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.5))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Logged today, \(progressCount) of \(card.target.count). Come back tomorrow.")
    }

    /// Days-left this week — the week framing for the log row.
    /// (Stakes live on the XP rail — one place for the XP economy.)
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
        }
    }

    /// Progress track + count — the single place the target count is shown.
    private var progressRow: some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.unbound.surfaceElevated)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(5, geo.size.width * progressFraction))
                }
            }
            .frame(height: 6)
            Text("\(progressCount)/\(card.target.count)")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(progressCount) of \(card.target.count) logged.")
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
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
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
        canLogToday = services.trials.canLogVowToday(userId: userId, now: Date())
    }

    private func logProgress() {
        guard let userId = services.auth.currentUserId else { return }
        UnboundHaptics.tick()
        Task { @MainActor in
            await services.trials.logVowProgress(userId: userId, at: Date())
            refreshState()
        }
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
