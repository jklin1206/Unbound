import Foundation

/// Identifier for an earned Title. 9 paths × 3 tiers = 27 total Titles.
struct TitleID: Codable, Hashable, Sendable {
    enum Path: Codable, Hashable, Sendable {
        case axis(AttributeKey)
        case cardKind(TrialCardKind)
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
        case .cardKind(let kind): pathLabel = kind.rawValue.capitalized
        }
        return "\(pathLabel) · \(tier.rawValue.capitalized)"
    }
}
