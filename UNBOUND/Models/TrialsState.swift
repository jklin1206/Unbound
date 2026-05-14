import Foundation

/// Persisted trials state per user. Lives in TrialsStore.
struct TrialsState: Codable, Equatable, Sendable {
    /// Monday 00:00 of the active trial week. nil before first generation.
    var currentWeekStart: Date?
    /// The 3 cards offered for the current week. Empty before generation.
    var currentWeekCards: [TrialCard]
    /// The user's pick. nil = not picked yet or skipped this week.
    var currentTrial: Trial?
    /// Per-axis Title progress counter. Increments on completion.
    var completionsByAxis: [AttributeKey: Int]
    /// Per-card-kind Title progress counter.
    var completionsByCardKind: [TrialCardKind: Int]
    /// Append-only list of unlocked Titles, ordered by unlock time.
    var unlockedTitles: [TitleID]
    /// User's chosen headline title (must be in unlockedTitles to equip).
    var equippedTitle: TitleID?
    /// User explicitly skipped the current week's pick. Prevents modal re-presentation.
    var skippedCurrentWeek: Bool

    static let empty = TrialsState(
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
