import SwiftUI

// MARK: - ActiveTrialCard (Binding Vow card)
//
// The week's Binding Vow on the Home Trials section — a calm card (surface +
// subtle lane tint edge, matching the rank-gate world card, no frost) with a
// clear inline log action. One tap on LOG records one toward the target (the
// once-a-day log); a second tap the same day is a no-op, and hitting the target
// seals the vow. Sized to give the vow real presence next to the gate.

struct ActiveTrialCard: View {
    let trial: Trial

    @EnvironmentObject private var services: ServiceContainer

    @State private var progressCount: Int = 0
    @State private var canLogToday: Bool = true

    private var card: TrialCard { trial.chosenCard }
    private var tint: Color { card.lane.tintColor }
    private var isSealed: Bool { trial.capstoneState == .completed }
    private var actionable: Bool { !isSealed && canLogToday }
    private var filledTint: Color { isSealed ? Color.unbound.success : tint }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                WeeklyVowProofAsset(lane: card.lane, tint: tint, compact: true)
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text("BINDING VOW")
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text("·")
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(card.lane.displayLabel)
                            .foregroundStyle(tint)
                    }
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .lineLimit(1)

                    Text(card.displayName)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 8)

                progressIndicator
            }

            affordance
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.20), lineWidth: 1)
        )
        .onAppear(perform: refreshState)
        .accessibilityIdentifier("weeklyVow.activeCard")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Binding vow, \(card.displayName), \(progressCount) of \(card.target.count)")
    }

    /// Weekly progress — pips for small targets (the common case), a count for big
    /// ones so it stays readable.
    @ViewBuilder
    private var progressIndicator: some View {
        if card.target.count <= 6 {
            HStack(spacing: 5) {
                ForEach(0..<card.target.count, id: \.self) { i in
                    Capsule()
                        .fill(i < progressCount ? filledTint : Color.unbound.surfaceElevated)
                        .frame(width: i < progressCount ? 13 : 8, height: 8)
                }
            }
        } else {
            Text("\(progressCount)/\(card.target.count)")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(filledTint)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var affordance: some View {
        if isSealed {
            statusRow(text: "VOW SEALED THIS WEEK", icon: "checkmark.seal.fill",
                      color: Color.unbound.success, fill: Color.unbound.success.opacity(0.12))
        } else if canLogToday {
            Button(action: handleTap) {
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
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.unbound.surfaceElevated.opacity(0.9))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log one \(card.target.noun). \(progressCount) of \(card.target.count) so far.")
        } else {
            statusRow(text: "LOGGED TODAY", icon: "checkmark.circle.fill",
                      color: Color.unbound.textSecondary, fill: Color.unbound.surfaceElevated.opacity(0.5))
        }
    }

    private func statusRow(text: String, icon: String, color: Color, fill: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(color)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(fill)
        )
    }

    private func handleTap() {
        guard actionable else { return }
        guard let userId = services.auth.currentUserId else { return }
        UnboundHaptics.tick()
        Task { @MainActor in
            await services.trials.logVowProgress(userId: userId, at: Date())
            refreshState()
        }
    }

    private func refreshState() {
        guard let userId = services.auth.currentUserId else { return }
        progressCount = services.trials.vowProgressCount(userId: userId)
        canLogToday = services.trials.canLogVowToday(userId: userId, now: Date())
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        VStack(spacing: 12) {
            ActiveTrialCard(
                trial: Trial(
                    id: "weekly-vow-W20-fuel",
                    userId: "preview",
                    weekStart: Date(),
                    chosenCard: TrialCard(
                        id: "weekly-vow-W20-fuel",
                        lane: .fuel,
                        bet: .medium,
                        displayName: "First Spark",
                        blurb: "Hit your fuel anchors this week.",
                        target: VowTarget(count: 3, noun: "fuel anchor")
                    ),
                    capstoneState: .windowOpen
                )
            )
        }
        .padding(20)
        .environmentObject(ServiceContainer.mock)
    }
}
