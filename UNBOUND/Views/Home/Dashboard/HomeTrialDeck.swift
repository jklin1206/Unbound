import SwiftUI

// MARK: - Home Trials deck
//
// The Home Trials section as a horizontally-swipeable deck of the gate worlds —
// the same NextGateCard, one per gate, that you slide through. The dots below are
// a pure position + state indicator (cleared / current / locked); there is no
// arrow, because the deck is browsed by swiping.

struct HomeTrialDeck: View {
    enum GateState { case cleared, current, locked }

    struct Gate: Identifiable {
        let id: Int
        let format: RankTrialFormat
        let world: GateWorld
        let state: GateState
    }

    let gates: [Gate]
    var currentReadiness: OverallRankTrialReadiness? = nil
    var onBegin: () -> Void = {}
    var onShowRecords: () -> Void = {}

    @State private var scrollID: Int?

    /// Open the deck on the gate you're working on (or the furthest cleared).
    private var startIndex: Int {
        gates.first(where: { $0.state == .current })?.id
            ?? gates.last(where: { $0.state == .cleared })?.id
            ?? 0
    }

    /// Only cleared + current gates can be swiped to — the next gate unlocks once
    /// you beat the current trial.
    private var swipeableGates: [Gate] { gates.filter { $0.state != .locked } }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(swipeableGates) { gate in
                        NextGateCard(
                            readiness: readiness(for: gate),
                            world: gate.world,
                            onBegin: gate.state == .current ? onBegin : nil
                        )
                        // Match the agent's original full-width card (the home content
                        // inset already provides the margin that shows the border).
                        .containerRelativeFrame(.horizontal)
                        .id(gate.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollID)
        }
        .onAppear { scrollID = startIndex }
    }

    // The gate you're on uses real readiness; cleared/locked use a light synthesized
    // state so the same card renders them (only the next gate's readiness is computed).
    private func readiness(for gate: Gate) -> OverallRankTrialReadiness {
        if gate.state == .current, let currentReadiness {
            return currentReadiness
        }
        let definition = OverallRankTrialDefinitions.all.first { $0.format == gate.format }
        let destination = gate.world.destinationRank

        if gate.state == .cleared {
            // definition == nil → NextGateCard renders the quiet "cleared" state.
            return OverallRankTrialReadiness(
                status: .ready,
                currentRank: destination,
                targetRank: destination,
                definition: nil,
                resolvedTrial: nil,
                blockerSummary: nil,
                requirements: [],
                latestAttempt: nil
            )
        }

        let origin = RankTier(rawValue: destination.rawValue - 1) ?? destination
        return OverallRankTrialReadiness(
            status: .locked,
            currentRank: origin,
            targetRank: destination,
            definition: definition,
            resolvedTrial: nil,
            blockerSummary: "Reach this gate to begin.",
            requirements: [
                OverallRankTrialRequirementLine(
                    id: "rank",
                    kind: .rank,
                    label: "Build to \(destination.displayName)",
                    current: origin.displayName,
                    required: destination.displayName,
                    isMet: false
                )
            ],
            latestAttempt: nil
        )
    }
}
