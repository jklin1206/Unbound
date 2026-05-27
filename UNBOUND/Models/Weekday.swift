// UNBOUND/Models/Weekday.swift
import Foundation

enum Weekday: String, Codable, CaseIterable, Identifiable, Hashable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: String { rawValue }

    var short: String {
        switch self {
        case .monday: return L10n.string(.weekdayMondayShort, defaultValue: "Mon")
        case .tuesday: return L10n.string(.weekdayTuesdayShort, defaultValue: "Tue")
        case .wednesday: return L10n.string(.weekdayWednesdayShort, defaultValue: "Wed")
        case .thursday: return L10n.string(.weekdayThursdayShort, defaultValue: "Thu")
        case .friday: return L10n.string(.weekdayFridayShort, defaultValue: "Fri")
        case .saturday: return L10n.string(.weekdaySaturdayShort, defaultValue: "Sat")
        case .sunday: return L10n.string(.weekdaySundayShort, defaultValue: "Sun")
        }
    }

    /// Gregorian weekday integer (1 = Sunday … 7 = Saturday) for use with
    /// `UNCalendarNotificationTrigger` date components.
    var calendarWeekday: Int {
        switch self {
        case .sunday:    return 1
        case .monday:    return 2
        case .tuesday:   return 3
        case .wednesday: return 4
        case .thursday:  return 5
        case .friday:    return 6
        case .saturday:  return 7
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
