import Foundation

struct RecoveryPlan: Codable {
    var sleepHoursTarget: Double
    var restDaysPerWeek: Int
    var activities: [RecoveryActivity]
    var notes: String
}

struct RecoveryActivity: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String
    var durationMinutes: Int
    var frequency: String
}
