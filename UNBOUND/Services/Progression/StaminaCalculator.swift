import Foundation

enum StaminaTier: String, CaseIterable, Sendable {
    case sedentary, active, conditioned, aerobic, elite

    var displayName: String {
        switch self {
        case .sedentary:   return "Sedentary"
        case .active:      return "Active"
        case .conditioned: return "Conditioned"
        case .aerobic:     return "Aerobic"
        case .elite:       return "Elite"
        }
    }

    static func forValue(_ value: Int) -> StaminaTier {
        switch value {
        case ..<20:  return .sedentary
        case ..<40:  return .active
        case ..<60:  return .conditioned
        case ..<80:  return .aerobic
        default:     return .elite
        }
    }
}

struct StaminaStat: Equatable, Sendable {
    let value: Int
    let tier: StaminaTier
    let weeklyTrend: Double

    static let empty = StaminaStat(value: 0, tier: .sedentary, weeklyTrend: 0)
}

struct StaminaCalculator {

    /// Benchmark for a "100" score: ~250 intensity-minutes over 28 days with
    /// half-life decay. Roughly 5 steady runs of 40min or 7 moderate bike
    /// sessions at 45min within the window.
    private static let maxIntensityMinutes: Double = 250
    private static let halfLifeDays: Double = 7
    private static let windowDays: Int = 28

    static func compute(sessions: [CardioSession], referenceDate: Date = .now) -> StaminaStat {
        guard !sessions.isEmpty else { return .empty }

        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -windowDays,
            to: referenceDate
        ) ?? referenceDate

        let windowed = sessions.filter { $0.date >= cutoff && $0.date <= referenceDate }
        guard !windowed.isEmpty else { return .empty }

        let score = decayWeighted(sessions: windowed, referenceDate: referenceDate)
        let normalized = Int((score / maxIntensityMinutes * 100).rounded())
        let clamped = max(0, min(100, normalized))
        let tier = StaminaTier.forValue(clamped)

        let weeklyTrend = trend(sessions: sessions, referenceDate: referenceDate)

        return StaminaStat(value: clamped, tier: tier, weeklyTrend: weeklyTrend)
    }

    private static func decayWeighted(sessions: [CardioSession], referenceDate: Date) -> Double {
        sessions.reduce(0) { sum, session in
            let age = referenceDate.timeIntervalSince(session.date) / 86_400
            let decay = pow(0.5, age / halfLifeDays)
            let base = Double(session.durationMinutes) * session.type.intensityFactor
            let effortBonus = 1.0 + (Double(session.perceivedEffort - 5) / 20.0)
            return sum + (base * max(0.5, effortBonus) * decay)
        }
    }

    private static func trend(sessions: [CardioSession], referenceDate: Date) -> Double {
        let cal = Calendar.current
        guard let thisWeekStart = cal.date(byAdding: .day, value: -7, to: referenceDate),
              let priorWeekStart = cal.date(byAdding: .day, value: -14, to: referenceDate) else {
            return 0
        }

        let thisWeek = sessions
            .filter { $0.date >= thisWeekStart && $0.date <= referenceDate }
            .reduce(0.0) { $0 + Double($1.durationMinutes) * $1.type.intensityFactor }

        let priorWeek = sessions
            .filter { $0.date >= priorWeekStart && $0.date < thisWeekStart }
            .reduce(0.0) { $0 + Double($1.durationMinutes) * $1.type.intensityFactor }

        guard priorWeek > 0 else { return thisWeek > 0 ? 1.0 : 0 }
        return (thisWeek - priorWeek) / priorWeek
    }
}
