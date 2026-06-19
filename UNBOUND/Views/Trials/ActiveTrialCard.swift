import SwiftUI

// MARK: - ActiveTrialCard (Binding Vow card)
//
// The week's Binding Vow on the Home Trials section. Leads with the goal in plain
// big text — what to do and how many — then a prominent log button (how to log).
// One tap on LOG records one toward the target (once a day); hitting the target
// seals the vow.

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

    /// The whole point of the vow, in plain words: "Log 3 fuel anchors".
    private var goalText: String {
        let plural = card.target.count == 1 ? card.target.noun : "\(card.target.noun)s"
        return "Log \(card.target.count) \(plural)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Category + running count.
            HStack(spacing: 8) {
                WeeklyVowProofAsset(lane: card.lane, tint: tint, compact: true)
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)
                Text("BINDING VOW · \(card.lane.displayLabel)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(progressCount)/\(card.target.count)")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(filledTint)
                    .monospacedDigit()
            }

            // The goal, big — what the vow is + how to complete it.
            VStack(alignment: .leading, spacing: 5) {
                Text(goalText)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.blurb)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            progressPips

            // How to log — one prominent action.
            affordance
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        )
        .onAppear(perform: refreshState)
        .accessibilityIdentifier("weeklyVow.activeCard")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Binding vow: \(goalText) this week. \(progressCount) of \(card.target.count) logged.")
    }

    @ViewBuilder
    private var progressPips: some View {
        if card.target.count <= 8 {
            HStack(spacing: 6) {
                ForEach(0..<card.target.count, id: \.self) { i in
                    Capsule()
                        .fill(i < progressCount ? filledTint : Color.unbound.surfaceElevated)
                        .frame(maxWidth: .infinity)
                        .frame(height: 8)
                }
            }
        } else {
            ProgressView(value: Double(min(progressCount, card.target.count)),
                         total: Double(card.target.count))
                .tint(filledTint)
        }
    }

    @ViewBuilder
    private var affordance: some View {
        if isSealed {
            statusRow(text: "Vow sealed this week", icon: "checkmark.seal.fill",
                      color: Color.unbound.success, fill: Color.unbound.success.opacity(0.14))
        } else if canLogToday {
            Button(action: handleTap) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("Log a \(card.target.noun)")
                        .font(.system(size: 15, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .opacity(0.8)
                }
                .foregroundStyle(Color.unbound.bg)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous).fill(tint)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log one \(card.target.noun). \(progressCount) of \(card.target.count) so far.")
        } else {
            statusRow(text: "Logged today — back tomorrow", icon: "checkmark.circle.fill",
                      color: Color.unbound.textSecondary, fill: Color.unbound.surfaceElevated.opacity(0.6))
        }
    }

    private func statusRow(text: String, icon: String, color: Color, fill: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(color)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous).fill(fill)
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
