import Foundation

struct WeeklyHonor: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let squadId: UUID
    let weekIso: String
    let kind: Kind
    let recipientUserId: UUID
    let awardedAt: Date

    enum Kind: String, Codable, CaseIterable, Sendable {
        case mostConsistent
        case ironWill
        case clutchPerformer
        case mostImproved
        case comebackArc
        case earlyBird
        case nightGrinder
        case vowFinisher
        case supportBuff

        var displayName: String {
            switch self {
            case .mostConsistent: return "Most Consistent"
            case .ironWill: return "Iron Will"
            case .clutchPerformer: return "Clutch Performer"
            case .mostImproved: return "Most Improved"
            case .comebackArc: return "Comeback Arc"
            case .earlyBird: return "Early Bird"
            case .nightGrinder: return "Night Grinder"
            case .vowFinisher: return "Binding Vow Finisher"
            case .supportBuff: return "Support Buff"
            }
        }

        var reason: String {
            switch self {
            case .mostConsistent: return "Most distinct training days"
            case .ironWill: return "Highest average RPE"
            case .clutchPerformer: return "Tier crossings during the week"
            case .mostImproved: return "Biggest attribute delta"
            case .comebackArc: return "Returned after 7+ days then logged 3+"
            case .earlyBird: return "Most pre-7am workouts"
            case .nightGrinder: return "Most post-9pm workouts"
            case .vowFinisher: return "Completed a Binding Vow"
            case .supportBuff: return "Most linked-session participation"
            }
        }

        var iconName: String {
            switch self {
            case .mostConsistent: return "calendar.badge.checkmark"
            case .ironWill: return "flame.fill"
            case .clutchPerformer: return "bolt.fill"
            case .mostImproved: return "arrow.up.right.circle.fill"
            case .comebackArc: return "arrow.uturn.up"
            case .earlyBird: return "sunrise.fill"
            case .nightGrinder: return "moon.stars.fill"
            case .vowFinisher: return "checkmark.seal.fill"
            case .supportBuff: return "figure.2"
            }
        }

        init(from decoder: Decoder) throws {
            let rawValue = try decoder.singleValueContainer().decode(String.self)
            switch rawValue {
            case "trialFinisher":
                self = .vowFinisher
            default:
                guard let kind = Kind(rawValue: rawValue) else {
                    throw DecodingError.dataCorrupted(
                        .init(codingPath: decoder.codingPath, debugDescription: "Unknown weekly honor kind: \(rawValue)")
                    )
                }
                self = kind
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        // Temporary adapter for old call sites and persisted rows.
        static var trialFinisher: Kind { .vowFinisher }
    }
}
