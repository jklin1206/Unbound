import Foundation

// MARK: - TravelOverride
//
// A Gemini-generated training plan that replaces the user's normal
// `TrainingProgram.days` for a bounded window (typically 3–14 days).
// Persisted in the `travel_overrides` collection and consumed by
// `TrainingProgram.effectiveDay(for:)` + home / Program tab lookups so
// the user sees the travel plan where the normal session would've been.
//
// Per plan, scoped narrowly — only touches the active window, expires
// automatically after `endDate`. Not abused because it's user-initiated
// via the Travel action chip.

struct TravelOverride: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    let startDate: Date
    let endDate: Date           // Inclusive — last day of travel
    let summary: String         // Coach-voice one-liner from Gemini
    let days: [TravelDay]
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        startDate: Date,
        endDate: Date,
        summary: String,
        days: [TravelDay],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.startDate = startDate
        self.endDate = endDate
        self.summary = summary
        self.days = days
        self.createdAt = createdAt
    }

    /// Active if today falls within [startDate, endDate] inclusive.
    func isActive(on date: Date = Date()) -> Bool {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        return day >= cal.startOfDay(for: startDate) && day <= cal.startOfDay(for: endDate)
    }

    /// Returns the override day corresponding to `date`, or nil if outside
    /// the window. Matches by day-offset from `startDate`.
    func day(for date: Date) -> TravelDay? {
        guard isActive(on: date) else { return nil }
        let cal = Calendar.current
        let offset = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: startDate),
            to: cal.startOfDay(for: date)
        ).day ?? 0
        return days.first { $0.dayOffset == offset }
    }
}

struct TravelDay: Codable, Hashable, Sendable {
    /// 0 = startDate, 1 = startDate + 1, etc. Days without an entry are
    /// treated as rest.
    let dayOffset: Int
    let title: String            // e.g. "BODYWEIGHT PUSH" / "REST / WALK"
    let duration: String         // e.g. "~30 MIN"
    let exercises: [String]      // Human-readable names, rendered as-is
    let isRest: Bool
}
