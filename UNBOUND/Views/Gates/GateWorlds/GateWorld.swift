import SwiftUI

/// The living-world element each gate's active layer animates. Plan 2 renders a
/// generic treatment for all of them (DefaultGateVisualizer); Plan 4 ships eight
/// bespoke GateVisualizer plugins keyed off this.
enum GateWorldElement: String, Equatable, Sendable {
    case lanterns   // I   — courtyard lanterns ignite
    case bell       // II  — the dojo bell
    case forge      // III — blade glows hotter, the quench
    case deck       // IV  — the road-worn deck
    case ascent     // V   — altitude rising through cloud
    case seals      // VI  — ritual circles shatter
    case siege      // VII — the portal opens across the trial
    case landings   // VIII— golden stairway landings
}

/// Declarative theme for one rank gate. Derives all visuals from the destination
/// rank so a balance/rename in the engine flows through automatically. Art is the
/// existing rank banner in Plan 2 (spec §3); Plan 3 swaps bespoke threshold art
/// behind `bannerAssetName`.
struct GateWorld: Identifiable, Equatable, Sendable {
    let format: RankTrialFormat
    let numeral: String           // "I" … "VIII"
    let order: Int                // 1 … 8
    let promise: String           // one-line, world-language, non-negging
    let beatVerb: String          // station-clear beat verb ("lit", "struck", …)
    let destinationRank: RankTitle
    let element: GateWorldElement

    var id: RankTrialFormat { format }
    var trialName: String { format.displayName }
    var difficultyPips: Int { order }

    /// Foreground-safe tint for text/icons on dark UI.
    var tint: Color { destinationRank.rewardTextTint }
    /// Saturated fill tint for sigils, progress fills, stamps.
    var fillTint: Color { destinationRank.rewardTint }
    /// The gate's threshold art (Plan 3, bespoke anime-JRPG `gate_threshold_<token>`),
    /// falling back to the rank banner cosmetic if a bespoke still is missing.
    var bannerAssetName: String {
        let threshold = "gate_threshold_\(destinationRank.token)"
        return UIImage(named: threshold) != nil ? threshold : "profile_banner_\(destinationRank.token)"
    }

    /// "FORGED → VETERAN" style transition label.
    func transitionLabel(from origin: RankTitle) -> String {
        "\(origin.displayName.uppercased()) → \(destinationRank.displayName.uppercased())"
    }
}
