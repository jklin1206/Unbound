import Foundation

// MARK: - SkillDisplayTree
//
// The top-level trees shown on the Skill Map landing screen.
//
// Display trees map 1:1 to the primary training tree the user opens. The
// handstand path now owns its balance work directly instead of routing through
// a separate Handbalance umbrella.
//
// Adding a new display tree: append a case + wire it up in
// `clusters`, `displayName`, `glyph`, `tagline`, `chapterSubtitle`. The
// landing view iterates `SkillDisplayTree.allCases` in declaration order.

enum SkillDisplayTree: String, CaseIterable, Identifiable, Sendable {
    case pull
    case push
    case legs
    case coreLevers
    case handstand
    case planche

    var id: String { rawValue }

    /// The SkillCluster(s) a display tree contains. Landing-screen
    /// aggregates (progress, keystone preview, active-now chip) sum across
    /// these.
    var clusters: [SkillCluster] {
        switch self {
        case .pull:        return [.pullingPower]
        case .push:        return [.calisthenicControl]
        case .legs:        return [.legDominance]
        case .coreLevers:  return [.coreLever]
        case .handstand:   return [.handstand]
        case .planche:     return [.planche]
        }
    }

    var displayName: String {
        switch self {
        case .pull:        return "Pull"
        case .push:        return "Push"
        case .legs:        return "Legs"
        case .coreLevers:  return "Core"
        case .handstand:   return "Handstand"
        case .planche:     return "Planche"
        }
    }

    var tagline: String {
        switch self {
        case .pull:        return "Pull-up → muscle-up"
        case .push:        return "Dip → HSPU · pressing strength"
        case .legs:        return "Pistol · shrimp · Nordic"
        case .coreLevers:  return "Hollow · L-sit · dragon flag"
        case .handstand:   return "Wall → freestanding → one arm"
        case .planche:     return "Tuck → straddle → full planche"
        }
    }

    /// Short evocative chapter name shown alongside the plain display name
    /// on cluster cards and staircase headers. Italic, lighter weight — the
    /// poetic counterpart to the blunt label.
    var chapterSubtitle: String {
        switch self {
        case .pull:        return "The Ascent"
        case .push:        return "The Press"
        case .legs:        return "The Pillar"
        case .coreLevers:  return "The Spine"
        case .handstand:   return "The Inversion"
        case .planche:     return "The Float"
        }
    }

    /// SF Symbol glyph for the landing card.
    var glyph: String {
        switch self {
        case .pull:        return "figure.climbing"
        case .push:        return "figure.strengthtraining.functional"
        case .legs:        return "figure.walk"
        case .coreLevers:  return "figure.core.training"
        case .handstand:   return "figure.gymnastics"
        case .planche:     return "figure.highintensity.intervaltraining"
        }
    }

    /// True when this display tree groups multiple clusters.
    var isUmbrella: Bool { clusters.count > 1 }
}

// MARK: - Cluster → Display tree lookup

extension SkillDisplayTree {
    /// The display tree that contains a given cluster. For umbrella trees,
    /// the same tree is returned for each of its constituent sub-clusters.
    /// Used by staircase views to surface the parent umbrella's subtitle.
    static func containing(_ cluster: SkillCluster) -> SkillDisplayTree? {
        allCases.first { $0.clusters.contains(cluster) }
    }
}

// MARK: - Aggregate helpers

extension SkillDisplayTree {
    /// All nodes across every cluster in this display tree.
    func allNodes(in graph: SkillGraph) -> [SkillNode] {
        clusters.flatMap { graph.nodes(in: $0) }
    }

    /// Count of proven nodes across all clusters.
    func achievedCount(in graph: SkillGraph, states: [String: NodeState]) -> Int {
        allNodes(in: graph).reduce(into: 0) { acc, node in
            if (states[node.id] ?? .locked) == .proven { acc += 1 }
        }
    }

    /// Total node count across all clusters.
    func totalCount(in graph: SkillGraph) -> Int {
        allNodes(in: graph).count
    }

    /// The first "ready to start" node in this display tree, walked in cluster
    /// order — prereqs satisfied but not yet proven. Used for the "NOW" chip on
    /// the landing card.
    func activeNode(in graph: SkillGraph, states: [String: NodeState]) -> SkillNode? {
        for cluster in clusters {
            if let n = graph.nodes(in: cluster).first(where: { node in
                (states[node.id] ?? .locked) != .proven
                    && node.prereqsSatisfied(given: states)
            }) {
                return n
            }
        }
        return nil
    }

    /// The farthest completed node in this display tree. Landing cards use
    /// this as the compact achievement signal because terminal keystones can
    /// be years away and read oddly before the user is close to them.
    func farthestAchievement(in graph: SkillGraph, states: [String: NodeState]) -> SkillNode? {
        allNodes(in: graph)
            .filter { node in
                (states[node.id] ?? .locked) == .proven
            }
            .max { lhs, rhs in
                if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
                if lhs.placementRank != rhs.placementRank {
                    return lhs.placementRank < rhs.placementRank
                }
                if lhs.isMythic != rhs.isMythic { return !lhs.isMythic && rhs.isMythic }
                if lhs.isKeystone != rhs.isKeystone { return !lhs.isKeystone && rhs.isKeystone }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedDescending
            }
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
                if (states[ks.id] ?? .locked) != .proven {
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
