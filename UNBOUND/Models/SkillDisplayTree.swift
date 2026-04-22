import Foundation

// MARK: - SkillDisplayTree
//
// The 6 top-level trees shown on the Skill Map landing screen.
//
// Most display trees map 1:1 to a `SkillCluster`. Handbalance is the lone
// UMBRELLA — it groups the three sub-clusters (.handstand, .handstandPushup,
// .oneArmHandstand) into one landing card. The per-cluster staircase views
// still operate on sub-clusters individually; the umbrella is only a display
// grouping so the landing screen shows a stable set of six trees.
//
// Adding a new display tree: append a case + wire it up in
// `clusters`, `displayName`, `glyph`, `tagline`. The landing view iterates
// `SkillDisplayTree.allCases` in declaration order.

enum SkillDisplayTree: String, CaseIterable, Identifiable, Sendable {
    case pull
    case push
    case legs
    case coreLevers
    case handbalance  // UMBRELLA: handstand + HSPU + one-arm handstand
    case endurance

    var id: String { rawValue }

    /// The SkillCluster(s) a display tree contains. Landing-screen
    /// aggregates (progress, keystone preview, active-now chip) sum across
    /// these. Ordered — for the umbrella this dictates stage priority
    /// (handstand first, then HSPU, then one-arm).
    var clusters: [SkillCluster] {
        switch self {
        case .pull:        return [.pullingPower]
        case .push:        return [.calisthenicControl]
        case .legs:        return [.legDominance]
        case .coreLevers:  return [.coreLever]
        case .handbalance: return [.handstand, .handstandPushup, .oneArmHandstand]
        case .endurance:   return [.conditioning]
        }
    }

    var displayName: String {
        switch self {
        case .pull:        return "Pull"
        case .push:        return "Push"
        case .legs:        return "Legs"
        case .coreLevers:  return "Core & Levers"
        case .handbalance: return "Handbalance"
        case .endurance:   return "Endurance"
        }
    }

    var tagline: String {
        switch self {
        case .pull:        return "Pull-up → muscle-up"
        case .push:        return "Dip → HSPU → planche"
        case .legs:        return "Pistol · shrimp · Nordic"
        case .coreLevers:  return "Hollow · L-sit · front lever"
        case .handbalance: return "Balance upside down"
        case .endurance:   return "Carries · hangs · grip"
        }
    }

    /// SF Symbol glyph for the landing card.
    var glyph: String {
        switch self {
        case .pull:        return "figure.climbing"
        case .push:        return "figure.strengthtraining.functional"
        case .legs:        return "figure.walk"
        case .coreLevers:  return "figure.core.training"
        case .handbalance: return "figure.gymnastics"
        case .endurance:   return "flame.fill"
        }
    }

    /// True when this display tree groups multiple clusters (i.e. the user
    /// has to pick which sub-staircase to drill into).
    var isUmbrella: Bool { clusters.count > 1 }
}

// MARK: - Aggregate helpers

extension SkillDisplayTree {
    /// All nodes across every cluster in this display tree.
    func allNodes(in graph: SkillGraph) -> [SkillNode] {
        clusters.flatMap { graph.nodes(in: $0) }
    }

    /// Count of achieved/mastered nodes across all clusters.
    func achievedCount(in graph: SkillGraph, states: [String: NodeState]) -> Int {
        allNodes(in: graph).reduce(into: 0) { acc, node in
            let s = states[node.id] ?? .locked
            if s == .achieved || s == .mastered { acc += 1 }
        }
    }

    /// Total node count across all clusters.
    func totalCount(in graph: SkillGraph) -> Int {
        allNodes(in: graph).count
    }

    /// The first `.attempting` node in this display tree, walked in cluster
    /// order. Used for the "NOW" chip on the landing card.
    func activeNode(in graph: SkillGraph, states: [String: NodeState]) -> SkillNode? {
        for cluster in clusters {
            if let n = graph.nodes(in: cluster).first(where: { states[$0.id] == .attempting }) {
                return n
            }
        }
        return nil
    }

    /// The keystone preview for the landing card. Walks clusters in order
    /// and returns the first keystone that is NOT yet achieved. If every
    /// keystone is achieved, returns the terminal keystone of the last
    /// cluster.
    func previewKeystone(in graph: SkillGraph, states: [String: NodeState]) -> SkillNode? {
        var terminalKeystone: SkillNode?
        for cluster in clusters {
            let keystones = graph.nodes(in: cluster).filter { $0.isKeystone && !$0.isMythic }
            for ks in keystones {
                let s = states[ks.id] ?? .locked
                if s != .achieved && s != .mastered {
                    return ks
                }
                terminalKeystone = ks
            }
        }
        return terminalKeystone
    }

    /// Entire display tree is locked when EVERY cluster in it is gated and
    /// the gate has not been met. For umbrellas, we treat the tree as
    /// unlocked if at least the first cluster (stage 1) is reachable.
    func isLocked(in graph: SkillGraph, states: [String: NodeState]) -> Bool {
        guard let first = clusters.first else { return false }
        return !graph.isClusterUnlocked(first, nodeStates: states)
    }

    /// For locked state — name the required cluster (used for the "REQUIRES"
    /// caption on dimmed cards).
    func requiredClusterName(for cluster: SkillCluster? = nil) -> String? {
        let target = cluster ?? clusters.first
        return target?.requiresClusterKeystone?.displayName
    }
}
