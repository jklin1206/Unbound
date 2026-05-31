import XCTest
@testable import UNBOUND

/// Locks the "dup#4" invariant.
///
/// `MovementCatalog.variantRankStandardNames` (catalog variant → canonical base
/// movement) and `StrengthStandards.compoundAliases` (movement → bw-ratio
/// compound) are SEQUENTIAL layers of one resolution pipeline, not two competing
/// maps: a logged lift is collapsed to its base (layer 1) before
/// `computeLiftRank` ranks it on a compound table (layer 2). The variant-level
/// entries in `compoundAliases` are a fallback for free-text logs.
///
/// Where a variant appears in BOTH maps, the layered path (variant → base →
/// compound) and the layer-2 fallback (variant → compound directly) must resolve
/// to the SAME compound — otherwise the strength badge and the free-text
/// fallback would rank the same lift differently. This test fails if a future
/// edit to either map makes them diverge.
final class VariantStandardConsistencyTests: XCTestCase {

    /// The two maps use different normalizers (compoundAliases preserves
    /// punctuation, variantRankStandardNames strips it). Compare on one unified
    /// punctuation-stripped key so the invariant is checked on the data, not on
    /// either map's incidental key form.
    private func key(_ value: String) -> String { MovementCatalog.normalized(value) }

    func test_variantAndCompoundMapsNeverContradict() {
        let compoundByKey = Dictionary(
            StrengthStandards.compoundAliases.map { (key($0.key), key($0.value)) },
            uniquingKeysWith: { first, _ in first }
        )

        var overlapCount = 0
        for (variantName, baseName) in MovementCatalog.variantRankStandardNames {
            let variantKey = key(variantName)
            guard let direct = compoundByKey[variantKey] else { continue } // not a shared key
            overlapCount += 1

            // Layered: the variant's canonical base, ranked as a compound.
            let layered = compoundByKey[key(baseName)]

            XCTAssertEqual(
                layered, direct,
                "dup#4 divergence — variant '\(variantName)' resolves directly to "
                + "'\(direct)', but the layered path via base '\(baseName)' resolves to "
                + "'\(layered ?? "nil")'. The two variant maps have drifted apart; "
                + "re-align them or remove the redundant compoundAliases entry."
            )
        }

        // Tripwire: if the overlap set changes, re-confirm the maps still agree.
        XCTAssertEqual(
            overlapCount, 6,
            "The variant/compound key overlap changed (was 6). Re-verify the two "
            + "maps remain consistent before updating this count."
        )
    }
}
