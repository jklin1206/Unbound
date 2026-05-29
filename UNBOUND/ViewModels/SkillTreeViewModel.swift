import Foundation
import SwiftUI

// MARK: - SkillTreeViewModel
//
// Backs the skill-tree tab. Loads the build-identity aggregate rank for the
// current user. Per-lift pattern sections (LiftRank-based) were removed
// with the muscle-ranking pipeline deletion (rank-cleanup-v1).

@MainActor
@Observable
final class SkillTreeViewModel {
    struct PatternSection: Identifiable {
        var id: String { pattern.rawValue }
        let pattern: MovementPattern
        let ranks: [PatternLiftEntry]
        let aggregate: RankTier
    }

    struct PatternLiftEntry: Identifiable {
        let id: String
        let displayName: String
        let currentRank: RankTier
    }

    var aggregateRank: RankTier = .initiate
    var sections: [PatternSection] = []
    var loading: Bool = false

    private let rankService: RankServiceProtocol

    init(rankService: RankServiceProtocol? = nil) {
        self.rankService = rankService ?? RankService.shared
    }

    func load(userId: String) async {
        loading = true
        defer { loading = false }
        aggregateRank = await rankService.aggregateRank(userId: userId)
        // sections intentionally empty — LiftRank pipeline removed
    }
}
