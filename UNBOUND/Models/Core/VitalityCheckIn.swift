import Foundation

enum VitalityCheckInSignal: String, Codable, CaseIterable, Identifiable, Sendable {
    case restDay = "rest-day"
    case easyWalkOrMobility = "easy-walk-mobility"
    case sleep = "sleep"
    case hydrationProtein = "hydration-protein"
    case deload = "deload"

    var id: String { rawValue }

    var token: String {
        "vitality:\(rawValue)"
    }

    var baseXP: Double {
        switch self {
        case .restDay: return 6
        case .easyWalkOrMobility: return 4
        case .sleep: return 3
        case .hydrationProtein: return 2
        case .deload: return 8
        }
    }
}

struct VitalityRewardRecord: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    let sourceLogId: String
    let awardedAt: Date
    let localDay: String
    let localWeek: String
    let signals: [VitalityCheckInSignal]
    let signalXP: Double
    let weeklyBonusXP: Double

    var totalXP: Double {
        signalXP + weeklyBonusXP
    }
}
