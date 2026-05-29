import Foundation

/// The single 9-tier ladder: Initiate → Ascendant. This is the one canonical
/// "rank / tier" type for the whole app — per-skill tiers, per-movement/-lift
/// tiers, attribute rank titles, and overall rank all speak it.
///
/// Phase 1 of the rank-vocabulary consolidation (see
/// docs/RANK-VOCABULARY-CONSOLIDATION.md): this merges the former `SkillTier`
/// (Int 0–8) and `RankTitle` (String) enums — which had the same nine names —
/// into one type. Both old names remain as typealiases so existing call sites
/// compile unchanged.
///
/// Bottom 4 (Initiate–Forged) are quiet trainee tiers. Top 5 (Veteran–
/// Ascendant) are brand-flavored. Only Vessel/Unbound/Ascendant crossings
/// trigger the full chain-shatter cinematic.
///
/// Raw value is the 0-based ordinal (so `<`, `.max()`, and `rawValue` math keep
/// working). Codable is custom + tolerant: it decodes BOTH the legacy Int form
/// (skill tiers, cosmetic highest) AND the legacy String form (trial progress,
/// including the historical `"honed"` alias for Master), and encodes the
/// case-name token — so no on-disk migration is needed.
enum RankTier: Int, CaseIterable, Sendable, Comparable {
    case initiate    = 0
    case novice      = 1
    case apprentice  = 2
    case forged      = 3
    case veteran     = 4
    case master      = 5
    case vessel      = 6
    case unbound     = 7
    case ascendant   = 8

    var displayName: String {
        switch self {
        case .initiate:   return "Initiate"
        case .novice:     return "Novice"
        case .apprentice: return "Apprentice"
        case .forged:     return "Forged"
        case .veteran:    return "Veteran"
        case .master:     return "Master"
        case .vessel:     return "Vessel"
        case .unbound:    return "Unbound"
        case .ascendant:  return "Ascendant"
        }
    }

    /// Stable lowercase token (the former `RankTitle` String rawValue). Used to
    /// build asset names and as the on-disk Codable representation, so badge
    /// art (`rank_title_*`, `avatar_frame_*`) and persisted blobs stay stable
    /// even though the in-memory raw value is now an Int.
    var token: String {
        switch self {
        case .initiate:   return "initiate"
        case .novice:     return "novice"
        case .apprentice: return "apprentice"
        case .forged:     return "forged"
        case .veteran:    return "veteran"
        case .master:     return "master"
        case .vessel:     return "vessel"
        case .unbound:    return "unbound"
        case .ascendant:  return "ascendant"
        }
    }

    /// 1-based tier number (the former `RankTitle.ordinal`), for user-facing
    /// "Tier 5" style display and the `isNamedTier` threshold.
    var ordinal: Int { rawValue + 1 }

    /// Asset name for the shield badge image in RankTitles/.
    var assetName: String { "rank_title_\(token)" }

    /// Tiers that trigger the full chain-shatter cinematic on advancing.
    /// Lower tiers use the quiet bloom toast.
    var isFlagshipMoment: Bool { self >= .vessel }

    /// "Named tiers" (Veteran+) get the brand-flavored treatment.
    var isNamedTier: Bool { self >= .veteran }

    /// True for the three crown tiers — Vessel/Unbound/Ascendant.
    var deservesCinematic: Bool { self >= .vessel }

    /// Next tier up, or nil if already at Ascendant.
    var next: RankTier? { RankTier(rawValue: rawValue + 1) }

    static func < (lhs: RankTier, rhs: RankTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: Tolerant decoding

    /// Resolve a stored token/legacy string to a tier. Handles the historical
    /// `"honed"` → Master alias and single-letter legacy grades (E…S).
    static func fromToken(_ raw: String) -> RankTier {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if token == "honed" { return .master }
        if let exact = RankTier.allCases.first(where: { $0.token == token }) { return exact }
        return legacyLetterFallback(token)
    }

    static func legacyLetterFallback(_ letter: String) -> RankTier {
        switch letter.uppercased().prefix(1) {
        case "E": return .initiate
        case "D": return .apprentice
        case "C": return .veteran
        case "B": return .master
        case "A": return .unbound
        case "S": return .ascendant
        default:  return .initiate
        }
    }
}

extension RankTier: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Legacy Int form (skill tiers, cosmetic highest).
        if let intValue = try? container.decode(Int.self),
           let tier = RankTier(rawValue: intValue) {
            self = tier
            return
        }
        // Legacy / current String form (trial progress, incl. "honed").
        if let stringValue = try? container.decode(String.self) {
            self = RankTier.fromToken(stringValue)
            return
        }
        self = .initiate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(token)
    }
}

// MARK: - Back-compat aliases
//
// The two former enums collapse into `RankTier`. Aliases keep every existing
// call site (`SkillTier`, `RankTitle`) compiling unchanged.

typealias SkillTier = RankTier
typealias RankTitle = RankTier

extension RankTier {
    /// Identity passthroughs kept for call sites that still bridge between the
    /// old two types. Both now resolve to the same `RankTier`.
    var asSkillTier: RankTier { self }
    var rankTitle: RankTier { self }
}

// MARK: - SkillTierAdvance

/// Emitted by RankService.ingest when a skill advances. Carries enough
/// payload for cinematic dispatchers to render the right effect.
struct SkillTierAdvance: Equatable, Sendable, Identifiable {
    let skillId: String
    let from: RankTier
    let to: RankTier

    /// Stable id for SwiftUI fullScreenCover(item:) usage.
    var id: String { "\(skillId):\(from.rawValue)→\(to.rawValue)" }

    /// Whether this advance lands on a flagship tier (Vessel+) and should
    /// trigger the chain-shatter cinematic instead of the quiet bloom.
    var isFlagship: Bool { to.isFlagshipMoment }
}

extension Notification.Name {
    /// Emitted by RankService.ingest when a skill advances. The `object`
    /// payload is a `SkillTierAdvance`.
    static let skillTierAdvanced = Notification.Name("unbound.skillTierAdvanced")
}

// MARK: - SubRank → RankTier bridge

extension SubRank {
    /// Convert a SubRank to the nearest RankTier (2:1 ordinal banding).
    var asSkillTier: RankTier {
        switch ordinal {
        case 0...1:   return .initiate
        case 2...3:   return .novice
        case 4...5:   return .apprentice
        case 6...7:   return .forged
        case 8...9:   return .veteran
        case 10...11: return .master
        case 12...13: return .vessel
        case 14...15: return .unbound
        default:      return .ascendant
        }
    }
}
