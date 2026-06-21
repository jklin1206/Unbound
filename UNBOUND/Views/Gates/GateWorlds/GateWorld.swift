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
    /// Card-friendly rank banner art for the gate cards / hall / discovery
    /// (crops cleanly). The full-screen bespoke threshold art (`gate_threshold_<token>`)
    /// is full-bleed-only and lives in The Crossing via `CrossingAssetResolver`.
    var bannerAssetName: String { "profile_banner_\(destinationRank.token)" }
    /// Bespoke in-trial world backdrop (Codex image_gen, style-locked to the rank
    /// banner). Used by the live trial stage; falls back to the banner if missing.
    var stageAssetName: String { "gate_stage_\(destinationRank.token)" }

    /// "FORGED → VETERAN" style transition label.
    func transitionLabel(from origin: RankTitle) -> String {
        "\(origin.displayName.uppercased()) → \(destinationRank.displayName.uppercased())"
    }
}
