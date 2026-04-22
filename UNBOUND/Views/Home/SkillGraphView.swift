import SwiftUI

// MARK: - SkillGraphView
//
// Landing screen for the Skill Map. A vertical scroll of rich cluster
// cards — one per display tree. 6 cards total:
//   • Pull
//   • Push
//   • Legs
//   • Core & Levers
//   • Handbalance (UMBRELLA — Handstand / HSPU / One-Arm)
//   • Endurance
//
// Tap behaviour:
//   • 1:1 display tree → opens ClusterStaircaseView for its cluster
//   • Umbrella (Handbalance) → opens HandbalanceSubclusterPicker
//   • Locked display tree → opens LockedClusterInfoSheet
//
// The "SKILLS TO CHASE" keystone hero row from the previous grid layout
// is gone — keystone preview is now inline on each card.

struct SkillGraphView: View {
    let graph: SkillGraph
    let nodeStates: [String: NodeState]
    var nodeProgress: [String: Double] = [:]
    var onNodeTap: (SkillNode) -> Void

    @State private var focusedCluster: SkillCluster?
    @State private var lockedInfoTree: SkillDisplayTree?
    @State private var umbrellaTree: SkillDisplayTree?

    @Bindable private var skillProgress = SkillProgressService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            cards
        }
        .sheet(item: $focusedCluster) { cluster in
            ClusterStaircaseView(
                cluster: cluster,
                graph: graph,
                nodeStates: nodeStates,
                nodeProgress: nodeProgress
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.unbound.bg)
        }
        .sheet(item: $umbrellaTree) { tree in
            HandbalanceSubclusterPicker(
                tree: tree,
                graph: graph,
                nodeStates: nodeStates,
                onPick: { cluster in
                    umbrellaTree = nil
                    // Let the dismiss animation finish before presenting
                    // the next sheet, otherwise SwiftUI will swallow it.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        focusedCluster = cluster
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.unbound.bg)
        }
        .sheet(item: $lockedInfoTree) { tree in
            if let firstCluster = tree.clusters.first,
               let required = firstCluster.requiresClusterKeystone {
                LockedClusterInfoSheet(
                    cluster: firstCluster,
                    requiredCluster: required,
                    graph: graph
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("SKILL TREES")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2.2)
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer()
            Text("\(graph.nodes.count) skills · 6 trees")
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    // MARK: - Cards

    private var cards: some View {
        VStack(spacing: 12) {
            ForEach(SkillDisplayTree.allCases) { tree in
                cardButton(tree)
            }
        }
    }

    private func cardButton(_ tree: SkillDisplayTree) -> some View {
        Button {
            handleTap(tree)
        } label: {
            ClusterCardView(
                tree: tree,
                graph: graph,
                nodeStates: nodeStates,
                skillProgress: skillProgress
            )
        }
        .buttonStyle(CardPressStyle())
    }

    // MARK: - Tap routing

    private func handleTap(_ tree: SkillDisplayTree) {
        UnboundHaptics.medium()
        if tree.isLocked(in: graph, states: nodeStates) {
            lockedInfoTree = tree
            return
        }
        if tree.isUmbrella {
            umbrellaTree = tree
            return
        }
        if let cluster = tree.clusters.first {
            focusedCluster = cluster
        }
    }
}

// MARK: - Card press style (subtle squeeze)

private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
