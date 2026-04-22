import Foundation

// MARK: - Skill graph model (v3)
//
// One shared SkillGraph for all users. Nodes are tagged with a cluster,
// a tier (1-7 where 7 = Mythic), and flags for keystone/mythic status.
// Archetype identity emerges from which nodes are seeded as `.attempting`
// at spawn (see ArchetypeSpawnPoints).
//
// 4-state progression kept intact: locked → attempting → achieved → mastered.
// Volume benchmarks (1 muscle-up vs 10 muscle-ups) are MODELED AS SEPARATE
// NODES rather than rep sub-states. Keeps the state machine tiny and every
// node has exactly one clear target.
//
// Prerequisites support OR-logic: a node may have multiple PrerequisiteGroups,
// and satisfying ANY of them opens the node. Inside a group, ALL node-ids
// must be achieved.
//
// The old SkillTree per-archetype wrapper is kept as a compatibility view
// over SkillGraph — callers that haven't migrated to SkillGraph yet still
// compile. Chunk 4 replaces the legacy view entirely.

// MARK: Node type

enum NodeType: String, Codable, Sendable {
    case strength   // barbell / weighted movement
    case skill      // bodyweight reps / dynamic
    case hold       // static isometric hold
}

// MARK: Node state

enum NodeState: String, Codable, Sendable {
    case locked       // prerequisites not met
    case attempting   // prereqs met, target not yet hit
    case achieved     // target hit once
    case mastered     // target hit at 2× (or sustained over 2+ sessions for boss-style nodes)
}

// MARK: Requirement

indirect enum NodeRequirement: Codable, Hashable, Sendable {
    case weightMultiplier(exercise: String, multiplier: Double)
    case reps(exercise: String, count: Int, load: String? = nil)
    case hold(exercise: String, seconds: Int)
    case steps(exercise: String, count: Int)
    case carry(exercise: String, seconds: Int, load: String)
    case composite([NodeRequirement])

    var displayName: String {
        switch self {
        case .weightMultiplier(let exercise, let mult):
            let fmt = mult == floor(mult) ? "\(Int(mult))x" : String(format: "%.2gx", mult)
            return "\(fmt) bw \(exercise)"
        case .reps(let exercise, let count, let load):
            if let load { return "\(count) \(exercise) @ \(load)" }
            return "\(count) \(exercise)"
        case .hold(let exercise, let seconds):
            return "\(exercise) \(seconds)s"
        case .steps(let exercise, let count):
            return "\(count) \(exercise) steps"
        case .carry(let exercise, let seconds, let load):
            return "\(exercise) \(load) × \(seconds)s"
        case .composite(let reqs):
            return reqs.map(\.displayName).joined(separator: " + ")
        }
    }
}

// MARK: Prerequisite group (OR-across-groups, AND-within-a-group)

struct PrerequisiteGroup: Codable, Hashable, Sendable {
    /// Node-ids that must all be `.achieved` or `.mastered` for this
    /// group to be satisfied.
    let nodeIds: [String]

    init(_ ids: [String]) { self.nodeIds = ids }
    init(_ ids: String...) { self.nodeIds = Array(ids) }
}

// MARK: Grid position (legacy, used until Chunk 4 ships SkillGraphView)

struct NodeGridPosition: Codable, Hashable, Sendable {
    let row: Int
    let column: Int   // 0 = center, -1 = left branch, +1 = right branch

    static let zero = NodeGridPosition(row: 0, column: 0)
}

// MARK: Node

