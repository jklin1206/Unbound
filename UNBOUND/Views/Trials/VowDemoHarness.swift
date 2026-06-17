import SwiftUI

#if DEBUG
// MARK: - VowDemoHarness
//
// Dev harness (`-vowDemo`) that renders the redesigned Binding Vow surfaces with
// seeded state, so the active card (progress bar + log affordance), the sealed
// state, and the profile history can be screenshot without driving the whole app
// to Home. Seeds WeeklyVowsStore.shared for the mock user the mock
// ServiceContainer authenticates as.

struct VowDemoHarness: View {
    private let userId = "mock-user-123"

    private let activeCard = TrialCard(
        id: "demo-fuel",
        lane: .fuel,
        bet: .medium,
        displayName: "First Spark Vow",
        blurb: "Bind three fuel anchors this week — protein, water, or a real meal. Tap each as you hit it.",
        target: VowTarget(count: 3, noun: "fuel anchor")
    )

    init() { seed() }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
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
            displayName: "Still Water Vow",
            blurb: "Bind one recovery reset this week. Protect the arc; let the body catch up.",
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
        s.keptVows = [
            KeptVow(vowId: "k1", name: "Still Water Vow", lane: .recovery, completedAt: Date().addingTimeInterval(-1 * 86_400)),
            KeptVow(vowId: "k2", name: "First Spark Vow", lane: .fuel, completedAt: Date().addingTimeInterval(-4 * 86_400)),
            KeptVow(vowId: "k3", name: "Iron Lungs Vow", lane: .engine, completedAt: Date().addingTimeInterval(-9 * 86_400)),
            KeptVow(vowId: "k4", name: "Open Gate Vow", lane: .recovery, completedAt: Date().addingTimeInterval(-16 * 86_400))
        ]
        return s
    }

    private func seed() {
        var state = WeeklyVowsState.empty
        state.currentWeekStart = weekStart
        state.currentWeekCards = [activeCard]
        state.currentVow = activeVow
        state.fuelAnchorsByVowId[activeCard.id] = 1  // partial progress, still loggable today (shows the LOG row)
        state.completionsByLane = [.recovery: 3, .fuel: 4, .engine: 2]
        WeeklyVowsStore.shared.save(state, userId: userId)
    }
}
#endif
