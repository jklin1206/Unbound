import Foundation

/// The user's committed Weekly Vow for the current week.
struct WeeklyVow: Codable, Identifiable, Equatable, Sendable {
    let id: String              // matches the chosen WeeklyVowCard.id
    let userId: String
    let weekStart: Date         // Monday 00:00 local
    let chosenCard: WeeklyVowCard
    var capstoneState: WeeklyVowState
    var completedAt: Date?

    var vowState: WeeklyVowState {
        get { capstoneState }
        set { capstoneState = newValue }
    }
}

/// State machine for the weekly vow lifecycle.
enum WeeklyVowState: String, Codable, Sendable {
    case pending        // Vow active, proof window not yet open.
    case windowOpen     // Vow proof is available.
    case completed      // Vow done. Counters incremented.
    case missed         // Sunday 23:59 passed without completion.
}

typealias Trial = WeeklyVow
typealias CapstoneState = WeeklyVowState
