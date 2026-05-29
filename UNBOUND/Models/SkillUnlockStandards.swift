import Foundation

// MARK: - Skill Unlock Standards
//
// Node prerequisites answer "which previous skills are connected?"
// Unlock standards answer "how owned does the previous skill need to be?"
//
// Default rule, based on the current rank ladder:
// Initiate/Novice/Apprentice = exposure and assisted progressions.
// Forged = first clean ownership of the named skill.
// Veteran/Master+ = repeatable ownership for high-risk or mythic branches.

struct SkillUnlockRequirement: Codable, Hashable, Sendable, Identifiable {
    let sourceSkillId: String
    let requiredTier: SkillTier
    let note: String
    let directProofFamily: ProofFamily
    let proofFamilyCovered: Set<ProofFamily>
    let autoClearFromHigherProof: Bool
    let safetyRequired: Bool

    var id: String { "\(sourceSkillId):\(requiredTier.rawValue)" }

    init(
        sourceSkillId: String,
        requiredTier: SkillTier,
        note: String,
        directProofFamily: ProofFamily = .form,
        proofFamilyCovered: Set<ProofFamily>? = nil,
        autoClearFromHigherProof: Bool? = nil,
        safetyRequired: Bool = false
    ) {
        self.sourceSkillId = sourceSkillId
        self.requiredTier = requiredTier
        self.note = note
        self.directProofFamily = directProofFamily
        self.proofFamilyCovered = proofFamilyCovered ?? [directProofFamily]
        self.safetyRequired = safetyRequired
        self.autoClearFromHigherProof = !safetyRequired
            && (autoClearFromHigherProof ?? directProofFamily.allowsHigherProofAutoClear)
    }
}

struct SkillUnlockRequirementGroup: Codable, Hashable, Sendable, Identifiable {
    let requirements: [SkillUnlockRequirement]

    var id: String {
        requirements.map(\.id).joined(separator: "+")
    }
}

enum SkillUnlockStandards {
    struct OutgoingUnlock: Identifiable, Hashable, Sendable {
        let child: SkillNode
        let requirement: SkillUnlockRequirement

        var id: String { "\(child.id):\(requirement.id)" }
    }

    static func groups(for node: SkillNode, in graph: SkillGraph) -> [SkillUnlockRequirementGroup] {
        node.prereqs.map { group in
            SkillUnlockRequirementGroup(
                requirements: group.nodeIds.map { parentId in
                    requirement(from: parentId, to: node, in: graph)
                }
            )
        }
    }

    static func outgoingUnlocks(from sourceSkillId: String, in graph: SkillGraph) -> [OutgoingUnlock] {
        graph.nodes
            .flatMap { child in
                groups(for: child, in: graph).flatMap { group in
                    group.requirements.compactMap { requirement -> OutgoingUnlock? in
                        guard requirement.sourceSkillId == sourceSkillId else { return nil }
                        return OutgoingUnlock(child: child, requirement: requirement)
                    }
                }
            }
            .sorted { lhs, rhs in
                if lhs.requirement.requiredTier != rhs.requirement.requiredTier {
                    return lhs.requirement.requiredTier < rhs.requirement.requiredTier
                }
                if lhs.child.tier != rhs.child.tier {
                    return lhs.child.tier < rhs.child.tier
                }
                return lhs.child.title < rhs.child.title
            }
    }

    static func requirement(from parentId: String, to child: SkillNode, in graph: SkillGraph) -> SkillUnlockRequirement {
        let tier = overrideTier(parentId: parentId, childId: child.id)
            ?? inferredTier(from: graph.node(id: parentId), to: child)
        let source = graph.node(id: parentId)
        let family = proofFamily(for: source, requiredTier: tier)
        let requiresSafetyProof = safetyRequired(source: source, child: child)

        return SkillUnlockRequirement(
            sourceSkillId: parentId,
            requiredTier: tier,
            note: note(for: tier, child: child),
            directProofFamily: family,
            proofFamilyCovered: [family],
            autoClearFromHigherProof: family.allowsHigherProofAutoClear && !requiresSafetyProof,
            safetyRequired: requiresSafetyProof
        )
    }

    static func isSatisfied(
        _ requirement: SkillUnlockRequirement,
        nodeStates: [String: NodeState],
        tierState: UserSkillTierState
    ) -> Bool {
        if tierState.tier(for: requirement.sourceSkillId) >= requirement.requiredTier {
            return true
        }

        // Compatibility while old progress saves migrate: a proven source node
        // is treated as enough for standard Forged unlocks.
        let state = nodeStates[requirement.sourceSkillId] ?? .locked
        return requirement.requiredTier <= .forged && state == .proven
    }

