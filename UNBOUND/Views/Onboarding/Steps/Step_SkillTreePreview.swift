import SwiftUI

// MARK: - Step_SkillTreePreview
//
// The paywall sell. Shows the user's archetype skill tree with first 2
// nodes "attempting" (unlocked, waiting for them to hit) and the rest
// locked behind the paywall. Tap a locked node → bottom detail card
// revealing what it takes + a reminder that the app teaches them.
//
// Copy framing: "This is where the adaptive protocol takes you — not
// just numbers going up. Moves you can do that you can't right now."
//
// Appears between trajectory and testimonials in the onboarding flow.

struct Step_SkillTreePreview: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var selectedNode: SkillNode?
    @State private var hasAnimated = false

    var body: some View {
        // TODO(Phase 17): derive tree from seededAttributes BuildIdentity
        let tree = SkillTree.tree(for: .vTaper)

        OnboardingScaffold(
            title: "You won't stay at E.",
            subtitle: "This is the ladder. Real feats, earned rep by rep.",
            progress: progress,
            primaryTitle: "I'm ready",
            hudStep: .skillTreePreview,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 18) {
                hypeCard
                howItWorksCard
                legendRow

                ScrollView(.vertical, showsIndicators: false) {
                    SkillTreeView(
                        tree: tree,
                        nodeStates: previewStates(for: tree),
                        onNodeTap: { node in
                            UnboundHaptics.medium()
                            selectedNode = node
                        }
                    )
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 420)
                .opacity(hasAnimated ? 1 : 0)
                .offset(y: hasAnimated ? 0 : 12)

                Text("Tap any node to see what it takes.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.top, 4)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.88)) {
                    hasAnimated = true
                }
            }
        }
        .sheet(item: $selectedNode) { node in
            NodeDetailSheet(node: node)
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.unbound.bg)
        }
    }

    // MARK: V1 static preview states
    //
    // First 2 nodes attempting (unlocked, not yet achieved); rest locked.
    // Real state-from-logs wiring is V2 work.

    private func previewStates(for tree: SkillTree) -> [String: NodeState] {
        var states: [String: NodeState] = [:]
        for (idx, node) in tree.nodes.enumerated() {
            states[node.id] = idx < 2 ? .attempting : .locked
        }
        return states
    }

    // MARK: Legend

    private var legendRow: some View {
        HStack(spacing: 16) {
            legendBadge(state: .attempting, label: "You're here")
            legendBadge(state: .locked, label: "Locked")
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func legendBadge(state: NodeState, label: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Hexagon()
                    .fill(state == .attempting
                          ? Color.unbound.surface
                          : Color.unbound.surface)
                Hexagon()
                    .strokeBorder(
                        state == .attempting ? Color.unbound.accent : Color.unbound.border,
                        lineWidth: 1.5
                    )
                if state == .locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
            .frame(width: 18, height: 18)
            .shadow(
                color: state == .attempting ? Color.unbound.accent.opacity(0.4) : .clear,
                radius: 4
            )
            Text(label)
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textSecondary)
        }
    }

    // MARK: Hype card — what the ladder actually unlocks
    //
    // Visceral preview of the peak moves *past* the beginner stuff. Anime
    // fans read the list and their brain goes "wait, I could actually do
    // that?" Concrete, earned, not vibes.

    private var hypeCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.unbound.ember)
                    Text("WHAT THIS UNLOCKS")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.ember)
                }

                VStack(alignment: .leading, spacing: 10) {
                    hypeFeat("Muscle-up", "The pull-up everyone wants")
                    hypeFeat("Front lever", "Core, grip, and lats in one hold")
                    hypeFeat("One-arm pushup", "Pure body control")
                    hypeFeat("Pistol squat", "Legs that actually work as a unit")
                    hypeFeat("Human flag", "The one that makes strangers stare")
                }

                Text("Each one is real. Each one is logged. Each one is yours.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }

    private func hypeFeat(_ name: String, _ detail: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "flame")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.ember)
                .frame(width: 18)
            Text(name)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("·")
                .foregroundStyle(Color.unbound.textTertiary)
            Text(detail)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer()
        }
    }

    // MARK: How it works — explains the app mechanic

    private var howItWorksCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.unbound.accent)
                    Text("HOW THIS WORKS")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.accent)
                }

                VStack(alignment: .leading, spacing: 10) {
                    howStep(number: "1", text: "Open the app. See your next unlock.")
                    howStep(number: "2", text: "Follow the session we built around it — form videos, set-by-set.")
                    howStep(number: "3", text: "Log your reps. Hit the benchmark — the node flips. Next one lights up.")
                }
            }
        }
    }

    private func howStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.accent)
                .frame(width: 18, height: 18)
                .overlay(
                    Circle().strokeBorder(Color.unbound.accent.opacity(0.55), lineWidth: 1)
                )
            Text(text)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

// MARK: - NodeDetailSheet

private struct NodeDetailSheet: View {
    let node: SkillNode

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Hexagon().fill(Color.unbound.surface)
                    Hexagon().strokeBorder(Color.unbound.accent, lineWidth: 1.5)
                    Image(systemName: node.isKeystone ? "shield.lefthalf.filled" : "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.unbound.accent)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(node.title)
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text({
                        if node.isMythic { return "MYTHIC NODE" }
                        if node.isKeystone { return "KEYSTONE" }
                        return node.type.rawValue.uppercased()
                    }())
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(node.isKeystone ? Color.unbound.impact : Color.unbound.accent)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("WHAT IT TAKES")
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(node.requirement.displayName.capitalized)
                    .font(Font.unbound.bodyLStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(node.subtitle)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
