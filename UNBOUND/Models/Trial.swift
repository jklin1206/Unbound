import Foundation

/// The user's committed trial for the current week.
struct Trial: Codable, Identifiable, Equatable, Sendable {
    let id: String              // matches the chosen TrialCard.id
    let userId: String
    let weekStart: Date         // Monday 00:00 local
    let chosenCard: TrialCard
    var capstoneState: CapstoneState
    var completedAt: Date?
}

/// State machine for the trial's capstone lifecycle.
enum CapstoneState: String, Codable, Sendable {
    case pending        // Trial active, Mon–Fri. Capstone not yet attemptable.
    case windowOpen     // Saturday 00:00 → Sunday 23:59 local. Capstone available.
    case completed      // Capstone done. Counters incremented.
    case missed         // Sunday 23:59 passed without completion.
}
