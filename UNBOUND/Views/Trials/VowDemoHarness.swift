import SwiftUI

#if DEBUG
// MARK: - VowDemoHarness
//
// Dev harness (`-vowDemo`) that renders the redesigned Binding Vow surfaces with
// seeded state, so the active card (incl. the debt strip + progress meter), the
// sealed state, and the profile history can be screenshot without driving the
// whole app to Home. Seeds WeeklyVowsStore.shared for the mock user the mock
// ServiceContainer authenticates as.

struct VowDemoHarness: View {
    private let userId = "mock-user-123"

    private let activeCard = TrialCard(
        id: "demo-fuel",
        lane: .fuel,
        bet: .medium,
        displayName: "Fuel Anchor",
        blurb: "Hit three clean fuel anchors before the week closes.",
        target: VowTarget(count: 3, noun: "fuel anchor")
    )

    init() { seed() }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    label("XP RAIL · DEBT IN ONE PLACE")
                    HomeTrainingRankRail(
                        level: 12,
                        xpInLevel: 340,
                        xpForLevel: 800,
                        fraction: 0.42,
                        aggregateTier: .veteran,
                        rankColor: RankTier.veteran.rewardTint,
                        vowDebtXP: 250
                    )
                    .frame(height: 210)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.surface)
                    )

                    label("ACTIVE VOW · CALM")
                    ActiveTrialCard(trial: activeVow)

                    label("SEALED")
                    ActiveTrialCard(trial: sealedVow)

                    label("PROFILE HISTORY")
                    ProfileTrialHistorySection(trialsState: profileState)
                }
                .padding(20)
            }
        }
        .environmentObject(ServiceContainer.mock)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(Color.unbound.textTertiary)
    }

    private var weekStart: Date { Date().addingTimeInterval(-2 * 86_400) }

    private var activeVow: Trial {
        WeeklyVow(
            id: activeCard.id,
            userId: userId,
            weekStart: weekStart,
            chosenCard: activeCard,
            capstoneState: .pending,
            completedAt: nil
        )
    }

    private var sealedVow: Trial {
        let card = TrialCard(
            id: "demo-recovery",
            lane: .recovery,
            bet: .small,
            displayName: "Iron Reset",
            blurb: "A low-day reset that protects recovery.",
            target: VowTarget(count: 1, noun: "recovery reset")
        )
        return WeeklyVow(
            id: card.id,
            userId: userId,
            weekStart: weekStart,
            chosenCard: card,
            capstoneState: .completed,
            completedAt: Date()
        )
    }

    private var profileState: TrialsState {
        var s = WeeklyVowsState.empty
        s.completionsByLane = [.recovery: 3, .fuel: 4, .engine: 2]
        return s
    }

    private func seed() {
        var state = WeeklyVowsState.empty
        state.currentWeekStart = weekStart
        state.currentWeekCards = [activeCard]
        state.currentVow = activeVow
        state.fuelAnchorsByVowId[activeCard.id] = 1
        state.pendingVowDebtXP = 250
        state.completionsByLane = [.recovery: 3, .fuel: 4, .engine: 2]
        WeeklyVowsStore.shared.save(state, userId: userId)
    }
}
#endif
