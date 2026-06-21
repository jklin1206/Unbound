import Foundation

/// Legacy weekly-vow slot identifier. Binding Vows v2 models a vow by lane/bet,
/// not by this enum — it survives ONLY as the persisted associated value of
/// `TitleID.Path.cardKind` (and its `TitleCatalog` display names). Do not wire
/// new behavior to it.
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
    /// Display label for the persisted `cardKind` Title path.
    var displayName: String {
        switch self {
        case .ember: return "Recovery Vow"
        case .overdrive: return "Finisher Vow"
        case .apex: return "Limit Vow"
        }
    }
}

typealias TrialCardKind = WeeklyVowKind
