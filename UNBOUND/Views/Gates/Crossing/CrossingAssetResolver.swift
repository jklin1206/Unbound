import SwiftUI

/// Resolves the best-available threshold still for a gate's Crossing, with
/// graceful fallback (spec §8: "missing assets → animated still on the banner").
///
/// Plan 3 ships on stills only. When jlin's curated art lane (docs/rank-gates-art-lane.md)
/// drops `gate_threshold_<token>` imagesets into the catalog, this resolver picks
/// them up automatically — no code change. Video clips (Seedance i2v "walk") are a
/// Plan-4 seam: they land as `gate_crossing_<token>` and a `.clip` case is added here.
enum CrossingAssetResolver {

    /// Asset name of the still to render under The Crossing.
    static func thresholdStill(for crossing: GateCrossing) -> String {
        let bespoke = bespokeStillName(for: crossing)
        return imageExists(bespoke) ? bespoke : crossing.world.bannerAssetName
    }

    /// True when a bespoke threshold painting exists (vs. falling back to the rank banner).
    static func hasBespokeArt(for crossing: GateCrossing) -> Bool {
        imageExists(bespokeStillName(for: crossing))
    }

    static func bespokeStillName(for crossing: GateCrossing) -> String {
        "gate_threshold_\(crossing.world.destinationRank.token)"
    }

    private static func imageExists(_ name: String) -> Bool {
        UIImage(named: name) != nil
    }
}
