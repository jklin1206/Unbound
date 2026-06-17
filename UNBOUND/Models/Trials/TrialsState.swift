import Foundation

struct WeeklyVowCompletionLedgerEntry: Codable, Equatable, Identifiable, Sendable {
    var id: String { performanceLogId }

    let vowId: String
    let performanceLogId: String
    let completedAt: Date
    let bonus: WeeklyVowCompletionBonus
}

struct WeeklyVowPenaltyLedgerEntry: Codable, Equatable, Identifiable, Sendable {
    var id: String { "\(vowId)-\(Int(weekStart.timeIntervalSince1970))" }

    let vowId: String
    let lane: VowLane
    let weekStart: Date
    let missedAt: Date
    let penaltyXP: Int
}

/// A vow the user cleared — the record behind the profile's completed-vows list.
struct KeptVow: Codable, Equatable, Identifiable, Sendable {
    var id: String { "\(vowId)-\(Int(completedAt.timeIntervalSince1970))" }

    let vowId: String
    let name: String
    let lane: VowLane
    let completedAt: Date
}

/// Persisted Weekly Vows state per user. Lives in WeeklyVowsStore.
struct WeeklyVowsState: Codable, Equatable, Sendable {
    /// Monday 00:00 of the active vow week. nil before first generation.
    var currentWeekStart: Date?
    /// The 3 cards offered for the current week. Empty before generation.
    var currentWeekCards: [WeeklyVowCard]
    /// The user's pick. nil = not picked yet or skipped this week.
    var currentTrial: WeeklyVow?
    /// Per-lane kept-vow counter (badge track + draw targeting).
    var completionsByLane: [VowLane: Int]
    /// Vow-scoped self-report tallies, keyed by vow id (all lanes). Feeds only
    /// the vow's completion — never XP/rank/attributes (spec §7 guardrail).
    var fuelAnchorsByVowId: [String: Int]
    /// Append-only list of unlocked Titles, ordered by unlock time.
    var unlockedTitles: [TitleID]
    /// User's chosen headline title (must be in unlockedTitles to equip).
    var equippedTitle: TitleID?
    /// User explicitly skipped the current week's pick. Prevents modal re-presentation.
    var skippedCurrentWeek: Bool
    /// Saved PerformanceLogs that have already consumed the one-time Vow bonus.
    var weeklyVowCompletionLedger: [WeeklyVowCompletionLedgerEntry]
    /// Missed picked vows. Skipping before picking still has no penalty.
    var weeklyVowPenaltyLedger: [WeeklyVowPenaltyLedgerEntry]
    /// Cleared vows, oldest-first — the profile's completed-vows list.
    var keptVows: [KeptVow]

    var currentVow: WeeklyVow? {
        get { currentTrial }
        set { currentTrial = newValue }
    }

    static let empty = WeeklyVowsState(
        currentWeekStart: nil,
        currentWeekCards: [],
        currentTrial: nil,
        completionsByLane: [:],
        fuelAnchorsByVowId: [:],
        unlockedTitles: [],
        equippedTitle: nil,
        skippedCurrentWeek: false,
        weeklyVowCompletionLedger: [],
        weeklyVowPenaltyLedger: [],
        keptVows: []
    )

    init(
        currentWeekStart: Date?,
        currentWeekCards: [WeeklyVowCard],
        currentTrial: WeeklyVow?,
        completionsByLane: [VowLane: Int] = [:],
        fuelAnchorsByVowId: [String: Int] = [:],
        unlockedTitles: [TitleID],
        equippedTitle: TitleID?,
        skippedCurrentWeek: Bool,
        weeklyVowCompletionLedger: [WeeklyVowCompletionLedgerEntry] = [],
        weeklyVowPenaltyLedger: [WeeklyVowPenaltyLedgerEntry] = [],
        keptVows: [KeptVow] = []
    ) {
        self.currentWeekStart = currentWeekStart
        self.currentWeekCards = currentWeekCards
        self.currentTrial = currentTrial
        self.completionsByLane = completionsByLane
        self.fuelAnchorsByVowId = fuelAnchorsByVowId
        self.unlockedTitles = unlockedTitles
        self.equippedTitle = equippedTitle
        self.skippedCurrentWeek = skippedCurrentWeek
        self.weeklyVowCompletionLedger = weeklyVowCompletionLedger
        self.weeklyVowPenaltyLedger = weeklyVowPenaltyLedger
        self.keptVows = keptVows
    }

