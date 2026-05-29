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

// Two honest states: a node is either `locked` (prereqs not met / target not
// yet hit) or `proven` (the node's target has been met). How GOOD the user is
// at a proven node is expressed by the per-skill earned `RankTier`
// (`UserSkillTierState.perSkill`), surfaced via `TierBadge` — not by NodeState.
//
// Legacy collapse: persisted `skillProgress` blobs predate this and may store
// the old 4-state raw values. The tolerant decoder below maps them so existing
// local saves decode without crashing:
//   attempting        → locked   (prereqs met but target not yet hit)
//   achieved|mastered → proven   (target hit at least once)
enum NodeState: String, Sendable {
    case locked
    case proven
}

extension NodeState: Codable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "proven", "achieved", "mastered":
            self = .proven
        // "locked", "attempting", and any unknown value fold into locked.
        default:
            self = .locked
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
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
    /// Node-ids that must all be `.proven` for this group to be satisfied.
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

    /// The stated target that defines this node. Hit once = `.proven`.
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

    /// Phase 2h: named sub-chapter within the owning cluster's tree.
    /// Nodes that share a sub-chapter render beneath a horizontal
    /// chapter divider in ClusterStaircaseView. Mythic nodes stay
    /// chapter-less — they render in the dedicated MYTHIC section.
    /// `nil` means "no chapter grouping" (default so old call sites compile).
    var subChapter: String? = nil

    /// When true, the renderer places this node at the SAME y-coordinate
    /// as its primary-parent prereq, offset horizontally — instead of one
    /// row below. Used for "parallel" chain-connected siblings on the
    /// same visual difficulty ring (e.g., Floating Pike Push-Up renders
    /// at the same y as Elevated Pike Push-Up).
    var isParallelToParent: Bool = false

    // MARK: - Phase 4.2 additions (ascension tier)
    //
    // Per-skill 9-tier criteria. Stamped at graph-init time from the cluster
    // authoring tables (CalSkillTiers, PpSkillTiers, …). Defaults to empty
    // so all existing content compiles before Phase 4.2 populates it.
    var tierCriteria: [SkillTier: TierCriterion] = [:]

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
        subChapter: String? = nil,
        isParallelToParent: Bool = false,
        tierCriteria: [SkillTier: TierCriterion] = [:]
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
            subChapter: subChapter,
            isParallelToParent: isParallelToParent,
            tierCriteria: tierCriteria
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
    /// treatment — top intrinsic difficulty (Vessel+ placement) OR the
    /// explicit `isMythic` flag. Drives the flame rank chip and impact-coloured
    /// accents wherever difficulty is rendered.
    /// Kept as a computed property so UI code reads it in one place.
    var displaysMythic: Bool { placementRank >= .vessel || isMythic }

    /// Canonical node-difficulty bucket on the 9-step RankTier scale.
    /// Maps `tier` N → `RankTier(rawValue: N)` (tier 1 → Novice … tier 8 →
    /// Unbound); tier 0 / locked clamps to `.initiate`. Out-of-range clamps
    /// into 0…8. This is the single source of truth for a node's placement.
    var placementRank: RankTier { RankTier(rawValue: min(8, max(0, tier))) ?? .initiate }

    /// True if at least ONE prerequisite group is fully satisfied by the given states,
    /// or the node has no prereqs. Matches the canonical OR-of-AND semantics used in
    /// `SkillTree.swift:246` and `SkillProgressService.swift:81–91`.
    func prereqsSatisfied(given states: [String: NodeState]) -> Bool {
        if prereqs.isEmpty { return true }
        return prereqs.contains { group in
            group.nodeIds.allSatisfy { id in
                (states[id] ?? .locked) == .proven
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
    // If the required cluster has no keystones defined, the gate stays CLOSED
    // — a cluster that requires a prereq with no achievable keystones remains
    // locked until content is added. This preserves the intended progression
    // chain even when a cluster's nodes are moved to another cluster.
    func isClusterUnlocked(_ cluster: SkillCluster, nodeStates: [String: NodeState]) -> Bool {
        guard let required = cluster.requiresClusterKeystone else { return true }
        let keystones = self.nodes.filter { $0.cluster == required && $0.isKeystone }
        guard !keystones.isEmpty else { return false }
        return keystones.allSatisfy { ks in
            (nodeStates[ks.id] ?? .locked) == .proven
        }
    }
}

// MARK: - SkillTree (legacy view-layer compatibility)
//
// The old UnboundSkillTreeTabView + SkillTreeView expect a `SkillTree`
// with nodes + a single `bossNodeId` and `rowCount`. We synthesize that
// from the full SkillGraph (universal — same tree for everyone).
//
// Chunk 4 kills this. Until then it keeps the tree tab rendering.

struct SkillTree: Codable, Sendable {
    let nodes: [SkillNode]
    let bossNodeId: String

    var rowCount: Int { (nodes.map(\.position.row).max() ?? 0) + 1 }

    /// Universal tree — all nodes from SkillGraph, repositioned by cluster.
    /// The skill tree is the same for everyone; identity comes from BuildIdentity,
    /// not a filtered subset.
    static var universal: SkillTree {
        let graph = SkillGraph.shared

        // Assign legacy positions: one column per cluster, rows stacked by tier.
        let columnOrder: [SkillCluster] = [
            .pullingPower, .legDominance,
            .calisthenicControl,
            .handstand, .handstandPushup, .oneArmHandstand,
            .planche,
            .coreLever
        ]
        var positioned: [SkillNode] = []
        for (idx, cluster) in columnOrder.enumerated() {
            let clusterNodes = graph.nodes(in: cluster)
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
                    subChapter: n.subChapter,
                    isParallelToParent: n.isParallelToParent,
                    tierCriteria: n.tierCriteria
                )
                positioned.append(repositioned)
            }
        }

        let topKeystone = positioned.first(where: { $0.isKeystone && !$0.isMythic })
        return SkillTree(
            nodes: positioned,
            bossNodeId: topKeystone?.id ?? ""
        )
    }
}
