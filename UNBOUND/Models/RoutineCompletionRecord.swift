import Foundation

/// The headline metric a finished routine leads with. `elapsedSeconds` is
/// always captured on the record regardless; this only chooses the headline.
enum RoutineMetric: Codable, Hashable, Sendable {
    case time(seconds: Int)                    // timer / interval / checklist
    case repCount(total: Int, bursts: [Int])   // repTarget (each ADD = a burst)
    case steps(done: Int, total: Int)          // instruction-dominant routine
}

enum RoutinePerformanceEntrySource: String, Codable, Hashable, Sendable {
    case instruction
    case timed
    case interval
    case repTarget
}

/// Movement-level work captured by the routine player. This lets routine
/// completion feed the unified progression pipeline with actual completed
/// reps/time/distance instead of only inferring from authored routine text.
struct RoutinePerformanceEntry: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var stepId: Int?
    var source: RoutinePerformanceEntrySource
    var name: String
    var reps: Int?
    var bursts: [Int]
    var holdSeconds: Int?
    var durationSeconds: Int?
    var distanceMeters: Int?
    var calories: Int?
    var loadKg: Double?
    var notes: String?

    init(
        id: String = UUID().uuidString,
        stepId: Int? = nil,
        source: RoutinePerformanceEntrySource,
        name: String,
        reps: Int? = nil,
        bursts: [Int] = [],
        holdSeconds: Int? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Int? = nil,
        calories: Int? = nil,
        loadKg: Double? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.stepId = stepId
        self.source = source
        self.name = name
        self.reps = reps
        self.bursts = bursts
        self.holdSeconds = holdSeconds
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.calories = calories
        self.loadKg = loadKg
        self.notes = notes
    }
}

struct RoutineCompletionRecord: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let routineId: String
    let completedAt: Date
    let elapsedSeconds: Int
    let primaryMetric: RoutineMetric
    let spAwarded: Int
    let performanceEntries: [RoutinePerformanceEntry]

    init(id: String = UUID().uuidString,
         routineId: String,
         completedAt: Date = Date(),
         elapsedSeconds: Int,
         primaryMetric: RoutineMetric,
         spAwarded: Int,
         performanceEntries: [RoutinePerformanceEntry] = []) {
        self.id = id
        self.routineId = routineId
        self.completedAt = completedAt
        self.elapsedSeconds = elapsedSeconds
        self.primaryMetric = primaryMetric
        self.spAwarded = spAwarded
        self.performanceEntries = performanceEntries
    }

    enum CodingKeys: String, CodingKey {
        case id, routineId, completedAt, elapsedSeconds, primaryMetric, spAwarded, performanceEntries
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        routineId = try c.decode(String.self, forKey: .routineId)
        completedAt = try c.decode(Date.self, forKey: .completedAt)
        elapsedSeconds = try c.decode(Int.self, forKey: .elapsedSeconds)
        primaryMetric = try c.decode(RoutineMetric.self, forKey: .primaryMetric)
        spAwarded = try c.decode(Int.self, forKey: .spAwarded)
        performanceEntries = try c.decodeIfPresent([RoutinePerformanceEntry].self, forKey: .performanceEntries) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(routineId, forKey: .routineId)
        try c.encode(completedAt, forKey: .completedAt)
        try c.encode(elapsedSeconds, forKey: .elapsedSeconds)
        try c.encode(primaryMetric, forKey: .primaryMetric)
        try c.encode(spAwarded, forKey: .spAwarded)
        try c.encode(performanceEntries, forKey: .performanceEntries)
    }
}