    private enum CodingKeys: String, CodingKey {
        case currentWeekStart
        case currentWeekCards
        case currentTrial
        case completionsByLane
        case fuelAnchorsByVowId
        case unlockedTitles
        case equippedTitle
        case skippedCurrentWeek
        case weeklyVowCompletionLedger
        case weeklyVowPenaltyLedger
        case keptVows
    }

    /// Legacy keys, decode-only for migration detection. `completionsByCardKind`
    /// is the pre-v2 marker that triggers discarding a stale in-flight vow (spec §9).
    private enum LegacyCodingKeys: String, CodingKey {
        case completionsByCardKind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)

        // Counters/titles always carry forward regardless of card-shape version.
        completionsByLane = try container.decodeIfPresent([VowLane: Int].self, forKey: .completionsByLane) ?? [:]
        fuelAnchorsByVowId = try container.decodeIfPresent([String: Int].self, forKey: .fuelAnchorsByVowId) ?? [:]
        unlockedTitles = try container.decodeIfPresent([TitleID].self, forKey: .unlockedTitles) ?? []
        equippedTitle = try container.decodeIfPresent(TitleID.self, forKey: .equippedTitle)
        weeklyVowCompletionLedger = try container.decodeIfPresent(
            [WeeklyVowCompletionLedgerEntry].self,
            forKey: .weeklyVowCompletionLedger
        ) ?? []
        // Penalty entries changed shape in Core-3 (cardKind -> lane); tolerate a
        // pre-v2 ledger that can't decode under the new shape.
        weeklyVowPenaltyLedger = ((try? container.decodeIfPresent(
            [WeeklyVowPenaltyLedgerEntry].self,
            forKey: .weeklyVowPenaltyLedger
        )) ?? nil) ?? []
        keptVows = try container.decodeIfPresent([KeptVow].self, forKey: .keptVows) ?? []

        // Spec §9 migration: a pre-v2 blob carries the old card shape under an
        // in-flight vow. If we detect the legacy `completionsByCardKind` marker,
        // or the in-flight cards/vow fail to decode under the new lean card shape,
        // discard the in-flight vow (no broken half-migrated vow) while keeping
        // every durable counter/title above.
        //
        // `cardsDecodeFailed`/`vowDecodeFailed` are true ONLY when a present value
        // throws under the new shape — an absent/null key is fine and decodes to
        // an empty week / no vow, which is the normal post-roll state.
        let hasLegacyMarker = legacyContainer.contains(.completionsByCardKind)

        var cardsDecodeFailed = false
        var decodedCards: [WeeklyVowCard] = []
        do {
            decodedCards = try container.decodeIfPresent([WeeklyVowCard].self, forKey: .currentWeekCards) ?? []
        } catch {
            cardsDecodeFailed = true
        }

        var vowDecodeFailed = false
        var decodedVow: WeeklyVow?
        do {
            decodedVow = try container.decodeIfPresent(WeeklyVow.self, forKey: .currentTrial)
        } catch {
            vowDecodeFailed = true
        }

        if hasLegacyMarker || cardsDecodeFailed || vowDecodeFailed {
            currentWeekStart = nil
            currentWeekCards = []
            currentTrial = nil
            skippedCurrentWeek = true
        } else {
            currentWeekStart = try container.decodeIfPresent(Date.self, forKey: .currentWeekStart)
            currentWeekCards = decodedCards
            currentTrial = decodedVow
            skippedCurrentWeek = try container.decodeIfPresent(Bool.self, forKey: .skippedCurrentWeek) ?? false
        }
    }
}

typealias TrialsState = WeeklyVowsState
