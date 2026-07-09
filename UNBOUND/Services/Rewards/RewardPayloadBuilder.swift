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
        copy.exerciseRanks = exerciseRanks(
            from: result,
            liftProgress: copy.liftProgress,
            personalRecords: copy.personalRecords
        )
        return copy
    }

    /// Unified per-exercise rank cards: one card per movement (skills AND lifts),
    /// each carrying the rank badge earned, progress toward the next rank, and any
    /// PR. Skills come from the proof result (highest tier cleared + the peak
    /// performance for the progress bar); lifts come from `liftProgress`.
    static func exerciseRanks(
        from result: ProofEngineResult,
        liftProgress: [LiftProgressReward],
        personalRecords: [PersonalRecordReward]
    ) -> [ExerciseRankReward] {
        var cards: [ExerciseRankReward] = []

        // ── Skills: group cleared standards by skill; the top tier is the badge.
        let bySkill = Dictionary(grouping: result.standardsCleared, by: \.skillId)
        for (skillId, standards) in bySkill {
            guard let top = standards.max(by: { $0.tier < $1.tier }) else { continue }

            let proofs = result.achievedProofs.filter { $0.skillId == skillId }
            let peakRepProof = proofs.filter { $0.unit == .reps }.max { $0.magnitude < $1.magnitude }
            let peakHoldProof = proofs.filter { $0.unit == .seconds }.max { $0.magnitude < $1.magnitude }
            let peakReps = peakRepProof.map { Int($0.magnitude.rounded()) } ?? 0
            let peakSeconds = peakHoldProof.map { Int($0.magnitude.rounded()) } ?? 0
            // The movement the peak was actually logged as — nodeProgress
            // name-gates authored variant ladders with it, so the progress bar
            // and micro-target never point into a rung that names a different
            // variant (1 nordic curl is not the one-leg Unbound rung).
            let loggedKey = peakRepProof?.exerciseName ?? peakHoldProof?.exerciseName

            let prog = SkillStandards.nodeProgress(skillId: skillId, exerciseKey: loggedKey, peakReps: peakReps, peakSeconds: peakSeconds)
            let nextText = SkillStandards.nodeNextThresholdText(skillId: skillId, exerciseKey: loggedKey, peakReps: peakReps, peakSeconds: peakSeconds)
            let fromTier = result.multiRankEvent?.skillId == skillId ? result.multiRankEvent?.fromTier : nil

            cards.append(
                ExerciseRankReward(
                    id: "skill:\(skillId)",
                    exerciseName: top.skillTitle,
                    skillId: skillId,
                    rank: top.tier,
                    didRankUp: true,
                    fromRank: fromTier,
                    progressToNext: prog?.fraction ?? 1.0,
                    nextRank: prog?.next ?? top.tier.next,
                    nextThresholdText: nextText,
                    personalBestText: bestText(for: top.skillTitle, in: result.newBests),
                    family: skillFamily(skillId: skillId, title: top.skillTitle)
                )
            )
        }
        cards.sort { lhs, rhs in
            if lhs.rank == rhs.rank { return lhs.exerciseName < rhs.exerciseName }
            return lhs.rank.ordinal > rhs.rank.ordinal   // highest rank first
        }

        // ── Lifts: each lift band → a card with its progress to the next tier.
        let liftCards = liftProgress.map { lift in
            ExerciseRankReward(
                id: "lift:\(lift.liftName)",
                exerciseName: lift.liftName,
                skillId: nil,
                rank: lift.currentTier,
                didRankUp: lift.didAdvanceTier,
                fromRank: lift.didAdvanceTier ? lift.fromTier : nil,
                progressToNext: lift.toProgress,
                nextRank: lift.currentTier.next,
                nextThresholdText: nil,
                personalBestText: prText(for: lift.liftName, in: personalRecords),
                family: lift.family
            )
        }

        return cards + liftCards
    }

    private static func bestText(for exerciseName: String, in bests: [PersonalBest]) -> String? {
        guard let best = bests.first(where: {
            MovementCatalog.normalized($0.exerciseName) == MovementCatalog.normalized(exerciseName)
        }) else { return nil }
        let unit = best.unit == .seconds ? "s" : (best.unit == .reps ? " reps" : " \(best.unit.rawValue)")
        return "New best · \(format(best.value))\(unit)"
    }

    private static func prText(for liftName: String, in records: [PersonalRecordReward]) -> String? {
        records.first { MovementCatalog.normalized($0.liftName) == MovementCatalog.normalized(liftName) }
            .map { "New best · \($0.valueText)" }
    }

    private static func skillFamily(skillId: String, title: String) -> LiftRewardFamily {
        let text = "\(skillId) \(title)".lowercased()
        if text.hasPrefix("pp.") || text.contains("pull") || text.contains("chin") || text.contains("row") { return .pull }
        if text.hasPrefix("ld.") || text.contains("squat") || text.contains("lunge") || text.contains("pistol") || text.contains("nordic") { return .legs }
        if text.hasPrefix("cl.") || text.contains("sit") || text.contains("lever") || text.contains("hollow") || text.contains("dragon") || text.contains("plank") { return .core }
        if text.hasPrefix("hs.") || text.hasPrefix("pl.") || text.hasPrefix("cal.") || text.contains("handstand") || text.contains("push") || text.contains("dip") || text.contains("planche") { return .press }
        if text.contains("jump") || text.contains("clap") || text.contains("explosive") { return .explosive }
        return .general
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
