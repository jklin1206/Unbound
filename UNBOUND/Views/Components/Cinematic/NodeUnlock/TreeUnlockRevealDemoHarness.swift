import SwiftUI

#if DEBUG
// MARK: - TreeUnlockRevealDemoHarness
//
// DEBUG-only harness to screenshot the in-tree unlock reveal in isolation.
// Launch with `-treeUnlockDemo`; pick the node with env `NODE_UNLOCK_DEMO_NODE`
// (default pp.muscle-up). Opens the node's real cluster tree focused on it and
// plays the fly-to + ignite, then loops so it can be re-captured.

struct TreeUnlockRevealDemoHarness: View {
    @State private var replayId = 0

    private var nodeId: String {
        ProcessInfo.processInfo.environment["NODE_UNLOCK_DEMO_NODE"] ?? "pp.muscle-up"
    }

    /// Mark the unlock node and all its ancestors proven, like a real account
    /// would be (you cleared the lead-up to unlock it).
    private func provenChain(to target: String) -> [String: NodeState] {
        var states: [String: NodeState] = [:]
        var frontier = [target]
        var depth = 0
        while !frontier.isEmpty && depth < 16 {
            var next: [String] = []
            for id in frontier where states[id] == nil {
                states[id] = .proven
                if let node = SkillGraph.shared.node(id: id) {
                    for group in node.prereqs { next.append(contentsOf: group.nodeIds) }
                }
            }
            frontier = next
            depth += 1
        }
        return states
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            if let node = SkillGraph.shared.node(id: nodeId) {
                ClusterStaircaseView(
                    cluster: node.cluster,
                    graph: SkillGraph.shared,
                    nodeStates: provenChain(to: nodeId),
                    nodeProgress: [:],
                    unlockRevealNodeId: nodeId,
                    revealFreeze: ProcessInfo.processInfo.environment["TREE_UNLOCK_FREEZE"] == "1",
                    onUnlockRevealFinished: {
                        // Loop the demo for repeated capture.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            replayId += 1
                        }
                    }
                )
                .id(replayId)
            } else {
                Text("Unknown node: \(nodeId)")
                    .foregroundStyle(Color.unbound.textPrimary)
            }
        }
    }
}
#endif
