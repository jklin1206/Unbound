import SwiftUI

// MARK: - Home Trials deck
//
// The Home Trials section as a horizontally-swipeable deck of the gate worlds —
// the same NextGateCard, one per gate, that you slide through instead of seeing
// only the next gate plus a separate progress strip. The dots below are a pure
// position + state indicator (cleared / current / locked); there is no arrow,
// because the deck is browsed by swiping.

struct HomeTrialDeck: View {
    struct Gate: Identifiable {
        let id: Int
        let format: RankTrialFormat
        let world: GateWorld
        let state: HomeGateMarkerState
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

    private var selectedIndex: Int { scrollID ?? startIndex }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(gates) { gate in
                        NextGateCard(
                            readiness: readiness(for: gate),
                            world: gate.world,
                            onBegin: gate.state == .current ? onBegin : nil
                        )
                        // Card inset inside a full-width page → its border reads.
                        .padding(.horizontal, 20)
                        .containerRelativeFrame(.horizontal)
                        .id(gate.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollID)

            indicator
        }
        .onAppear { scrollID = startIndex }
    }

    // Dots only — position + state at a glance, no arrow.
    private var indicator: some View {
        Button(action: onShowRecords) {
            HStack(spacing: 6) {
                ForEach(gates) { gate in
                    Capsule()
                        .fill(dotColor(gate))
                        .frame(width: gate.id == selectedIndex ? 20 : 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedIndex)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gate \(selectedIndex + 1) of \(gates.count). Double-tap for trial records.")
    }

    private func dotColor(_ gate: Gate) -> Color {
        switch gate.state {
        case .cleared: return Color.unbound.rankGold
        case .current: return Color.unbound.accent
        case .locked:  return Color.unbound.surfaceElevated
        }
    }

    // The gate you're on uses real readiness (full requirements + CTA). Cleared and
    // locked gates use a light synthesized state so the same card can render them —
    // full per-gate readiness isn't computed (only the next gate is).
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
