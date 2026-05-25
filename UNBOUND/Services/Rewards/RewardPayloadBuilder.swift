import Foundation

enum RewardPayloadBuilder {
    static func attachProofRewards(
        _ result: ProofEngineResult,
        to summary: WorkoutRewardSequenceSummary
    ) -> WorkoutRewardSequenceSummary {
        var copy = summary
        let payload = proofPayload(from: result)
        copy.beats = payload.beats
        copy.tally = payload.tally
        copy.emblemIgnition = payload.emblemIgnition
        return copy
    }

    static func proofPayload(from result: ProofEngineResult) -> ProofRewardPayload {
        let standards = result.standardsCleared.sorted {
            if $0.skillId == $1.skillId {
                return $0.tier < $1.tier
            }
            if $0.tier == $1.tier {
                return $0.skillTitle < $1.skillTitle
            }
            return $0.tier < $1.tier
        }

        var beats = standards.map { standard in
            RewardBeat(
                id: "standard:\(standard.id)",
                kind: .standardCleared,
                title: "\(standard.tier.displayName) cleared",
                subtitle: standard.skillTitle,
                skillId: standard.skillId,
                skillTitle: standard.skillTitle,
                tier: standard.tier,
                sortRank: standard.tier.rawValue
            )
        }

        if beats.isEmpty {
            beats = result.unlocks.map { unlock in
                RewardBeat(
                    id: "unlock:\(unlock.id)",
                    kind: .skillUnlock,
                    title: "\(unlock.tier.displayName) unlocked",
                    subtitle: unlock.skillTitle,
                    skillId: unlock.skillId,
                    skillTitle: unlock.skillTitle,
                    tier: unlock.tier,
                    sortRank: unlock.tier.rawValue
                )
            }
        }

        if beats.isEmpty {
            beats = result.newBests.map { best in
                RewardBeat(
                    id: "best:\(best.id)",
                    kind: .newBest,
                    title: "New best",
                    subtitle: "\(best.exerciseName) \(format(best.value)) \(best.unit.rawValue)",
                    skillId: nil,
                    skillTitle: nil,
                    tier: nil,
                    sortRank: 0
                )
            }
        }

        let tally = RewardTally(
            standardsCleared: result.standardsCleared.count,
            unlocksGained: result.unlocks.count,
            ranksAdvanced: result.multiRankEvent?.ranksAdvanced ?? 0,
            attributesGained: [:],
            newBests: result.newBests.count
        )

        return ProofRewardPayload(
            beats: beats,
            tally: tally,
            emblemIgnition: result.multiRankEvent != nil || !result.unlocks.isEmpty
        )
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.2f", value)
    }
}

struct ProofRewardPayload: Hashable, Sendable {
    var beats: [RewardBeat]
    var tally: RewardTally
    var emblemIgnition: Bool

    static let empty = ProofRewardPayload(beats: [], tally: .empty, emblemIgnition: false)
}
