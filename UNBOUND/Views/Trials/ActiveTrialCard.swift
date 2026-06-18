import SwiftUI

// MARK: - ActiveTrialCard (slim vow strip)
//
// A thin, calm Binding Vow row for the Home Trials section — deliberately
// distinct from the rank-gate world card, because a vow is a weekly self-report
// habit, not a place you enter. One tap logs one toward the target (the
// once-a-day inline log) and shows the running count; a second tap the same day
// is a no-op, and hitting the target seals the vow.

struct ActiveTrialCard: View {
    let trial: Trial

    @EnvironmentObject private var services: ServiceContainer

    @State private var progressCount: Int = 0
    @State private var canLogToday: Bool = true

    private var card: TrialCard { trial.chosenCard }
    private var tint: Color { card.lane.tintColor }
    private var isSealed: Bool { trial.capstoneState == .completed }
    private var actionable: Bool { !isSealed && canLogToday }

    private var statusText: String {
        if isSealed { return "sealed" }
        if !canLogToday { return "done today" }
        return "tap to log"
    }

    private var trailingIcon: String {
        if isSealed { return "checkmark.seal.fill" }
        return canLogToday ? "plus.circle.fill" : "checkmark.circle.fill"
    }

    private var trailingTint: Color {
        if actionable { return tint }
        return isSealed ? Color.unbound.success : Color.unbound.textTertiary
    }

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 12) {
                WeeklyVowProofAsset(lane: card.lane, tint: tint, compact: true)
                    .frame(width: 26, height: 26)
                    .accessibilityHidden(true)

                HStack(spacing: 6) {
                    Text(card.lane.displayLabel)
                        .foregroundStyle(tint)
                    Text("·")
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(card.displayName)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(0.6)

                Spacer(minLength: 8)

                Text("\(progressCount)/\(card.target.count)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(isSealed ? Color.unbound.success : tint)
                    .monospacedDigit()

                Image(systemName: trailingIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(trailingTint)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!actionable)
        .onAppear(perform: refreshState)
        .accessibilityIdentifier("weeklyVow.activeCard")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Binding vow, \(card.displayName), \(progressCount) of \(card.target.count), \(statusText)")
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
        VStack(spacing: 8) {
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
