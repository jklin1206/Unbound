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

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            if let node = SkillGraph.shared.node(id: nodeId) {
                ClusterStaircaseView(
                    cluster: node.cluster,
                    graph: SkillGraph.shared,
                    nodeStates: [nodeId: .proven],
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