struct SkillNode: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let cluster: SkillCluster
    let tier: Int                      // 1 = Novice, 6 = Elite, 7 = Mythic
    let type: NodeType
    let isKeystone: Bool               // renders larger + violet outer ring
    let isMythic: Bool                 // implies isKeystone; gold stroke + LEGENDARY chip

    /// The stated target that defines this node. Hit once = .achieved,
    /// hit 2× = .mastered.
    let target: NodeRequirement

    /// OR-across-groups, AND-within-a-group. Empty = entry node.
    let prereqs: [PrerequisiteGroup]

    // Equipment & anatomy
    let equipment: [SkillEquipment]
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]

    // Teaching metadata
    let description: String
    let formCues: [String]
    let commonMistakes: [String]
    let timelineEstimate: String
    let glyph: String                  // SF Symbol

    // Legacy layout — Chunk 4 ships cluster-based positioning and drops this
    let position: NodeGridPosition

    // MARK: - Phase 1a additions (skill-tree redesign)
    //
    // `rank` and `levels` are introduced so every node can carry an
    // E/D/C/B/A/S difficulty tier and a 1-5 XP-gated ladder. Both default
    // so existing content in SkillTreeContent.swift keeps compiling — the
    // Phase 1c migration populates real values per node.

    /// Difficulty tier shown on the node chip. Defaults to `.d`.
    var rank: SkillRank = .d

    /// Ordered 1-5 ladder. Empty until Phase 1c content migration.
    var levels: [SkillLevel] = []

    /// Phase 2h: named sub-chapter within the owning cluster's tree.
    /// Nodes that share a sub-chapter render beneath a horizontal
    /// chapter divider in ClusterStaircaseView. Mythic nodes stay
    /// chapter-less — they render in the dedicated MYTHIC section.
    /// `nil` means "no chapter grouping" (default so old call sites compile).
    var subChapter: String? = nil

    static func == (lhs: SkillNode, rhs: SkillNode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: Back-compat shim
    //
    // Old content used `requirement` as the only requirement field.
    // Views display it via `displayName`. Keep the property forwarding
    // so SkillNodeDetailSheet and similar keep rendering.
    var requirement: NodeRequirement { target }

    // MARK: Convenience constructor

    static func simple(
        id: String,
        title: String,
        cluster: SkillCluster,
        tier: Int,
        type: NodeType,
        target: NodeRequirement,
        prereqs: [PrerequisiteGroup] = [],
        isKeystone: Bool = false,
        isMythic: Bool = false,
        equipment: [SkillEquipment] = [.bodyweight],
        primary: [MuscleGroup] = [],
        secondary: [MuscleGroup] = [],
        subtitle: String = "",
        description: String = "",
        formCues: [String] = [],
        commonMistakes: [String] = [],
        timeline: String = "",
        glyph: String? = nil,
        position: NodeGridPosition = .zero,
        rank: SkillRank = .d,
        levels: [SkillLevel] = [],
        subChapter: String? = nil
    ) -> SkillNode {
        SkillNode(
            id: id,
            title: title,
            subtitle: subtitle,
            cluster: cluster,
            tier: tier,
            type: type,
            isKeystone: isKeystone || isMythic,
            isMythic: isMythic,
            target: target,
            prereqs: prereqs,
            equipment: equipment,
            primaryMuscles: primary,
            secondaryMuscles: secondary,
            description: description,
            formCues: formCues,
            commonMistakes: commonMistakes,
            timelineEstimate: timeline,
            glyph: glyph ?? defaultGlyph(for: type, isMythic: isMythic),
            position: position,
            rank: rank,
            levels: levels,
            subChapter: subChapter
        )
    }

    private static func defaultGlyph(for type: NodeType, isMythic: Bool) -> String {
        if isMythic { return "star.circle.fill" }
        switch type {
        case .strength: return "dumbbell.fill"
        case .skill:    return "figure.strengthtraining.functional"
        case .hold:     return "figure.mind.and.body"
        }
    }
}

// MARK: - SkillNode helpers

extension SkillNode {
    /// True when this node deserves the "mythic / life pursuit" visual
    /// treatment — S-rank OR the explicit `isMythic` flag. Drives the flame
    /// rank chip and impact-coloured accents wherever rank is rendered.
    /// Kept as a computed property so UI code reads it in one place.
    var displaysMythic: Bool { rank == .s || isMythic }

    /// True if at least ONE prerequisite group is fully satisfied by the given states,
    /// or the node has no prereqs. Matches the canonical OR-of-AND semantics used in
    /// `SkillTree.swift:246` and `SkillProgressService.swift:81–91`.
    func prereqsSatisfied(given states: [String: NodeState]) -> Bool {
        if prereqs.isEmpty { return true }
        return prereqs.contains { group in
            group.nodeIds.allSatisfy { id in
                let s = states[id] ?? .locked
                return s == .achieved || s == .mastered
            }
        }
    }
}

// MARK: - SkillGraph (the unified v3 source of truth)

struct SkillGraph: Codable, Sendable {
    let nodes: [SkillNode]

    func node(id: String) -> SkillNode? {
        nodes.first { $0.id == id }
    }

    func nodes(in cluster: SkillCluster) -> [SkillNode] {
        nodes.filter { $0.cluster == cluster }
    }

