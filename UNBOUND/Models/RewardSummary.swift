import Foundation

// MARK: - RewardSummary
//
// Aggregates everything a user earned from a single training event —
// a logged set, a finished session, or a one-shot achievement. The
// Callers adapt this into the shared workout reward sequence. Each
// non-nil/non-empty component becomes a beat or receipt line:
//
//  - Quiet event (XP only)             → single card
//  - Set with PR                       → 2 cards
//  - Set with PR + badge unlock        → 3 cards
//  - Rank-up (named tier)              → cinematic + cards
//
// Compute this server-side (or service-side) by snapshotting state
// before the write and diffing afterward. Nil/empty fields render
// nothing — there is no "no reward" celebration.

struct RewardSummary: Equatable {
    /// XP awarded for the event. 0 = no XP delta worth showing.
    var xpGained: Int = 0

    /// New personal record set during this event, if any.
    var personalRecord: PersonalRecord? = nil

    /// Rank advance — set when the user crossed into a new tier on a
    /// skill or lift. Drives the celebration's hero card and the
    /// chain-shatter cinematic when `tier.deservesCinematic` is true.
    var rankUp: RankUp? = nil

    /// Badges unlocked by this event, in earned-order. Each one
    /// renders as a card in the stack.
    var badgeUnlocks: [BadgeUnlock] = []

    /// User's first-ever logged set on this skill. Distinct from a PR
    /// (first attempts have no prior data to beat) — this surface
    /// celebrates the start of the journey on a per-skill basis.
    var firstSet: FirstSet? = nil

    /// Skill-name shown in the celebration header. Falls back to the
    /// rank-up's skill if not set explicitly.
    var skillTitle: String? = nil

    /// Unified progression receipt emitted by `TrainingCompletionService`.
    /// This is the first user-visible bridge for the migration spine:
    /// movement AP, attribute XP, level XP, body-map novelty, and skill XP
    /// all converge here after a finished training event.
    var progression: ProgressionReceipt? = nil

    /// True when there is at least one celebration-worthy item to show.
    /// Callers should skip presenting the sheet if false.
    var hasContent: Bool {
        if xpGained > 0 { return true }
        if personalRecord != nil { return true }
        if rankUp != nil { return true }
        if !badgeUnlocks.isEmpty { return true }
        if firstSet != nil { return true }
        if progression?.hasContent == true { return true }
        return false
    }

    /// True when at least one component warrants the full cinematic
    /// treatment — currently rank-ups into Vessel/Unbound/Ascendant.
    var deservesCinematic: Bool {
        rankUp?.toTier.deservesCinematic ?? false
    }
}

// MARK: - ProgressionReceipt

struct ProgressionReceipt: Equatable {
    var totalMovementAP: Double = 0
    var totalAttributeXP: Double = 0
    var overallLevelXPGained: Double = 0
    var overallLevelBefore: Int = 0
    var overallLevelAfter: Int = 0
    var overallLevelProgressBefore: Double = 0
    var overallLevelProgressAfter: Double = 0
    var noveltyMultiplier: Double = 1.0
    var skillXPGained: Int = 0
    var movementLines: [ProgressionMovementLine] = []
    var attributeLines: [ProgressionAttributeLine] = []
    var bodyRegionLines: [ProgressionBodyRegionLine] = []

    var hasContent: Bool {
        if totalMovementAP > 0 { return true }
        if totalAttributeXP > 0 { return true }
        if overallLevelXPGained > 0 { return true }
        if skillXPGained > 0 { return true }
        if noveltyMultiplier > 1.001 { return true }
        if !movementLines.isEmpty || !attributeLines.isEmpty || !bodyRegionLines.isEmpty { return true }
        return false
    }

    var didOverallLevelUp: Bool {
        overallLevelAfter > overallLevelBefore
    }
}

