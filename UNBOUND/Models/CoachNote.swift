import Foundation

// MARK: - CoachNote
//
// One-per-day AI-generated insight surfaced on Home as a small card.
// Bounded to a single Gemini call per user per calendar day — the
// service caches to avoid regenerating on every home appear.

struct CoachNote: Codable, Identifiable, Sendable, Equatable {
    let id: String                 // "{userId}:{yyyy-MM-dd}"
    let userId: String
    let text: String               // 1-2 sentence coach-voice read
    let createdAt: Date

    init(userId: String, text: String, createdAt: Date = Date()) {
        let key = Self.dayKey(for: createdAt)
        self.id = "\(userId):\(key)"
        self.userId = userId
        self.text = text
        self.createdAt = createdAt
    }

    static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: date)
    }
}
