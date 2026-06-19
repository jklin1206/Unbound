import Foundation

/// The single 9-tier ladder: Initiate → Unbound. This is the one canonical
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
/// Unbound) are brand-flavored. Only Vessel/Ascendant/Unbound crossings
/// trigger the full chain-shatter cinematic.
///
/// Raw value is the 0-based ordinal (so `<`, `.max()`, and `rawValue` math keep
/// working). Codable is custom + tolerant: it decodes BOTH the legacy Int form
/// (skill tiers, cosmetic highest) AND the legacy String form (trial progress,
/// including the historical `"honed"` alias for Master), and encodes the Int
/// rawValue — positions are stable across the 2026-06 crown rename, so no
/// on-disk migration is needed (see `fromLegacyToken`).
enum RankTier: Int, CaseIterable, Sendable, Comparable {
    case initiate    = 0
    case novice      = 1
    case apprentice  = 2
    case forged      = 3
    case veteran     = 4
    case master      = 5
    case vessel      = 6
    case ascendant   = 7
    case unbound     = 8

    var displayName: String {
        switch self {
        case .initiate:   return "Initiate"
        case .novice:     return "Novice"
        case .apprentice: return "Apprentice"
        case .forged:     return "Forged"
        case .veteran:    return "Veteran"
        case .master:     return "Master"
        case .vessel:     return "Vessel"
        // Brand decision: "Unbound" is the PEAK label — the app's pinnacle.
        // 2026-06: case names/tokens were realigned to match the display names
        // (the earlier label-only swap left `.ascendant` as the peak case).
        // `.unbound` now IS rawValue 8. Legacy on-disk crown tokens decode with
        // their old meanings via `fromLegacyToken`. See ONE-METRIC log.
        case .ascendant:  return "Ascendant"
        case .unbound:    return "Unbound"
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
        case .ascendant:  return "ascendant"
        case .unbound:    return "unbound"
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

    /// True for the three crown tiers — Vessel/Ascendant/Unbound.
    var deservesCinematic: Bool { self >= .vessel }

    /// Next tier up, or nil if already at Unbound.
    var next: RankTier? { RankTier(rawValue: rawValue + 1) }

    /// Nearest tier for a fractional 0–8 ladder position.
    static func nearest(for position: Double) -> RankTier {
        let clamped = max(0.0, min(8.0, position))
        return RankTier(rawValue: Int(clamped.rounded())) ?? .initiate
    }

    /// Advance by `n` tiers, capped at Ascendant.
    func advanced(by n: Int = 1) -> RankTier { RankTier(rawValue: min(8, max(0, rawValue + n))) ?? self }

    /// Decay by `n` tiers, floored at Initiate.
    func decayed(by n: Int = 1) -> RankTier { RankTier(rawValue: min(8, max(0, rawValue - n))) ?? self }

    static func < (lhs: RankTier, rhs: RankTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: Tolerant decoding

    /// Resolve a STORED legacy string to a tier. Handles the historical
    /// `"honed"` → Master alias and single-letter legacy grades (E…S).
    ///
    /// Crown caveat: string tokens on disk predate the 2026-06 crown rename, so
    /// the two crown tokens keep their LEGACY meanings — "ascendant" was the
    /// peak (now `.unbound`) and "unbound" was tier 7 (now `.ascendant`). New
    /// writes encode the Int rawValue, so no new-style string ever reaches this.
    static func fromLegacyToken(_ raw: String) -> RankTier {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if token == "honed" { return .master }
        if token == "ascendant" { return .unbound }
        if token == "unbound" { return .ascendant }
        if let exact = RankTier.allCases.first(where: { $0.token == token }) { return exact }
        return legacyLetterFallback(token)
    }

    static func legacyLetterFallback(_ letter: String) -> RankTier {
        switch letter.uppercased().prefix(1) {
        case "E": return .initiate
        case "D": return .apprentice
        case "C": return .veteran
        case "B": return .master
        case "A": return .ascendant
        case "S": return .unbound
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
        // Legacy String form (trial progress, incl. "honed"; crown tokens carry
        // their pre-rename meanings — see fromLegacyToken).
        if let stringValue = try? container.decode(String.self) {
            self = RankTier.fromLegacyToken(stringValue)
            return
        }
        self = .initiate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // Int rawValue: positions are stable across renames (the decoder's
        // String path is legacy-only — see fromLegacyToken's crown caveat).
        try container.encode(rawValue)
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
