import SwiftUI

// MARK: - ActiveTrialCard
//
// Compact Binding Vow tile for the Home Trials row (paired beside the rank tile).
// One tap logs one toward the target — the once-a-day inline log — and the tile
// shows the running count. A second tap the same day is a no-op (status reads
// "LOGGED TODAY"); once the target is hit the vow seals.

struct ActiveTrialCard: View {
    let trial: Trial

    @EnvironmentObject private var services: ServiceContainer

    @State private var progressCount: Int = 0
    @State private var canLogToday: Bool = true

    private var card: TrialCard { trial.chosenCard }
    private var tint: Color { card.lane.tintColor }
    private var isSealed: Bool { trial.capstoneState == .completed }

    private var status: String {
        if isSealed { return "SEALED" }
        if !canLogToday { return "LOGGED TODAY" }
        return "TAP TO LOG +1"
    }

    private var statusTint: Color {
        if isSealed { return Color.unbound.success }
        if !canLogToday { return Color.unbound.textSecondary }
        return tint
    }

    var body: some View {
        HomeTrialTileShell(
            tint: tint,
            eyebrow: card.lane.displayLabel,
            title: card.displayName,
            status: status,
            statusTint: statusTint,
            onTap: handleTap,
            glyph: {
                WeeklyVowProofAsset(lane: card.lane, tint: tint, compact: true)
                    .frame(width: 30, height: 30)
            },
            trailing: {
                Text("\(progressCount)/\(card.target.count)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(isSealed ? Color.unbound.success : tint)
                    .monospacedDigit()
            }
        )
        .onAppear(perform: refreshState)
        .accessibilityIdentifier("weeklyVow.activeCard")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Binding vow, \(card.displayName), \(progressCount) of \(card.target.count). \(status)")
    }

    private func handleTap() {
        guard !isSealed, canLogToday else { return }
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
        HStack(alignment: .top, spacing: 12) {
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
                    capstoneState: .completed,
                    completedAt: Date()
                )
            )
        }
        .padding(20)
        .environmentObject(ServiceContainer.mock)
    }
}
