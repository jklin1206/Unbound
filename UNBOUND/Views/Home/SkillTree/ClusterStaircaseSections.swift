import SwiftUI
import UIKit

extension ClusterStaircaseView {
    struct StaircaseSections {
        var achieved: [SkillNode]
        var active: SkillNode?
        var next: [SkillNode]
        var keystone: SkillNode?
        var keystoneIsActive: Bool
        var mythic: [SkillNode]
    }

    func buildSections() -> StaircaseSections {
        let nodes = clusterNodes
        let nodeById = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let tiers = computeEffectiveTiers(nodes: nodes)

        func state(_ n: SkillNode) -> NodeState { nodeStates[n.id] ?? .locked }

        let keystone = nodes.first { $0.isKeystone && !$0.isMythic }
        let mythicNodes = nodes.filter { $0.isMythic }
        let keystoneUnlocked = keystone.map { isUnlockedState(state($0)) } ?? false

        let achievedAll = nodes
            .filter { !$0.isMythic && $0.id != keystone?.id }
            .filter { isUnlockedState(state($0)) }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }
        let achieved = Array(achievedAll.suffix(2))

        // "Active" = the next unproven node whose prereqs are satisfied
        // (the old `.attempting` concept, now derived rather than stored).
        let unlockables = nodes
            .filter { state($0) == .locked }
            .filter { $0.prereqsSatisfied(given: nodeStates) }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }
        var activeNode: SkillNode? = unlockables.first
        if activeNode == nil { activeNode = keystone }

        let keystoneIsActive = (activeNode?.id == keystone?.id) && keystone != nil

        let ancestorIds: Set<String> = keystone
            .map { keystoneAncestors(keystone: $0, nodeById: nodeById) }
            ?? []

        let nextCandidates = nodes
            .filter { !$0.isMythic }
            .filter { $0.id != keystone?.id }
            .filter { $0.id != activeNode?.id }
            .filter { !isUnlockedState(state($0)) }
            .filter { node in
                if ancestorIds.contains(node.id) { return true }
                if node.prereqsSatisfied(given: nodeStates) { return true }
                return false
            }
            .sorted {
                let ta = tiers[$0.id] ?? $0.tier
                let tb = tiers[$1.id] ?? $1.tier
                if ta != tb { return ta < tb }
                return $0.id < $1.id
            }
        let next = Array(nextCandidates.prefix(5))

        // Mythics now render inline in the main tree as the deepest tier,
        // so the dedicated MYTHIC section below the tree is empty.
        let mythic: [SkillNode] = []
        _ = mythicNodes
        _ = keystoneUnlocked

        return StaircaseSections(
            achieved: achieved,
            active: activeNode,
            next: next,
            keystone: keystone,
            keystoneIsActive: keystoneIsActive,
            mythic: mythic
        )
    }

    func keystoneAncestors(
        keystone: SkillNode,
        nodeById: [String: SkillNode]
    ) -> Set<String> {
        var ancestors: Set<String> = [keystone.id]
        var queue: [String] = [keystone.id]
        while let currentId = queue.popLast() {
            guard let node = nodeById[currentId] else { continue }
            let prereqIds = node.prereqs.flatMap { $0.nodeIds }
            for pid in prereqIds where nodeById[pid] != nil && !ancestors.contains(pid) {
                ancestors.insert(pid)
                queue.append(pid)
            }
        }
        return ancestors
    }

    // MARK: - Effective tier

    func computeEffectiveTiers(nodes: [SkillNode]) -> [String: Int] {
        let nodeById = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        var cache: [String: Int] = [:]
        var inProgress: Set<String> = []

        func depth(_ id: String) -> Int {
            if let cached = cache[id] { return cached }
            guard let node = nodeById[id] else { return 1 }
            if inProgress.contains(id) { return node.tier }
            inProgress.insert(id)
            defer { inProgress.remove(id) }

            let within = node.prereqs.flatMap { $0.nodeIds }
                .filter { nodeById[$0] != nil }
            let d: Int
            if within.isEmpty {
                d = 1
            } else {
                let maxPrereqDepth = within.map { depth($0) }.max() ?? 0
                d = maxPrereqDepth + 1
            }
            cache[id] = d
            return d
        }

        for node in nodes { _ = depth(node.id) }
        return cache
    }

    // MARK: - Helpers

    func isUnlockedState(_ s: NodeState) -> Bool {
        s == .proven
    }
}
