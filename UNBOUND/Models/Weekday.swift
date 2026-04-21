// UNBOUND/Models/Weekday.swift
import Foundation

enum Weekday: String, Codable, CaseIterable, Identifiable, Hashable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: String { rawValue }

    var short: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }

    /// Initialize from a Date using the given calendar. Returns nil only if the
    /// calendar returns an unexpected weekday component (shouldn't happen in
    /// practice — Gregorian always returns 1–7).
    init?(from date: Date, calendar: Calendar = .current) {
        let weekdayNumber = calendar.component(.weekday, from: date)
        // Gregorian convention: 1 = Sunday, 2 = Monday, ..., 7 = Saturday.
        switch weekdayNumber {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }
}
