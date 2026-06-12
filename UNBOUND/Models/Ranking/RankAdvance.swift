import Foundation
import SwiftUI

// MARK: - Rank-up notification payload
//
// Emitted on `.rankAdvanced` when a lift (or an attribute-axis crossing
// synthesized by AttributeRankUpToast) reaches a new RankTier. Listened for
// by RankUpCinematic / BadgeService.

struct RankAdvance: Identifiable, Sendable {
    let id: UUID
    let userId: String
    let exerciseKey: String
    let displayName: String
    let fromRank: RankTier
    let toRank: RankTier
    let at: Date
    let userBodyweightKg: Double?

    init(
        userId: String,
        exerciseKey: String,
        displayName: String,
        fromRank: RankTier,
        toRank: RankTier,
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

extension Color {
    /// Gold reserved for S-tier ranks.
    static let unboundGold = Color(.sRGB, red: 1.0, green: 0.784, blue: 0.341, opacity: 1.0) // #FFC857
}
