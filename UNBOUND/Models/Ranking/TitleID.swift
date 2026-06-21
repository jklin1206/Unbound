import Foundation

/// Identifier for an earned Title.
struct TitleID: Codable, Hashable, Sendable {
    enum Path: Codable, Hashable, Sendable {
        case axis(AttributeKey)
        case cardKind(WeeklyVowKind)
        /// A title earned by unlocking a badge (badge id). Tier is unused for
        /// these (carried as `.gold`); the name comes from the badge itself.
        case badge(String)
        /// A cosmetic title bought in the Shop. Tier is unused for these
        /// (carried as `.gold`); the name comes from `ShopTitleCatalog`.
        case shop(String)
        /// The single personal title awarded to the #1 member on a squad
        /// season leaderboard.
        case squadSeasonWinner(Int)
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
        case .shop(let id):       return ShopTitleCatalog.displayName(for: id)
        case .squadSeasonWinner(let seasonNumber):
            return "Season \(max(1, seasonNumber)) Winner"
        }
        return "\(pathLabel) · \(tier.rawValue.capitalized)"
    }

    var rewardAssetName: String? {
        switch path {
        case .squadSeasonWinner(let seasonNumber) where max(1, seasonNumber) == 1:
            return "squad_reward_season_1_winner"
        default:
            return nil
        }
    }

    /// Convenience: the title earned by unlocking a badge.
    static func badge(_ badgeId: String) -> TitleID {
        TitleID(path: .badge(badgeId), tier: .gold)
    }

    /// Convenience: a title bought in the Shop.
    static func shop(_ id: String) -> TitleID {
        TitleID(path: .shop(id), tier: .gold)
    }

    /// Convenience: the personal title earned by finishing #1 on a squad
    /// season leaderboard.
    static func squadSeasonWinner(_ seasonNumber: Int) -> TitleID {
        TitleID(path: .squadSeasonWinner(max(1, seasonNumber)), tier: .gold)
    }
}

enum ShopTitleCatalog {
    static func displayName(for id: String) -> String {
        switch id {
        case "chalkGhost": return "Chalked Up"
        case "nightShift": return "Sleep Debt CEO"
        case "ironStatic": return "PR Pending"
        case "goldSignal": return "Aura Farmer"
        case "solarBreaker": return "Main Character Arc"
        default:
            return id
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }
}
