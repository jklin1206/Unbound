import Foundation

// MARK: - RegionRank
//
// Aggregate rank for a single BodyRegion, computed from the current
// LiftRank of each contributing lift. Missing lifts are treated as
// `.eMinus` so a muscle that's never been trained correctly reads "dim".

struct RegionRank: Sendable, Identifiable, Hashable {
    let region: BodyRegion
    let rank: SubRank
    let topContributingLifts: [ContributingLift]
    let needsWork: Bool

    var id: BodyRegion { region }

    struct ContributingLift: Sendable, Hashable {
        let exerciseKey: String
        let displayName: String
        let rank: SubRank
    }
}

// MARK: - MuscleRankCalculator

enum MuscleRankCalculator {

    /// Compute a RegionRank for a single region from all available LiftRanks.
    /// Missing lifts contribute at `.eMinus.ordinal` (0). All contributors
    /// are weighted equally — primary vs accessory weighting is a V2 lever.
    static func compute(
        for region: BodyRegion,
        from liftRanks: [LiftRank]
    ) -> RegionRank {
        let byKey: [String: LiftRank] = Dictionary(
            uniqueKeysWithValues: liftRanks.map { ($0.exerciseKey, $0) }
        )

        // Match contributing lifts against the LiftRank table by substring so
        // variants ("incline bench press" inherits from "bench press" entry)
        // land in the right bucket without duplicating keys.
        var matched: [RegionRank.ContributingLift] = []
        var ordinals: [Int] = []

        for canonical in region.contributingLifts {
            // Exact key first — then substring fallback against known ranks.
            let hit: LiftRank? = byKey[canonical] ?? liftRanks.first { liftRank in
                liftRank.exerciseKey.contains(canonical) || canonical.contains(liftRank.exerciseKey)
            }
            if let hit {
                matched.append(.init(
                    exerciseKey: hit.exerciseKey,
                    displayName: hit.displayName,
                    rank: hit.currentRank
                ))
                ordinals.append(hit.currentRank.ordinal)
            } else {
                ordinals.append(SubRank.eMinus.ordinal)
            }
        }

        let mean: Double
        if ordinals.isEmpty {
            mean = Double(SubRank.eMinus.ordinal)
        } else {
            mean = Double(ordinals.reduce(0, +)) / Double(ordinals.count)
        }

        let rank = SubRank.nearest(for: mean)

        let top = matched
            .sorted { $0.rank.ordinal > $1.rank.ordinal }
            .prefix(3)

        return RegionRank(
            region: region,
            rank: rank,
            topContributingLifts: Array(top),
            needsWork: rank.ordinal < SubRank.cMinus.ordinal
        )
    }

    /// Compute RegionRank for every BodyRegion in one pass.
    static func computeAll(liftRanks: [LiftRank]) -> [BodyRegion: RegionRank] {
        var result: [BodyRegion: RegionRank] = [:]
        for region in BodyRegion.allCases {
            result[region] = compute(for: region, from: liftRanks)
        }
        return result
    }

    /// Pick the lowest-ranked region that still has visible room to grow.
    /// Anything already at B- or above is considered "in balance" — we only
    /// nudge a directive for real weaknesses so the home tile reads as a
    /// call to action, not nagging.
    static func weakestMuscle(from liftRanks: [LiftRank]) -> (BodyRegion, RegionRank)? {
        let all = computeAll(liftRanks: liftRanks)
        let weak = all.values.filter { $0.rank.ordinal < SubRank.bMinus.ordinal }
        guard let lowest = weak.min(by: { $0.rank.ordinal < $1.rank.ordinal }) else {
            return nil
        }
        return (lowest.region, lowest)
    }
}

// MARK: - SubRank tint ramp
//
// Red → green → violet → gold heat ramp. Universal fitness language:
// red = needs urgent work, green = solid, violet = advanced, gold = elite.
// This replaces the old dim-grey → violet ramp so a user can instantly scan
// the body map and see which zones are weakest (red) vs crushing (violet+).
//
//   E-, E, E+ → rankRed          (#B91C1C)   untrained / urgent
//   D-, D, D+ → rankOrange       (#F97316)   weak
//   C-, C, C+ → rankAmber        (#EAB308)   moderate
//   B-, B, B+ → rankGreen        (#22C55E)   solid
//   A-, A, A+ → accent / impact  (#7C3AED)   advanced (violet = brand)
//   S-, S, S+ → rankGold         (#FFC857)   elite (S / S+ render with shimmer)

import SwiftUI

extension SubRank {
    /// Steady-state tint for the body map figure.
    var regionTint: Color {
        switch self.letter {
        case "E":
            return Color.unbound.rankRed
        case "D":
            return Color.unbound.rankOrange
        case "C":
            return Color.unbound.rankAmber
        case "B":
            return Color.unbound.rankGreen
        case "A":
            // A-tier uses the brand violet; A / A+ step up to the brighter impact hue.
            return self == .aMinus ? Color.unbound.accent : Color.unbound.impact
        case "S":
            return Color.unbound.rankGold
        default:
            return Color.unbound.rankRed
        }
    }

    /// True when the region should render with a holographic shimmer
    /// (S / S+ only; S- reads as gold without shimmer).
    var usesHolographicShimmer: Bool {
        self == .s || self == .sPlus
    }
}

extension Color {
    /// Gold reserved for S-tier regions.
    static let unboundGold = Color(.sRGB, red: 1.0, green: 0.784, blue: 0.341, opacity: 1.0) // #FFC857
}
