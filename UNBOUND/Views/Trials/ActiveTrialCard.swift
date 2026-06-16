import SwiftUI

// MARK: - ActiveTrialCard
//
// Shows the current active Binding Vow in the Home contextualStack, with its
// in-context seal affordance:
//   - Fuel (self-report): a tap-to-log anchor row that increments toward target
//     and seals the vow at target via WeeklyVowsService.logFuelAnchor.
//   - Recovery/Engine (auto-from-log): a calm hint that the vow auto-seals when
//     a qualifying recovery/cardio session is logged this week.

struct ActiveTrialCard: View {
    let trial: Trial

    @EnvironmentObject private var services: ServiceContainer

    /// Fuel anchor tally for the active vow, kept in sync after each self-report
    /// tap so the row reflects progress without a full state reload.
    @State private var fuelCount: Int = 0

    private var card: TrialCard { trial.chosenCard }
    private var tint: Color { card.lane.tintColor }
    private var isSealed: Bool { trial.capstoneState == .completed }

    var body: some View {
        cardContent
            .onAppear(perform: refreshFuelCount)
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
        } else if card.lane.verification == .selfReport {
            fuelLogRow
        } else {
            autoSealHint
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

    /// Fuel self-report: each tap logs one anchor toward target; the service
    /// seals the vow once the tally reaches the target count.
    private var fuelLogRow: some View {
        Button(action: logFuelAnchor) {
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
                Text("\(fuelCount)/\(card.target.count)")
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
        .accessibilityLabel("Log one \(card.target.noun). \(fuelCount) of \(card.target.count) so far.")
    }

    /// Recovery/Engine: verified from logged sessions, so there is no manual
    /// button — just a calm hint of what seals it.
    private var autoSealHint: some View {
        HStack(spacing: 8) {
            Image(systemName: card.lane.sealSymbolName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
            Text("Auto-seals when you log \(card.target.displayText) this week")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.6))
        )
    }

    // MARK: - Actions

    private func refreshFuelCount() {
        guard card.lane.verification == .selfReport,
              let userId = services.auth.currentUserId
        else { return }
        fuelCount = services.trials.fuelAnchorCount(userId: userId)
    }

    private func logFuelAnchor() {
        guard let userId = services.auth.currentUserId else { return }
        UnboundHaptics.tick()
        services.trials.logFuelAnchor(userId: userId)
        fuelCount = services.trials.fuelAnchorCount(userId: userId)
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
