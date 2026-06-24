import SwiftUI

// MARK: - Skill unlock tree reveal
//
// Presents the in-tree unlock reveal (ClusterStaircaseView focused on the
// freshly-proven node) as a full-screen cover, driven by
// SkillProgressService.pendingUnlock.
//
// Mounted once near the root (HomeTabView). Because the cover is presented from
// an ancestor of the workout/reward covers, SwiftUI holds it until those
// dismiss — so it auto-opens once the user lands back on home after a workout,
// flies to the node, ignites it, and returns on Continue. Mirrors the
// RankUpCinematicPresenter pattern.

extension View {
    func skillUnlockTreeReveal() -> some View {
        modifier(SkillUnlockTreeRevealPresenter())
    }
}

private struct SkillUnlockTreeRevealPresenter: ViewModifier {
    @Bindable private var service = SkillProgressService.shared

    func body(content: Content) -> some View {
        content.fullScreenCover(item: $service.pendingUnlock) { event in
            SkillUnlockTreeRevealCover(event: event) {
                service.clearPendingUnlock()
            }
        }
    }
}

private struct SkillUnlockTreeRevealCover: View {
    let event: NodeUnlockedEvent
    let onFinish: () -> Void

    @Bindable private var progress = SkillProgressService.shared

    var body: some View {
        ClusterStaircaseView(
            cluster: event.node.cluster,
            graph: SkillGraph.shared,
            nodeStates: liveStates(),
            nodeProgress: progress.nodeProgress,
            unlockRevealNodeId: event.node.id,
            onUnlockRevealFinished: onFinish
        )
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    private func liveStates() -> [String: NodeState] {
        var states = progress.nodeStates
        for node in SkillGraph.shared.nodes where states[node.id] == nil {
            states[node.id] = .locked
        }
        return states
    }
}