    var keystones: [SkillNode] {
        nodes.filter { $0.isKeystone && !$0.isMythic }
    }

    var mythics: [SkillNode] {
        nodes.filter { $0.isMythic }
    }

    var entryNodes: [SkillNode] {
        nodes.filter { $0.prereqs.isEmpty }
    }

    // MARK: - Cluster unlock gating
    //
    // Some clusters (e.g. HSPU, One-Arm Handstand) are staged behind the
    // keystone(s) of a prerequisite cluster. Returns true when the cluster
    // has no prereq or all keystones of its prereq cluster are achieved.
    // If the required cluster has no keystones defined yet, we fail open
    // (treat as unlocked) so POC content gaps never soft-brick the UI.
    func isClusterUnlocked(_ cluster: SkillCluster, nodeStates: [String: NodeState]) -> Bool {
        guard let required = cluster.requiresClusterKeystone else { return true }
        let keystones = self.nodes.filter { $0.cluster == required && $0.isKeystone }
        guard !keystones.isEmpty else { return true }
        return keystones.allSatisfy { ks in
            let state = nodeStates[ks.id] ?? .locked
            return state == .achieved || state == .mastered
        }
    }
}

// MARK: - SkillTree (legacy view-layer compatibility)
//
// The old UnboundSkillTreeTabView + SkillTreeView expect a `SkillTree`
// with nodes + a single `bossNodeId` and `rowCount`. We synthesize that
// from SkillGraph filtered to an archetype's spawn reach.
//
// Chunk 4 kills this. Until then it keeps the tree tab rendering.

struct SkillTree: Codable, Sendable {
    let archetype: Archetype
    let nodes: [SkillNode]
    let bossNodeId: String

    var displayName: String { archetype.shortName }
    var rowCount: Int { (nodes.map(\.position.row).max() ?? 0) + 1 }

    /// Legacy API — returns the per-archetype "reachable" slice of the
    /// shared SkillGraph. Nodes are re-positioned column-by-cluster so
    /// the old SkillTreeView lays them out coherently.
    static func tree(for archetype: Archetype) -> SkillTree {
        let graph = SkillGraph.shared
        let spawnIds = Set(ArchetypeSpawnPoints.nodeIds(for: archetype))

        // Compute reachable set via fixed-point iteration on OR-groups.
        var reachable: Set<String> = spawnIds
        var changed = true
        while changed {
            changed = false
            for node in graph.nodes where !reachable.contains(node.id) {
                guard !node.prereqs.isEmpty else { continue }
                let any = node.prereqs.contains { group in
                    group.nodeIds.allSatisfy { reachable.contains($0) }
                }
                if any {
                    reachable.insert(node.id)
                    changed = true
                }
            }
        }

        // Assign legacy positions: one column per cluster, rows stacked by tier.
        let columnOrder: [SkillCluster] = [
            .pullingPower, .legDominance,
            .calisthenicControl,
            .handstand, .handstandPushup, .oneArmHandstand,
            .planche,
            .coreLever, .conditioning
        ]
        var positioned: [SkillNode] = []
        for (idx, cluster) in columnOrder.enumerated() {
            let clusterNodes = graph.nodes(in: cluster)
                .filter { reachable.contains($0.id) }
                .sorted { $0.tier < $1.tier }
            for (row, n) in clusterNodes.enumerated() {
                let repositioned = SkillNode(
                    id: n.id, title: n.title, subtitle: n.subtitle,
                    cluster: n.cluster, tier: n.tier, type: n.type,
                    isKeystone: n.isKeystone, isMythic: n.isMythic,
                    target: n.target, prereqs: n.prereqs,
                    equipment: n.equipment,
                    primaryMuscles: n.primaryMuscles,
                    secondaryMuscles: n.secondaryMuscles,
                    description: n.description,
                    formCues: n.formCues,
                    commonMistakes: n.commonMistakes,
                    timelineEstimate: n.timelineEstimate,
                    glyph: n.glyph,
                    position: NodeGridPosition(row: row, column: idx - columnOrder.count / 2),
                    rank: n.rank,
                    levels: n.levels,
                    subChapter: n.subChapter
                )
                positioned.append(repositioned)
            }
        }

        let topKeystone = positioned.first(where: { $0.isKeystone && !$0.isMythic })
        return SkillTree(
            archetype: archetype,
            nodes: positioned,
            bossNodeId: topKeystone?.id ?? ""
        )
    }
}
