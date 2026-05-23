import Foundation

/// Which vow slot in the 3-card weekly trio.
enum WeeklyVowKind: String, CaseIterable, Sendable {
    case ember
    case overdrive
    case apex
}

extension WeeklyVowKind: Codable {
    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        switch rawValue {
        case Self.ember.rawValue, "aligned":
            self = .ember
        case Self.overdrive.rawValue, "growth":
            self = .overdrive
        case Self.apex.rawValue, "prestige":
            self = .apex
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown weekly vow kind: \(rawValue)")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension WeeklyVowKind {
    var displayName: String {
        switch self {
        case .ember: return "Ember"
        case .overdrive: return "Overdrive"
        case .apex: return "Apex"
        }
    }

    var shortDescription: String {
        switch self {
        case .ember:
            return "Recovery-safe low-day vow"
        case .overdrive:
            return "After-workout finisher vow"
        case .apex:
            return "Dedicated weekend event vow"
        }
    }

    // Temporary adapters for old call sites and persisted raw values.
    static var aligned: WeeklyVowKind { .ember }
    static var growth: WeeklyVowKind { .overdrive }
    static var prestige: WeeklyVowKind { .apex }

    var completionBonusOverallLevelXP: Int {
        switch self {
        case .ember: return 60
        case .overdrive: return 120
        case .apex: return 240
        }
    }

    var vowIdComponent: String {
        rawValue
    }
}

typealias TrialCardKind = WeeklyVowKind
