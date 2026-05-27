import Foundation

// MARK: - ProgramScheduler
//
// V3 — Active goals route to a weekly Push / Pull / Legs / Core / Skills /
// Conditioning / Rest split based on each goal's skill cluster. The user
// can now customize the weekly schedule (persisted via SkillProgressService).
// Tappable day chips in the Program tab let the user preview any day's
// routed goals.
//
// Ordering rules (within a day):
//   1) NOT yet trained today (canTrain == true) FIRST — actionable work
//      lands at the top.
//   2) Stable alphabetical tiebreak by node id.

/// Body-part / movement category for a training day. Active goals route
/// to matching days based on the skill's cluster. Codable so user-authored
/// weekly schedules persist round-trip.
enum DayCategory: String, CaseIterable, Identifiable, Hashable, Codable {
    case push, pull, legs, core, skills, conditioning, rest

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .push:         return "Push"
        case .pull:         return "Pull"
        case .legs:         return "Legs"
        case .core:         return "Core"
        case .skills:       return "Skills"
        case .conditioning: return "Conditioning"
        case .rest:         return "Rest"
        }
    }
    /// SF Symbol for the day-strip glyph.
    var glyph: String {
        switch self {
        case .push:         return "arrow.up.right"
        case .pull:         return "arrow.down.left"
        case .legs:         return "figure.walk"
        case .core:         return "figure.core.training"
        case .skills:       return "figure.gymnastics"
        case .conditioning: return "figure.run"
        case .rest:         return "moon.fill"
        }
    }
}

// MARK: - WeekPhase (V4)
//
// Manual periodization tag the user picks to set this week's emphasis.
// Flows into deterministic session prescription so volume/intensity scale
// with the user's chosen emphasis. A 7-day periodization cycle was deemed
// too complex for V4 — the simple manual tag keeps the user in control.
enum WeekPhase: String, Codable, CaseIterable, Identifiable, Hashable {
    case heavy, moderate, light, deload

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .heavy:    return "Heavy"
        case .moderate: return "Moderate"
        case .light:    return "Light"
        case .deload:   return "Deload"
        }
    }

    var description: String {
        switch self {
        case .heavy:    return "Push intensity. Add load. Limit volume."
        case .moderate: return "Balanced volume + intensity. Default."
        case .light:    return "Tempo work, technique focus, lower intensity."
        case .deload:   return "Active recovery. Mobility + light skill work only."
        }
    }

    /// SF Symbol for the chip glyph.
    var glyph: String {
        switch self {
        case .heavy:    return "flame.fill"
        case .moderate: return "chart.bar.fill"
        case .light:    return "leaf.fill"
        case .deload:   return "moon.zzz.fill"
        }
    }
}

@MainActor
final class ProgramScheduler {
    static let shared = ProgramScheduler()
    private init() {}

    // MARK: - Cluster → Category mapping

    /// Maps skill clusters to body-part categories so active goals route to
    /// the right days. Cluster IDs come from SkillCluster enum.
    static func category(for cluster: SkillCluster) -> DayCategory {
        switch cluster {
        case .calisthenicControl: return .push
        case .pullingPower:       return .pull
        case .legDominance:       return .legs
        case .coreLever:          return .core   // covers core proper + lever family
        case .handstand:          return .skills
        case .handstandPushup:    return .push   // pressing variant — overhead push
        case .oneArmHandstand:    return .skills
        case .planche:            return .skills
        case .conditioning:       return .conditioning   // V3 — real conditioning slot
        }
    }

    func optimizedWeeklySchedule(activeGoalIds: Set<String>) -> [DayCategory] {
        let categories = activeGoalIds.compactMap { id -> DayCategory? in
            guard let node = SkillGraph.shared.node(id: id) else { return nil }
            return Self.category(for: node.cluster)
        }
        guard !categories.isEmpty else { return Self.defaultWeeklySchedule }

        let counts = Dictionary(grouping: categories, by: { $0 })
            .mapValues(\.count)
        let ranked = counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return categoryPriority(lhs.key) < categoryPriority(rhs.key)
            }
            .map(\.key)

