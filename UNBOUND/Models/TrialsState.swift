import Foundation

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
        skippedCurrentWeek: false
    )
}

typealias TrialsState = WeeklyVowsState
