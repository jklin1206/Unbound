import Foundation

// MARK: - MovementResolution
//
// Single source for the small, shared pieces of movement-name resolution that
// were copied across the ranking code:
//
//   • regressionTerms — the variation prefixes that make a logged movement a
//     REGRESSION of its parent (an assisted / banded / negative pull-up can't
//     prove a strict pull-up). Was duplicated verbatim in MovementProofMatcher
//     and RankService.
//   • normalizedKey — the simple trim+lowercase key normalizer used by the lift
//     rank paths. Was duplicated in StrengthStandards.normalize and
//     RankService.normalizedKey.
//
// NOTE: `MovementCatalog.normalized` is a DIFFERENT, richer normalizer (it also
// strips punctuation for catalog name matching) — intentionally not folded in.
//
// `MovementCatalog.variantRankStandardNames` and
// `StrengthStandards.compoundAliases` are NOT a duplicate pair (the original
// audit mislabeled them dup#4): they are two SEQUENTIAL layers of variant
// resolution — variant → canonical base (layer 1), then base → bw-ratio
// compound (layer 2) — and they resolve into different namespaces (a movement
// id vs a ratio-table key), so they can't be one map. Where a variant appears
// in both, the layered path and the layer-2 fallback entry resolve to the same
// compound; `VariantStandardConsistencyTests` locks that so they can never
// silently diverge.

enum MovementResolution {

    /// Variation prefixes marking a logged movement as a regression of its
    /// parent standard. Consumers keep their own matching predicate; only the
    /// list is shared.
    static let regressionTerms: [String] = [
        "assisted",
        "band",
        "banded",
        "machine",
        "negative",
        "jumping",
        "eccentric",
        "partial"
    ]

    /// Simple key normalizer: trim + lowercase, punctuation preserved.
    static func normalizedKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