/// Per-movement reward line: XP earned this session plus how close that
/// movement now sits to its next RankTier (derived from the user's best metric
/// via `StrengthStandards.progressToNextRank`). Unranked/unrecognized movements
/// carry no rank — `currentRank == nil` → the reward shows just "+X XP".
struct ProgressionMovementLine: Identifiable, Equatable {
    let id: String
    let name: String
    let xpGained: Double

    /// The movement's current RankTier, or nil if unranked (cardio, carry,
    /// unranked accessory, free-text). nil → "+X XP" only, no rank bar.
    var currentRank: RankTier?
    /// The next tier up, or nil at peak ("MAXED").
    var nextRank: RankTier?
    /// 0…1 fill between `currentRank` and `nextRank` (1.0 at peak).
    var fractionToNextRank: Double = 0
    /// True when this session crossed the movement into a new tier.
    var didRankUp: Bool = false
}

struct ProgressionAttributeLine: Identifiable, Equatable {
    var id: String { key.rawValue }

    let key: AttributeKey
    let xpGained: Double
    let levelBefore: Int
    let levelAfter: Int
    var progressBefore: Double = 0
    var progressAfter: Double = 0
    let tierAfter: RankTitle

    var didLevelUp: Bool {
        levelAfter > levelBefore
    }
}

struct ProgressionBodyRegionLine: Identifiable, Equatable {
    var id: String { name }

    let name: String
    let loadAdded: Double
}

// MARK: - PersonalRecord

/// A new max set on a single dimension. A single LoggedSet can only
/// improve one dimension at a time in practice — we surface the most
/// significant one.
struct PersonalRecord: Equatable {
    enum Kind: String, Equatable {
        case maxReps        // most reps in a single set
        case maxWeight      // heaviest single load (regardless of reps)
        case maxHold        // longest static hold
        case maxVolume      // sets × reps × load (future)
    }
    let kind: Kind
    let exerciseName: String
    let value: Double           // raw numeric value (reps as Double, kg, seconds)
    let previousBest: Double    // for the "+X" delta line

    var displayValue: String {
        switch kind {
        case .maxReps:    return "\(Int(value)) reps"
        case .maxWeight:  return value == floor(value) ? "\(Int(value)) kg" : String(format: "%.1f kg", value)
        case .maxHold:    return "\(Int(value))s hold"
        case .maxVolume:  return "\(Int(value)) total"
        }
    }

    var deltaText: String? {
        let delta = value - previousBest
        guard delta > 0 else { return nil }
        switch kind {
        case .maxReps:    return "+\(Int(delta)) over best"
        case .maxWeight:  return "+\(delta == floor(delta) ? "\(Int(delta))" : String(format: "%.1f", delta)) kg over best"
        case .maxHold:    return "+\(Int(delta))s over best"
        case .maxVolume:  return "+\(Int(delta)) volume"
        }
    }
}

// MARK: - RankUp

/// Skill-rank crossing event. `fromTier == nil` means this is the
/// user's first earned rank on the skill (Initiate → Novice typically).
struct RankUp: Equatable {
    let skillId: String
    let skillTitle: String
    let fromTier: RankTitle?
    let toTier: RankTitle
}

// MARK: - FirstSet

/// First-ever logged set on a given skill. The "journey begins" moment.
/// Per-skill scope (not per-account) so trying a new skill always
/// rewards the first attempt.
struct FirstSet: Equatable {
    let skillId: String
    let skillTitle: String
}

// MARK: - BadgeUnlock

/// Reference to a Badge unlocked by this event. Asset name resolves
/// via the BadgeArt imageset bundle.
struct BadgeUnlock: Equatable {
    let id: String              // matches BadgeCatalog id
    let title: String
    let subtitle: String?
    let assetName: String       // imageset name in Assets.xcassets/BadgeArt
    let rankTier: RankTitle?

    init(id: String, title: String, subtitle: String?, assetName: String, rankTier: RankTitle? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.assetName = assetName
        self.rankTier = rankTier
    }
}
