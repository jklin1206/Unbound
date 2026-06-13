import SwiftUI

/// Config for one gate's Crossing cinematic. Wraps the Plan-2 `GateWorld` (single
/// source for numeral, tint, banner, destination rank) and adds the Crossing-only
/// pieces: tier cadence + the dwell line. Investiture title derives from the rank.
struct GateCrossing: Identifiable, Equatable, Sendable {
    let world: GateWorld
    /// One brand-safe, non-negging line for the arrival/dwell beat ("You live here now.").
    let dwellLine: String

    var id: RankTrialFormat { world.format }
    var tier: CrossingTier { CrossingTier.forOrder(world.order) }

    /// "FORGED" — the rank, spoken as arrival.
    var investitureTitle: String { world.destinationRank.displayName.uppercased() }

    /// Color surface — all derive from the destination rank (Color Design Check §1).
    var tint: Color { world.tint }          // foreground-safe (rewardTextTint)
    var fillTint: Color { world.fillTint }   // saturated fill (rewardTint)
    var glowColors: [Color] { world.destinationRank.rewardGlowColors }

    /// Banner-cosmetic unlock chip copy for the spoils beat.
    var unlockChip: String { "\(world.destinationRank.displayName.uppercased()) BANNER UNLOCKED" }
}
