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
    let cardKind: WeeklyVowKind
    let weekStart: Date
    let missedAt: Date
    let penaltyXP: Int
}

/// Persisted Weekly Vows state per user. Lives in WeeklyVowsStore.
struct WeeklyVowsState: Codable, Equatable, Sendable {
    /// Monday 00:00 of the active vow week. nil before first generation.
    var currentWeekStart: Date?
    /// The 3 cards offered for the current week. Empty before generation.
    var currentWeekCards: [WeeklyVowCard]
    /// The user's pick. nil = not picked yet or skipped this week.
    var currentTrial: WeeklyVow?
    /// Per-axis Title progress counter. Increments on completion.
    var completionsByAxis: [AttributeKey: Int]
    /// Per-vow-kind Title progress counter.
    var completionsByCardKind: [WeeklyVowKind: Int]
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
    /// Outstanding XP debt from broken vows. Withheld from the user's next
    /// earned training XP (never subtracts existing total, never de-levels).
    var pendingVowDebtXP: Int

    var currentVow: WeeklyVow? {
        get { currentTrial }
        set { currentTrial = newValue }
    }

    var completionsByVowKind: [WeeklyVowKind: Int] {
        get { completionsByCardKind }
        set { completionsByCardKind = newValue }
    }

    static let empty = WeeklyVowsState(
        currentWeekStart: nil,
        currentWeekCards: [],
        currentTrial: nil,
        completionsByAxis: [:],
        completionsByCardKind: [:],
        unlockedTitles: [],
        equippedTitle: nil,
        skippedCurrentWeek: false,
        weeklyVowCompletionLedger: [],
        weeklyVowPenaltyLedger: [],
        pendingVowDebtXP: 0
    )

    init(
        currentWeekStart: Date?,
        currentWeekCards: [WeeklyVowCard],
        currentTrial: WeeklyVow?,
        completionsByAxis: [AttributeKey: Int],
        completionsByCardKind: [WeeklyVowKind: Int],
        unlockedTitles: [TitleID],
        equippedTitle: TitleID?,
        skippedCurrentWeek: Bool,
        weeklyVowCompletionLedger: [WeeklyVowCompletionLedgerEntry] = [],
        weeklyVowPenaltyLedger: [WeeklyVowPenaltyLedgerEntry] = [],
        pendingVowDebtXP: Int = 0
    ) {
        self.currentWeekStart = currentWeekStart
        self.currentWeekCards = currentWeekCards
        self.currentTrial = currentTrial
        self.completionsByAxis = completionsByAxis
        self.completionsByCardKind = completionsByCardKind
        self.unlockedTitles = unlockedTitles
        self.equippedTitle = equippedTitle
        self.skippedCurrentWeek = skippedCurrentWeek
        self.weeklyVowCompletionLedger = weeklyVowCompletionLedger
        self.weeklyVowPenaltyLedger = weeklyVowPenaltyLedger
        self.pendingVowDebtXP = max(0, pendingVowDebtXP)
    }

    private enum CodingKeys: String, CodingKey {
        case currentWeekStart
        case currentWeekCards
        case currentTrial
        case completionsByAxis
        case completionsByCardKind
        case unlockedTitles
        case equippedTitle
        case skippedCurrentWeek
        case weeklyVowCompletionLedger
        case weeklyVowPenaltyLedger
        case pendingVowDebtXP
    }

    /// Legacy v1 key, decode-only for migration.
    private enum LegacyCodingKeys: String, CodingKey {
        case pendingVowPenaltyXP
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentWeekStart = try container.decodeIfPresent(Date.self, forKey: .currentWeekStart)
        currentWeekCards = try container.decodeIfPresent([WeeklyVowCard].self, forKey: .currentWeekCards) ?? []
        currentTrial = try container.decodeIfPresent(WeeklyVow.self, forKey: .currentTrial)
        completionsByAxis = try container.decodeIfPresent([AttributeKey: Int].self, forKey: .completionsByAxis) ?? [:]
        completionsByCardKind = try container.decodeIfPresent([WeeklyVowKind: Int].self, forKey: .completionsByCardKind) ?? [:]
        unlockedTitles = try container.decodeIfPresent([TitleID].self, forKey: .unlockedTitles) ?? []
        equippedTitle = try container.decodeIfPresent(TitleID.self, forKey: .equippedTitle)
        skippedCurrentWeek = try container.decodeIfPresent(Bool.self, forKey: .skippedCurrentWeek) ?? false
        weeklyVowCompletionLedger = try container.decodeIfPresent(
            [WeeklyVowCompletionLedgerEntry].self,
            forKey: .weeklyVowCompletionLedger
        ) ?? []
        weeklyVowPenaltyLedger = try container.decodeIfPresent(
            [WeeklyVowPenaltyLedgerEntry].self,
            forKey: .weeklyVowPenaltyLedger
        ) ?? []
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        pendingVowDebtXP = try container.decodeIfPresent(Int.self, forKey: .pendingVowDebtXP)
            ?? legacyContainer.decodeIfPresent(Int.self, forKey: .pendingVowPenaltyXP)
            ?? 0
    }
}

typealias TrialsState = WeeklyVowsState
