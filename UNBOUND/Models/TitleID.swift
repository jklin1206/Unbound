import Foundation

/// Identifier for an earned Title. 9 paths × 3 tiers = 27 total Titles.
struct TitleID: Codable, Hashable, Sendable {
    enum Path: Codable, Hashable, Sendable {
        case axis(AttributeKey)
        case cardKind(WeeklyVowKind)
        /// A title earned by unlocking a badge (badge id). Tier is unused for
        /// these (carried as `.gold`); the name comes from the badge itself.
        case badge(String)
    }
    enum Tier: String, Codable, CaseIterable, Sendable {
        case bronze
        case silver
        case gold
    }
    let path: Path
    let tier: Tier
}

// MARK: - Display helpers

extension TitleID {
    var displayName: String {
        let pathLabel: String
        switch path {
        case .axis(let key):      pathLabel = key.buildVocab
        case .cardKind(let kind): pathLabel = kind.displayName
        case .badge(let id):      return BadgeCatalog.all.first { $0.id == id }?.displayName ?? "Badge"
        }
        return "\(pathLabel) · \(tier.rawValue.capitalized)"
    }

    /// Convenience: the title earned by unlocking a badge.
    static func badge(_ badgeId: String) -> TitleID {
        TitleID(path: .badge(badgeId), tier: .gold)
    }
}