    private static func inferredTier(from parent: SkillNode?, to child: SkillNode) -> SkillTier {
        if child.isMythic || child.placementRank >= .unbound || child.tier >= 6 {
            return .master
        }

        let title = child.title.lowercased()
        if title.contains("strict")
            || title.contains("one-arm")
            || title.contains("one arm")
            || title.contains("full")
            || title.contains("90")
            || title.contains("ninety")
            || title.contains("clapping")
            || title.contains("triple")
            || title.contains("press to handstand") {
            return .veteran
        }

        if let parent, child.tier > parent.tier + 1 {
            return .veteran
        }

        return .forged
    }

    private static func overrideTier(parentId: String, childId: String) -> SkillTier? {
        explicitEdgeTiers["\(parentId)->\(childId)"]
    }

    private static func proofFamily(for source: SkillNode?, requiredTier: SkillTier) -> ProofFamily {
        guard let source else { return .form }
        if let criterion = source.tierCriteria[requiredTier] {
            return ProofFamily.inferred(from: criterion)
        }
        return ProofFamily.inferred(from: source.target)
    }

    private static func safetyRequired(source: SkillNode?, child: SkillNode) -> Bool {
        guard let source else { return false }
        if source.isMythic || child.isMythic { return true }

        let joinedText = [
            source.title,
            child.title,
            source.target.displayName,
            child.target.displayName,
            source.formCues.joined(separator: " "),
            child.formCues.joined(separator: " ")
        ]
        .joined(separator: " ")
        .lowercased()

        return joinedText.contains("pain-free")
            || joinedText.contains("pain free")
            || joinedText.contains("mobility")
            || joinedText.contains("wrist")
            || joinedText.contains("shoulder")
            || joinedText.contains("strict form")
            || joinedText.contains("controlled")
    }

    private static let explicitEdgeTiers: [String: SkillTier] = [
        // Pull crossover: a normal muscle-up unlocks volume earlier, but ring
        // and strict work need repeatable ownership first.
        "pp.muscle-up->pp.10-muscle-ups": .forged,
        "pp.muscle-up->pp.ring-muscle-up": .veteran,
        "pp.ring-muscle-up->pp.strict-muscle-up": .master,

        // One-arm pulling should not open from a lucky first rep.
        "pp.archer-pullup->pp.one-arm-pullup-negative": .veteran,
        "pp.weighted-pullup->pp.one-arm-pullup": .master,
        "pp.one-arm-pullup->pp.5-oap-side": .veteran,

        // Handstand line: wall work opens freestanding practice at ownership,
        // but one-arm work waits until the full handstand path is repeatable.
        "hs.wall-handstand-30->hs.freestanding-hs-10": .forged,
        "hs.freestanding-hs-30->hs.wall-supported-oah": .master,
        "hs.wall-supported-oah->oah.one-arm-handstand-5s": .veteran,
        "oah.one-arm-handstand-5s->oah.full-one-arm-handstand": .master,

        // Planche: the next lever opens at ownership; elite dynamic branches
        // require repeatable control.
        "pl.tuck-planche->pl.tuck-planche-pushup": .forged,
        "pl.straddle-planche->pl.full-planche": .veteran,
        "pl.full-planche->pl.full-planche-pushup": .veteran,
        "pl.full-planche->pl.one-arm-planche": .master,
        "pl.straddle-planche->pl.bent-arm-planche": .veteran,
        "pl.half-lay-planche->pl.full-planche": .forged,

        // Lever families: straight-arm static ownership before harder lever
        // length, repeatable ownership before dynamic or mythic work.
        "cl.tuck-front-lever->cl.straddle-front-lever": .forged,
        "cl.straddle-front-lever->cl.full-front-lever": .veteran,
        "cl.skin-the-cat->cl.straddle-back-lever": .forged,
        "cl.straddle-back-lever->cl.full-back-lever": .veteran,
        "cl.skin-the-cat->cl.three-sixty-pulls": .master,

        // Legs: loaded/explosive variants wait until the base pattern is owned.
        "ld.bulgarian-split-squat->ld.pistol-squat": .forged,
        "ld.pistol-squat->ld.weighted-pistol": .veteran,
        "ld.advancing-nordic-curl->ld.nordic-curl": .veteran,
    ]

    private static func note(for tier: SkillTier, child: SkillNode) -> String {
        switch tier {
        case .initiate, .novice, .apprentice:
            return "Build enough exposure to start \(child.title)."
        case .forged:
            return "Own the first clean standard before this unlocks."
        case .veteran:
            return "Show repeatable ownership before this harder branch opens."
        case .master, .vessel, .unbound, .ascendant:
            return "Prove strong ownership before this high-skill branch opens."
        }
    }
}
