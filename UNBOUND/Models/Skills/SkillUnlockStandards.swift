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
        if child.isMythic || child.placementRank >= .ascendant || child.tier >= 6 {
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

        // Basic next-steps open at exposure, not clean ownership. The gate scales
        // with the child's difficulty; skipping a tier costs one extra notch.
        let base: SkillTier = child.tier <= 2 ? .initiate
            : child.tier == 3 ? .novice
            : child.tier == 4 ? .apprentice
            : .forged
        if let parent, child.tier > parent.tier + 1 {
            return SkillTier(rawValue: min(base.rawValue + 1, SkillTier.forged.rawValue)) ?? base
        }
        return base
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
        // Heavy three-strand redesign: every real feat gates on lineage + a
        // strength floor (+ a foundation hold). Each strand pinned to its tier so
        // the unlock display matches docs/rank-prereqs-redesign.html. See that doc.
        // ld.shrimp-squat
        "ld.pistol-squat->ld.shrimp-squat": .apprentice,
        "ld.deep-squat->ld.shrimp-squat": .apprentice,
        // ld.nordic-curl
        "ld.advancing-nordic-curl->ld.nordic-curl": .veteran,
        "ld.single-leg-glute-bridge->ld.nordic-curl": .forged,
        // cl.tuck-back-lever
        "cl.skin-the-cat->cl.tuck-back-lever": .apprentice,
        "pp.pullup->cl.tuck-back-lever": .apprentice,
        "cl.german-hang->cl.tuck-back-lever": .apprentice,
        // cl.straddle-back-lever
        "cl.tuck-back-lever->cl.straddle-back-lever": .forged,
        "pp.pullup->cl.straddle-back-lever": .forged,
        "cl.german-hang->cl.straddle-back-lever": .veteran,
        // cl.full-back-lever
        "cl.straddle-back-lever->cl.full-back-lever": .veteran,
        "pp.weighted-pullup->cl.full-back-lever": .veteran,
        "cl.german-hang->cl.full-back-lever": .master,
        "cl.skin-the-cat->cl.full-back-lever": .master,
        // cl.tuck-front-lever
        "pp.strict-pullup->cl.tuck-front-lever": .forged,
        "pp.decline-row->cl.tuck-front-lever": .apprentice,
        "cl.hollow-body-30->cl.tuck-front-lever": .apprentice,
        // cl.straddle-front-lever
        "cl.tuck-front-lever->cl.straddle-front-lever": .forged,
        "pp.strict-pullup->cl.straddle-front-lever": .veteran,
        "pp.decline-row->cl.straddle-front-lever": .forged,
        // cl.full-front-lever
        "cl.straddle-front-lever->cl.full-front-lever": .veteran,
        "pp.weighted-pullup->cl.full-front-lever": .veteran,
        "pp.decline-row->cl.full-front-lever": .veteran,
        "cl.hollow-body-30->cl.full-front-lever": .master,
        // pp.tuck-front-lever-pullup
        "cl.tuck-front-lever->pp.tuck-front-lever-pullup": .forged,
        "pp.one-arm-row->pp.tuck-front-lever-pullup": .forged,
        "pp.strict-pullup->pp.tuck-front-lever-pullup": .veteran,
        // pp.muscle-up
        "pp.explosive-pullup->pp.muscle-up": .forged,
        "cal.5-dips->pp.muscle-up": .forged,
        "pp.pullup->pp.muscle-up": .veteran,
        // pp.ring-muscle-up
        "pp.muscle-up->pp.ring-muscle-up": .veteran,
        "cal.ring-dip->pp.ring-muscle-up": .forged,
        // pp.strict-muscle-up
        "pp.muscle-up->pp.strict-muscle-up": .master,
        "pp.weighted-pullup->pp.strict-muscle-up": .forged,
        "cal.5-dips->pp.strict-muscle-up": .veteran,
        // pp.explosive-pullup
        "pp.strict-pullup->pp.explosive-pullup": .apprentice,
        "pp.pullup->pp.explosive-pullup": .forged,
        // pp.archer-pullup
        "pp.weighted-pullup->pp.archer-pullup": .veteran,
        "pp.pullup->pp.archer-pullup": .master,
        // pp.clapping-pullup
        "pp.explosive-pullup->pp.clapping-pullup": .master,
        "pp.pullup->pp.clapping-pullup": .veteran,
        // pp.oap-negative
        "pp.archer-pullup->pp.oap-negative": .master,
        "pp.weighted-pullup->pp.oap-negative": .master,
        // pp.one-arm-pullup
        "pp.oap-negative->pp.one-arm-pullup": .master,
        "pp.weighted-pullup->pp.one-arm-pullup": .vessel,
        "pp.archer-pullup->pp.one-arm-pullup": .veteran,
        // pp.heighted-chin-up
        "pp.weighted-chin-up->pp.heighted-chin-up": .master,
        "pp.chin-up->pp.heighted-chin-up": .veteran,
        // pp.one-arm-chin-up
        "pp.heighted-chin-up->pp.one-arm-chin-up": .master,
        "pp.weighted-chin-up->pp.one-arm-chin-up": .veteran,
        "pp.chin-up->pp.one-arm-chin-up": .master,
        // pp.weighted-pullup
        "pp.strict-pullup->pp.weighted-pullup": .forged,
        "pp.pullup->pp.weighted-pullup": .forged,
        // cl.three-sixty-pulls
        "cl.skin-the-cat->cl.three-sixty-pulls": .master,
        "cl.german-hang->cl.three-sixty-pulls": .veteran,
        // cal.pseudo-planche-pushup
        "cal.decline-pushup->cal.pseudo-planche-pushup": .apprentice,
        "cal.pushup->cal.pseudo-planche-pushup": .forged,
        // cal.archer-pushup
        "cal.decline-pushup->cal.archer-pushup": .apprentice,
        "cal.pushup->cal.archer-pushup": .forged,
        // cal.clapping-pushup
        "cal.explosive-pushup->cal.clapping-pushup": .apprentice,
        "cal.pushup->cal.clapping-pushup": .apprentice,
        // cal.one-arm-pushup
        "cal.archer-pushup->cal.one-arm-pushup": .apprentice,
        "cal.decline-pushup->cal.one-arm-pushup": .forged,
        "cal.diamond-pushup->cal.one-arm-pushup": .forged,
        // cal.pike-pushup
        "cal.diamond-pushup->cal.pike-pushup": .apprentice,
        "hs.wall-handstand-30->cal.pike-pushup": .novice,
        // cal.elevated-pike-pushup
        "cal.pike-pushup->cal.elevated-pike-pushup": .forged,
        "hs.wall-handstand-30->cal.elevated-pike-pushup": .apprentice,
        // cal.floating-pike-pushup
        "cal.elevated-pike-pushup->cal.floating-pike-pushup": .forged,
        "hs.wall-handstand-30->cal.floating-pike-pushup": .forged,
        // cal.handstand-pushup
        "cal.elevated-pike-pushup->cal.handstand-pushup": .master,
        "hs.wall-handstand-30->cal.handstand-pushup": .forged,
        "cal.pike-pushup->cal.handstand-pushup": .veteran,
        // cal.bent-arm-press
        "cal.floating-pike-pushup->cal.bent-arm-press": .master,
        "hs.wall-handstand-30->cal.bent-arm-press": .forged,
        // cal.ninety-degree-pushup
        "cal.handstand-pushup->cal.ninety-degree-pushup": .master,
        "cal.pseudo-planche-pushup->cal.ninety-degree-pushup": .master,
        "hs.wall-handstand-30->cal.ninety-degree-pushup": .veteran,
        // cal.clapping-handstand-pushup
        "cal.ninety-degree-pushup->cal.clapping-handstand-pushup": .forged,
        "cal.handstand-pushup->cal.clapping-handstand-pushup": .veteran,
        // cal.triple-clap-pushup
        "cal.clapping-pushup->cal.triple-clap-pushup": .forged,
        "cal.explosive-pushup->cal.triple-clap-pushup": .forged,
        // hs.flying-crow
        "hs.crow-pose->hs.flying-crow": .novice,
        "hs.crane-pose->hs.flying-crow": .apprentice,
        // pl.bent-arm-planche
        "hs.elbow-lever->pl.bent-arm-planche": .apprentice,
        "cal.pseudo-planche-pushup->pl.bent-arm-planche": .forged,
        "hs.crane-pose->pl.bent-arm-planche": .forged,
        // hs.one-arm-elbow-lever
        "hs.elbow-lever->hs.one-arm-elbow-lever": .veteran,
        "hs.crane-pose->hs.one-arm-elbow-lever": .veteran,
        // pl.straddle-planche
        "pl.tuck-planche->pl.straddle-planche": .master,
        "cal.pseudo-planche-pushup->pl.straddle-planche": .veteran,
        "cal.l-sit-10->pl.straddle-planche": .master,
        // pl.half-lay-planche
        "pl.straddle-planche->pl.half-lay-planche": .master,
        "cal.pseudo-planche-pushup->pl.half-lay-planche": .master,
        // pl.full-planche
        "pl.half-lay-planche->pl.full-planche": .forged,
        "cal.tuck-planche-pushup->pl.full-planche": .veteran,
        "cal.pseudo-planche-pushup->pl.full-planche": .master,
        "hs.crane-pose->pl.full-planche": .master,
        // hs.tuck-press
        "hs.tuck-handstand->hs.tuck-press": .veteran,
        "hs.freestanding-hs-30->hs.tuck-press": .apprentice,
        "cl.hollow-body-30->hs.tuck-press": .forged,
        // hs.straddle-press
        "hs.tuck-press->hs.straddle-press": .master,
        "hs.freestanding-hs-30->hs.straddle-press": .master,
        "cal.pike-pushup->hs.straddle-press": .veteran,
        // hs.press-to-handstand
        "hs.straddle-press->hs.press-to-handstand": .master,
        "hs.freestanding-hs-30->hs.press-to-handstand": .vessel,
        "cl.straddle-l-sit->hs.press-to-handstand": .master,
        // hs.wall-supported-oah
        "hs.freestanding-hs-30->hs.wall-supported-oah": .vessel,
        "hs.wall-handstand-30->hs.wall-supported-oah": .veteran,
        // oah.one-arm-handstand-5s
        "hs.wall-supported-oah->oah.one-arm-handstand-5s": .veteran,
        "hs.freestanding-hs-30->oah.one-arm-handstand-5s": .master,
        // oah.full-one-arm-handstand
        "oah.one-arm-handstand-5s->oah.full-one-arm-handstand": .master,
        "hs.wall-supported-oah->oah.full-one-arm-handstand": .master,
        // cl.dragon-flag
        "cl.dragon-flag-hip-raise->cl.dragon-flag": .forged,
        "cl.hollow-body-30->cl.dragon-flag": .forged,
        // cl.v-sit
        "cal.l-sit-10->cl.v-sit": .forged,
        "cl.hollow-body-30->cl.v-sit": .veteran,
        // cl.straddle-l-sit
        "cl.semi-straddle-l-sit->cl.straddle-l-sit": .master,
        "cal.l-sit-10->cl.straddle-l-sit": .master,
        // cl.toes-to-bar
        "cl.hanging-leg-raise->cl.toes-to-bar": .novice,
        "pp.dead-hang->cl.toes-to-bar": .apprentice,
        // pp.l-sit-chin-up
        "pp.strict-chin-up->pp.l-sit-chin-up": .apprentice,
        "cal.l-sit-10->pp.l-sit-chin-up": .forged,
        // cal.tuck-planche-pushup
        "pl.tuck-planche->cal.tuck-planche-pushup": .forged,
        "cal.pseudo-planche-pushup->cal.tuck-planche-pushup": .veteran,
        // pl.tuck-planche
        "hs.crane-pose->pl.tuck-planche": .forged,
        "cal.pseudo-planche-pushup->pl.tuck-planche": .forged,
        "cal.l-sit-10->pl.tuck-planche": .master,
        // preserved (unrelated to the redesign)
        "pp.muscle-up->pp.10-muscle-ups": .forged,
        "pp.one-arm-pullup->pp.5-oap-side": .veteran,
        "hs.wall-handstand-30->hs.freestanding-hs-10": .forged,
        "pl.full-planche->pl.full-planche-pushup": .veteran,
        "pl.full-planche->pl.one-arm-planche": .master,
        "ld.bulgarian-split-squat->ld.pistol-squat": .forged,
        "ld.pistol-squat->ld.weighted-pistol": .veteran,
    ]

    private static func note(for tier: SkillTier, child: SkillNode) -> String {
        switch tier {
        case .initiate, .novice, .apprentice:
            return "Build enough exposure to start \(child.title)."
        case .forged:
            return "Own the first clean standard before this unlocks."
        case .veteran:
            return "Show repeatable ownership before this harder branch opens."
        case .master, .vessel, .ascendant, .unbound:
            return "Prove strong ownership before this high-skill branch opens."
        }
    }
}
