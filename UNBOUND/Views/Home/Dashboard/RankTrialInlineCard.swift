import SwiftUI

// MARK: - Home Trials chrome
//
// Supporting pieces for the Home Trials section. The rank gate itself is the
// immersive NextGateCard "world" card (placed directly on Home — ENTER drops you
// into the trial, no detail-sheet repeat). These are the bits around it: the
// Trial Records entry that opens the full 8-gate list, the all-gates-cleared
// state, the locked fallback, and the vow pick strip.

enum HomeGateMarkerState {
    case cleared, current, locked
}

/// The 8-gate journey, visible at a glance: cleared / current / locked segments.
/// Tappable for the full records list, but you can SEE your progress without it.
struct HomeGateProgressionStrip: View {
    let states: [HomeGateMarkerState]
    let onTap: () -> Void

    private var clearedCount: Int { states.filter { $0 == .cleared }.count }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("GATES")
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)

                HStack(spacing: 5) {
                    ForEach(states.indices, id: \.self) { i in
                        marker(states[i])
                    }
                }
                .frame(maxWidth: .infinity)

                Text("\(clearedCount)/\(states.count)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .monospacedDigit()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gate progress, \(clearedCount) of \(states.count) cleared. Tap for trial records.")
    }

    @ViewBuilder
    private func marker(_ state: HomeGateMarkerState) -> some View {
        switch state {
        case .cleared:
            Capsule().fill(Color.unbound.rankGold)
                .frame(maxWidth: .infinity).frame(height: 6)
        case .current:
            Capsule().fill(Color.unbound.accent)
                .frame(maxWidth: .infinity).frame(height: 8)
                .shadow(color: Color.unbound.accent.opacity(0.55), radius: 4)
        case .locked:
            Capsule().fill(Color.unbound.surfaceElevated)
                .frame(maxWidth: .infinity).frame(height: 6)
        }
    }
}

/// Shown when every gate has been answered (peak rank) — there's no next gate, so
/// instead of a "locked" fallback this is the quiet milestone state.
struct HomeAllGatesClearedCard: View {
    let peakRankName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(Color.unbound.rankGold)
                    .shadow(color: Color.unbound.rankGold.opacity(0.5), radius: 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text("ALL GATES CLEARED")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.rankGold)
                    Text(peakRankName)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }

            Text("Every gate answered. You're Unbound.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.unbound.rankGold.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("All gates cleared. \(peakRankName).")
    }
}

struct HomeRankGateLockedRow: View {
    let detail: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.unbound.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("RANK TRIAL")
                        .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(detail)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rank trial, \(detail)")
    }
}

/// The vow slot before a vow is picked — a slim prompt matching the active strip.
struct HomeVowPickStrip: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "link")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("BINDING VOW")
                        .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("Pick this week's vow")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.20), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pick a binding vow")
    }
}

#if DEBUG
// MARK: - Demo harness (-homeTrialsDemo)
//
// Renders the Home Trials section in the states the live dev user isn't in, so
// the in-progress gate (with requirements), the ready gate, the all-gates-cleared
// milestone, and the no-vow prompt can be screenshotted for review.

struct HomeTrialsDemoHarness: View {
    private let userId = "mock-user-123"
    private let totalGates = RankTrialFormat.allCases.count

    private let vowCard = TrialCard(
        id: "demo-fuel",
        lane: .fuel,
        bet: .medium,
        displayName: "First Spark",
        blurb: "Bind three fuel anchors this week.",
        target: VowTarget(count: 3, noun: "fuel anchor")
    )

    init() { seedVow() }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    section("ALL GATES CLEARED") {
                        HomeAllGatesClearedCard(peakRankName: "Unbound")
                        HomeGateProgressionStrip(states: gateStates(cleared: totalGates, hasCurrent: false), onTap: {})
                    }

                    section("ACTIVE VOW") {
                        ActiveTrialCard(trial: activeVow)
                    }

                    section("NO VOW PICKED") {
                        HomeVowPickStrip(onTap: {})
                    }

                    section("IN PROGRESS · REQUIREMENTS SHOW") {
                        NextGateCard(readiness: fixtureReadiness(open: false), world: world)
                        HomeGateProgressionStrip(states: gateStates(cleared: 2, hasCurrent: true), onTap: {})
                    }

                    section("READY TO ENTER") {
                        NextGateCard(readiness: fixtureReadiness(open: true), world: world, onBegin: {})
                        HomeGateProgressionStrip(states: gateStates(cleared: 0, hasCurrent: true), onTap: {})
                    }
                }
                .padding(20)
            }
        }
        .environmentObject(ServiceContainer.mock)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            content()
        }
    }

    // MARK: Fixtures

    private var world: GateWorld { GateWorldCatalog.world(for: .firstLight) }

    private var definition: OverallRankTrialDefinition? {
        OverallRankTrialDefinitions.all.first { $0.format == .firstLight }
    }

    private func fixtureReadiness(open: Bool) -> OverallRankTrialReadiness {
        let origin = RankTier(rawValue: world.destinationRank.rawValue - 1) ?? .initiate
        var reqs: [OverallRankTrialRequirementLine] = [
            .init(id: "lvl", kind: .overallLevel, label: "Reach the level floor",
                  current: open ? "Lv 24" : "Lv 19", required: "Lv 24", isMet: open),
            .init(id: "rank", kind: .rank, label: "Build to \(world.destinationRank.displayName)",
                  current: open ? world.destinationRank.displayName : origin.displayName,
                  required: world.destinationRank.displayName, isMet: open)
        ]
        for (i, key) in GateKeys.keys(for: .firstLight).enumerated() {
            let lit = open || i == 0
            reqs.append(.init(id: key.id, kind: .gateKey, label: key.label,
                              current: lit ? "Proven" : "Unproven", required: key.label, isMet: lit))
        }
        return OverallRankTrialReadiness(
            status: open ? .ready : .locked, currentRank: origin, targetRank: world.destinationRank,
            definition: definition, resolvedTrial: nil,
            blockerSummary: open ? nil : "Keep training — the gate is close.",
            requirements: reqs, latestAttempt: nil)
    }

    private func gateStates(cleared: Int, hasCurrent: Bool) -> [HomeGateMarkerState] {
        (0..<totalGates).map { i in
            if i < cleared { return .cleared }
            if hasCurrent && i == cleared { return .current }
            return .locked
        }
    }

    private var activeVow: Trial {
        WeeklyVow(
            id: vowCard.id,
            userId: userId,
            weekStart: Date().addingTimeInterval(-2 * 86_400),
            chosenCard: vowCard,
            capstoneState: .windowOpen,
            completedAt: nil
        )
    }

    private func seedVow() {
        var state = WeeklyVowsState.empty
        state.currentWeekStart = Date().addingTimeInterval(-2 * 86_400)
        state.currentWeekCards = [vowCard]
        state.currentVow = activeVow
        state.fuelAnchorsByVowId[vowCard.id] = 1  // 1/3, still loggable
        WeeklyVowsStore.shared.save(state, userId: userId)
    }
}
#endif
