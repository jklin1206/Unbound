import Foundation
import SwiftUI

// MARK: - SkillTreeViewModel
//
// Backs the augmented skill-tree tab: loads all LiftRanks for the current
// user, groups them by ExerciseCatalog movement pattern, and exposes the
// build-identity aggregate rank.

@MainActor
@Observable
final class SkillTreeViewModel {
    struct PatternSection: Identifiable {
        var id: MovementPattern { pattern }
        let pattern: MovementPattern
        let ranks: [LiftRank]
        let aggregate: SubRank
    }

    var aggregateRank: SubRank = .eMinus
    var sections: [PatternSection] = []
    var loading: Bool = false

    private let rankService: RankServiceProtocol

    init(rankService: RankServiceProtocol? = nil) {
        self.rankService = rankService ?? RankService.shared
    }

    func load(userId: String) async {
        loading = true
        defer { loading = false }

        let ranks = await rankService.fetchAll(userId: userId)
        aggregateRank = await rankService.aggregateRank(userId: userId)
        sections = buildSections(ranks: ranks)
    }

    // MARK: Helpers

    private func buildSections(ranks: [LiftRank]) -> [PatternSection] {
        // Group ranks by MovementPattern via ExerciseCatalog lookup.
        var byPattern: [MovementPattern: [LiftRank]] = [:]
        for rank in ranks {
            guard let pattern = pattern(for: rank.exerciseKey) else { continue }
            byPattern[pattern, default: []].append(rank)
        }

        // Sort the sections in a consistent order matching the home-screen hero: push / pull / legs / core / arms.
        let order: [MovementPattern] = [
            .pushHorizontal, .pushVertical,
            .pullVertical, .pullHorizontal,
            .legsQuad, .legsPosterior,
            .core, .arms, .calves
        ]

        return order.compactMap { pattern in
            let ranks = byPattern[pattern] ?? []
            guard !ranks.isEmpty else { return nil }
            let aggregate = aggregateRank(for: ranks)
            let sorted = ranks.sorted { $0.currentRank.ordinal > $1.currentRank.ordinal }
            return PatternSection(pattern: pattern, ranks: sorted, aggregate: aggregate)
        }
    }

    private func pattern(for exerciseKey: String) -> MovementPattern? {
        // Direct catalog lookup first.
        if let exercise = ExerciseCatalog.exercise(named: exerciseKey) {
            for (pattern, list) in ExerciseCatalog.exercisesByPattern {
                if list.contains(where: { $0.name == exercise.name }) { return pattern }
            }
        }

        // Heuristic fallback for aliases like "squat" or "bench".
        let k = exerciseKey.lowercased()
        if k.contains("squat") { return .legsQuad }
        if k.contains("deadlift") || k.contains("rdl") || k.contains("hip thrust") { return .legsPosterior }
        if k.contains("bench") || k.contains("chest press") || k.contains("pushup") || k.contains("push-up") { return .pushHorizontal }
        if k.contains("overhead") || k.contains("ohp") || k.contains("pike pushup") || k.contains("handstand") { return .pushVertical }
        if k.contains("pullup") || k.contains("pull-up") || k.contains("chin-up") || k.contains("chinup") || k.contains("muscle-up") { return .pullVertical }
        if k.contains("row") { return .pullHorizontal }
        if k.contains("plank") || k.contains("l-sit") || k.contains("dragon flag") || k.contains("hollow") || k.contains("front lever") { return .core }
        if k.contains("curl") || k.contains("tricep") || k.contains("skull crush") || k.contains("dip") { return .arms }
        if k.contains("calf") { return .calves }
        return nil
    }

    private func aggregateRank(for ranks: [LiftRank]) -> SubRank {
        guard !ranks.isEmpty else { return .eMinus }
        let mean = Double(ranks.map(\.currentRank.ordinal).reduce(0, +)) / Double(ranks.count)
        return SubRank.nearest(for: mean)
    }
}
