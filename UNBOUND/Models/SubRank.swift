import Foundation
import SwiftUI

// MARK: - SubRank
//
// 18-step sub-rank ladder anchored to letter-rank strength standards.
// E- · E · E+ · D- · D · D+ · C- · C · C+ · B- · B · B+ · A- · A · A+ · S- · S · S+
//
// Letter ranks are the anchor; minus/plain/plus are 1/3-interval
// interpolations between adjacent letters.

enum SubRank: String, Codable, CaseIterable, Sendable, Comparable {
    case eMinus, e, ePlus
    case dMinus, d, dPlus
    case cMinus, c, cPlus
    case bMinus, b, bPlus
    case aMinus, a, aPlus
    case sMinus, s, sPlus

    var ordinal: Int {
        switch self {
        case .eMinus: return 0
        case .e:      return 1
        case .ePlus:  return 2
        case .dMinus: return 3
        case .d:      return 4
        case .dPlus:  return 5
        case .cMinus: return 6
        case .c:      return 7
        case .cPlus:  return 8
        case .bMinus: return 9
        case .b:      return 10
        case .bPlus:  return 11
        case .aMinus: return 12
        case .a:      return 13
        case .aPlus:  return 14
        case .sMinus: return 15
        case .s:      return 16
        case .sPlus:  return 17
        }
    }

    /// Letter-grade label for this sub-rank ("E-", "B+", "S", etc.).
    /// This is the primary display label used throughout the UI — e.g. rank
    /// chips, skill nodes, share cards.  Always returns `letter + modifier`.
    var displayName: String { letter + modifier }

    /// Human-readable title band ("Initiate", "Veteran", "Ascendant", etc.).
    /// Use this for new surfaces that want the nine-tier title instead of the
    /// letter-grade (e.g. Build hex phase 8+ UI).
    var rankTitleName: String { title.displayName }

    var title: RankTitle {
        switch ordinal {
        case 0...1: return .initiate
        case 2...3: return .novice
        case 4...5: return .apprentice
        case 6...7: return .forged
        case 8...9: return .veteran
        case 10...11: return .honed
        case 12...13: return .vessel
        case 14...15: return .unbound
        default: return .ascendant
        }
    }

    /// Letter portion only ("E", "B", "S"). Used for coarse UI / color bucketing.
    var letter: String {
        switch self {
        case .eMinus, .e, .ePlus: return "E"
        case .dMinus, .d, .dPlus: return "D"
        case .cMinus, .c, .cPlus: return "C"
        case .bMinus, .b, .bPlus: return "B"
        case .aMinus, .a, .aPlus: return "A"
        case .sMinus, .s, .sPlus: return "S"
        }
    }

    /// "-" | "" | "+"
    var modifier: String {
        switch self {
        case .eMinus, .dMinus, .cMinus, .bMinus, .aMinus, .sMinus: return "-"
        case .ePlus, .dPlus, .cPlus, .bPlus, .aPlus, .sPlus:       return "+"
        default: return ""
        }
    }

    static func < (lhs: SubRank, rhs: SubRank) -> Bool {
        lhs.ordinal < rhs.ordinal
    }

    /// Advance by `n` steps, capped at `.sPlus`.
    func advanced(by n: Int = 1) -> SubRank {
        let target = min(17, max(0, ordinal + n))
        return SubRank.allCases.first(where: { $0.ordinal == target }) ?? self
    }

    /// Decay by `n` steps, floored at `.eMinus`.
    func decayed(by n: Int = 1) -> SubRank {
        let target = min(17, max(0, ordinal - n))
        return SubRank.allCases.first(where: { $0.ordinal == target }) ?? self
    }

    /// Nearest sub-rank for a fractional ladder position (0.0 = E-, 17.0 = S+).
    static func nearest(for position: Double) -> SubRank {
        let clamped = max(0.0, min(17.0, position))
        let rounded = Int(clamped.rounded())
        return SubRank.allCases.first(where: { $0.ordinal == rounded }) ?? .eMinus
    }

    /// Index of a letter's plain tier (E=1, D=4, C=7, B=10, A=13, S=16).
    static func ordinalForLetter(_ letter: String) -> Int {
        switch letter.uppercased() {
        case "E": return 1
        case "D": return 4
        case "C": return 7
        case "B": return 10
        case "A": return 13
        case "S": return 16
        default:  return 0
        }
    }
}

enum RankTitle: String, Codable, CaseIterable, Sendable {
    case initiate
    case novice
    case apprentice
    case forged
    case veteran
    case honed
    case vessel
    case unbound
    case ascendant

    var displayName: String {
        switch self {
        case .initiate: return "Initiate"
        case .novice: return "Novice"
        case .apprentice: return "Apprentice"
        case .forged: return "Forged"
        case .veteran: return "Veteran"
        case .honed: return "Honed"
        case .vessel: return "Vessel"
        case .unbound: return "Unbound"
        case .ascendant: return "Ascendant"
        }
    }

    var assetName: String { "rank_title_\(rawValue)" }

    static func legacyLetterFallback(_ letter: String) -> RankTitle {
        switch letter.uppercased().prefix(1) {
        case "E": return .initiate
        case "D": return .apprentice
        case "C": return .veteran
        case "B": return .honed
        case "A": return .unbound
        case "S": return .ascendant
        default: return .initiate
        }
    }
}

// MARK: - Rank-up notification payload

struct RankAdvance: Identifiable, Sendable {
    let id: UUID
    let userId: String
    let exerciseKey: String
    let displayName: String
    let fromRank: SubRank
    let toRank: SubRank
    let at: Date
    let userBodyweightKg: Double?

    init(
        userId: String,
        exerciseKey: String,
        displayName: String,
        fromRank: SubRank,
        toRank: SubRank,
        at: Date = Date(),
        userBodyweightKg: Double? = nil
    ) {
        self.id = UUID()
        self.userId = userId
        self.exerciseKey = exerciseKey
        self.displayName = displayName
        self.fromRank = fromRank
        self.toRank = toRank
        self.at = at
        self.userBodyweightKg = userBodyweightKg
    }
}

extension Notification.Name {
    static let rankAdvanced = Notification.Name("unbound.rankAdvanced")
}

// MARK: - SubRank tint bridge
//
// Legacy letter ranks are still present in a few older Home surfaces while
// the app migrates fully to named SkillTier badges. Keep their color output
// tied to SkillTier so the same badge ladder is used everywhere.

extension SubRank {
    /// Steady-state tint used by rank displays.
    var regionTint: Color {
        asSkillTier.rewardTint
    }

    /// True when the rank should render with a holographic shimmer (S / S+ only).
    var usesHolographicShimmer: Bool {
        self == .s || self == .sPlus
    }
}

extension Color {
    /// Gold reserved for S-tier ranks.
    static let unboundGold = Color(.sRGB, red: 1.0, green: 0.784, blue: 0.341, opacity: 1.0) // #FFC857
}