        var schedule = Self.defaultWeeklySchedule
        let trainingSlots = [0, 1, 2, 3, 4, 5]
        for (offset, slot) in trainingSlots.enumerated() {
            schedule[slot] = ranked[offset % ranked.count]
        }
        if ranked.count == 1 {
            schedule[1] = recoveryPair(for: ranked[0])
            schedule[3] = .conditioning
            schedule[5] = .skills
        }
        schedule[6] = .rest
        return smoothBackToBackRepeats(schedule)
    }

    private func categoryPriority(_ category: DayCategory) -> Int {
        switch category {
        case .pull: return 0
        case .push: return 1
        case .legs: return 2
        case .core: return 3
        case .skills: return 4
        case .conditioning: return 5
        case .rest: return 6
        }
    }

    private func recoveryPair(for category: DayCategory) -> DayCategory {
        switch category {
        case .pull, .push: return .legs
        case .legs: return .pull
        case .core, .skills: return .conditioning
        case .conditioning, .rest: return .push
        }
    }

    private func smoothBackToBackRepeats(_ schedule: [DayCategory]) -> [DayCategory] {
        var result = schedule
        for index in 1..<6 where result[index] == result[index - 1] {
            if let swapIndex = ((index + 1)..<6).first(where: { result[$0] != result[index] }) {
                result.swapAt(index, swapIndex)
            }
        }
        return result
    }

    // MARK: - Weekly schedule

    /// Default weekly split. Index 0 = Monday, 6 = Sunday. User overrides
    /// (in SkillProgressService.weeklySchedule) supersede this per-slot.
    static let defaultWeeklySchedule: [DayCategory] = [
        .pull,          // Mon
        .push,          // Tue
        .legs,          // Wed
        .conditioning,  // Thu — V3 real conditioning day
        .pull,          // Fri  (second pull day for muscle-up / front lever progression)
        .skills,        // Sat
        .rest           // Sun
    ]

    /// Apple weekday: Sun=1, Mon=2, ..., Sat=7. We map to a Mon=0..Sun=6
    /// index for the schedule array.
    private func mondayZeroIndex(for date: Date) -> Int {
        let cal = Calendar(identifier: .iso8601)
        let weekday = cal.component(.weekday, from: date)
        switch weekday {
        case 2: return 0  // Mon
        case 3: return 1
        case 4: return 2
        case 5: return 3
        case 6: return 4
        case 7: return 5
        case 1: return 6  // Sun
        default: return 0
        }
    }

    /// Returns the category for a given date. Consults the user's persisted
    /// schedule first; falls back to `defaultWeeklySchedule` per-slot.
    func category(for date: Date) -> DayCategory {
        let index = mondayZeroIndex(for: date)
        if let userPick = SkillProgressService.shared.weeklySchedule[safe: index] ?? nil {
            return userPick
        }
        return Self.defaultWeeklySchedule[index]
    }

    /// Resolves the user's weekly schedule into a 7-element array. User picks
    /// merged with defaults — used by the editor sheet so it can show what's
    /// currently in effect.
    func effectiveWeeklySchedule() -> [DayCategory] {
        let userSchedule = SkillProgressService.shared.weeklySchedule
        return (0..<7).map { idx in
            (userSchedule[safe: idx] ?? nil) ?? Self.defaultWeeklySchedule[idx]
        }
    }

    // MARK: - Today's training

    /// Returns active goals routed to TODAY based on cluster→category match.
    /// On a rest day, returns []. Sort: NOT-trained-today first.
    func todaysSkillSessions() -> [String] {
        let today = category(for: Date())
        if today == .rest { return [] }
        return skillIds(forCategory: today)
    }

    /// Active goals matching a given category. Used by the day strip to
    /// count each day's load.
    func skillIds(forCategory cat: DayCategory) -> [String] {
        let progress = SkillProgressService.shared
        let graph = SkillGraph.shared
        let goals = Array(progress.activeGoalIds)

        let matching = goals.filter {
            guard let node = graph.node(id: $0) else { return false }
            return Self.category(for: node.cluster) == cat
        }

        return matching.sorted { a, b in
            let aReady = progress.canTrain(nodeId: a)
            let bReady = progress.canTrain(nodeId: b)
            if aReady != bReady { return aReady && !bReady }
            return a < b
        }
    }

    /// Returns the goals routed to a specific date. Used by the day-preview
    /// sheet — not filtered by canTrain status.
    func skillIds(forDate date: Date) -> [String] {
        let cat = category(for: date)
        if cat == .rest { return [] }
        return skillIds(forCategory: cat)
    }

    /// First date whose program category can host the given skill. This is
    /// the bridge from Skill Detail's "Add to Program" action to the Program
    /// tab's next eligible Workout Ready draft.
    func nextEligibleDate(
        forSkillId skillId: String,
        from startDate: Date = Date(),
        daysToSearch: Int = 14
    ) -> Date? {
        guard daysToSearch > 0,
              let node = SkillGraph.shared.node(id: skillId)
        else { return nil }

        let targetCategory = Self.category(for: node.cluster)
        guard targetCategory != .rest else { return nil }

        let calendar = Calendar(identifier: .iso8601)
        let start = calendar.startOfDay(for: startDate)
        for offset in 0..<daysToSearch {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            if category(for: candidate) == targetCategory {
                return candidate
            }
        }
        return nil
    }

    /// Returns the upcoming N days' (date, category, skillCount) tuples.
    /// Used by the 7-day horizontal strip.
    func weeklyOverview(days: Int = 7) -> [(date: Date, category: DayCategory, count: Int)] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return (0..<days).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            let cat = category(for: date)
            let count = cat == .rest ? 0 : skillIds(forCategory: cat).count
            return (date, cat, count)
        }
    }

    /// Quick helper — does the user have anything to train today?
    func hasTodaysTraining() -> Bool {
        !todaysSkillSessions().isEmpty
    }

    /// Returns just the count for badge display. Reflects routing.
    func todaysSkillCount() -> Int { todaysSkillSessions().count }

    /// Whether the user has any active goals at all (independent of
    /// routing). Drives whether the TODAY'S TRAINING card shows at all.
    func hasActiveGoals() -> Bool {
        !SkillProgressService.shared.activeGoalIds.isEmpty
    }
}

// MARK: - Array safe-index helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
