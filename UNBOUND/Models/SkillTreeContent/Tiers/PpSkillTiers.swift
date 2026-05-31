// UNBOUND/Models/SkillTreeContent/Tiers/PpSkillTiers.swift
//
// Tier criteria for the pull family (pp.*, 26 skills) — GENERATED from real-data
// anchors (PullSkillAnchors + SkillTierGenerator), replacing the old hand-authored
// 9-tier-per-node tables (the source of the distribution mess). Grind moves spread
// real strengthlevel standards across the 9 tiers; hard feats start high (the first
// rep jumps to a floor rank, ranks below are "not yet"). The node's difficulty
// (SkillNode.tier, used by trials) is unchanged — only the per-node rank ladder is
// generated here. See docs/pull-rank-ladders-review.md + docs/strength-standards-harvest.md.

import Foundation

#if DEBUG
private let _ppCountCheck: Int = {
    assert(
        PpSkillTiers.table.count == 26,
        "pp cluster should have 26 entries, has \(PpSkillTiers.table.count)"
    )
    for (id, tiers) in PpSkillTiers.table {
        assert(tiers.count == 9, "\(id) needs 9 tiers, has \(tiers.count)")
        for tier in SkillTier.allCases {
            assert(tiers[tier] != nil, "\(id) missing tier \(tier)")
        }
    }
    return PpSkillTiers.table.count
}()
#endif

enum PpSkillTiers {
    /// Generated from `PullSkillAnchors` — each anchor's real-data ladder → 9 tiers.
    static let table: [String: [SkillTier: TierCriterion]] =
        PullSkillAnchors.table.mapValues { SkillTierGenerator.generate($0) }
}
