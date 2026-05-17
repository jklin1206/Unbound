import Foundation

/// The headline metric a finished routine leads with. `elapsedSeconds` is
/// always captured on the record regardless; this only chooses the headline.
enum RoutineMetric: Codable, Hashable, Sendable {
    case time(seconds: Int)                    // timer / interval / checklist
    case repCount(total: Int, bursts: [Int])   // repTarget (each ADD = a burst)
    case steps(done: Int, total: Int)          // instruction-dominant routine
}

struct RoutineCompletionRecord: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let routineId: String
    let completedAt: Date
    let elapsedSeconds: Int
    let primaryMetric: RoutineMetric
    let spAwarded: Int

    init(id: String = UUID().uuidString,
         routineId: String,
         completedAt: Date = Date(),
         elapsedSeconds: Int,
         primaryMetric: RoutineMetric,
         spAwarded: Int) {
        self.id = id
        self.routineId = routineId
        self.completedAt = completedAt
        self.elapsedSeconds = elapsedSeconds
        self.primaryMetric = primaryMetric
        self.spAwarded = spAwarded
    }
}
