import Foundation

enum WorkoutProofSource: String, Codable, CaseIterable, Sendable {
    case generated
    case edited
    case savedWorkout
    case custom
    case skillPractice
    case vow
    case retest
    case imported
}

struct SkillStandard: Codable, Hashable, Sendable, Identifiable {
    var skillId: String
    var skillTitle: String
    var tier: SkillTier
    var criterion: TierCriterion
    var proofFamily: ProofFamily

    var id: String { "\(skillId):\(tier.rawValue)" }
}

struct SkillUnlock: Codable, Hashable, Sendable, Identifiable {
    var skillId: String
    var skillTitle: String
    var tier: SkillTier

    var id: String { "\(skillId):\(tier.rawValue)" }
}

struct RankAdvancement: Codable, Hashable, Sendable, Identifiable {
    var skillId: String
    var skillTitle: String
    var fromTier: SkillTier?
    var toTier: SkillTier
    var ranksAdvanced: Int

    var id: String {
        "\(skillId):\(fromTier?.rawValue ?? -1)->\(toTier.rawValue)"
    }
}

struct PersonalBest: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var exerciseName: String
    var family: ProofFamily
    var value: Double
    var unit: SkillProofUnit

    init(
        id: String = UUID().uuidString,
        exerciseName: String,
        family: ProofFamily,
        value: Double,
        unit: SkillProofUnit
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.family = family
        self.value = value
        self.unit = unit
    }
}

struct ProofEngineResult: Codable, Hashable, Sendable {
    var logId: String
    var source: WorkoutProofSource
    var achievedProofs: [AchievedSkillProof]
    var standardsCleared: [SkillStandard]
    var prereqsCleared: [ClearedSkillPrereq]
    var unlocks: [SkillUnlock]
    var multiRankEvent: RankAdvancement?
    var newBests: [PersonalBest]

    static func empty(logId: String, source: WorkoutProofSource) -> ProofEngineResult {
        ProofEngineResult(
            logId: logId,
            source: source,
            achievedProofs: [],
            standardsCleared: [],
            prereqsCleared: [],
            unlocks: [],
            multiRankEvent: nil,
            newBests: []
        )
    }

    var hasRewards: Bool {
        !standardsCleared.isEmpty
            || !prereqsCleared.isEmpty
            || !unlocks.isEmpty
            || multiRankEvent != nil
            || !newBests.isEmpty
    }
}

enum ProofEngine {
    static func evaluate(
        log: WorkoutLog,
        source: WorkoutProofSource,
        currentTierState: UserSkillTierState = .empty,
        processedLogIds: Set<String> = [],
        bodyweightKg: Double = 70,
        graph: SkillGraph = .shared
    ) -> ProofEngineResult {
        guard !processedLogIds.contains(log.id) else {
            return .empty(logId: log.id, source: source)
        }

        let entries = log.exerciseEntries.filter { !$0.skipped && $0.sets.contains(where: setHasWork) }
        guard !entries.isEmpty else {
            return .empty(logId: log.id, source: source)
        }

        let achievedProofs = proofs(from: entries)
        let standards = standardsCleared(
            by: entries,
            currentTierState: currentTierState,
            bodyweightKg: bodyweightKg,
            graph: graph
        )
        let prereqs = PrereqClearer.autoClearedPrereqs(from: achievedProofs, graph: graph)
        let unlocks = unlocks(from: standards)
        let rankEvent = multiRankEvent(from: standards, currentTierState: currentTierState, graph: graph)
        let personalBests = newBests(from: achievedProofs)

        return ProofEngineResult(
            logId: log.id,
            source: source,
            achievedProofs: achievedProofs,
            standardsCleared: standards,
            prereqsCleared: prereqs,
            unlocks: unlocks,
            multiRankEvent: rankEvent,
            newBests: personalBests
        )
    }
}

private extension ProofEngine {
    static func standardsCleared(
        by entries: [ExerciseLogEntry],
        currentTierState: UserSkillTierState,
        bodyweightKg: Double,
        graph: SkillGraph
    ) -> [SkillStandard] {
        candidateNodes(for: entries, in: graph)
            .flatMap { node -> [SkillStandard] in
                guard !node.tierCriteria.isEmpty else { return [] }
                let priorTier = currentTierState.tier(for: node.id)
                let wasUntracked = currentTierState.perSkill[node.id] == nil

                return SkillTier.allCases.compactMap { tier -> SkillStandard? in
                    guard let criterion = node.tierCriteria[tier] else { return nil }
                    let isNew = wasUntracked
                        ? tier.rawValue >= priorTier.rawValue
                        : tier.rawValue > priorTier.rawValue
                    guard isNew else { return nil }
                    guard TierCriterionEvaluator.satisfied(
                        criterion: criterion,
                        history: entries,
                        bodyweightKg: bodyweightKg
                    ) else { return nil }

                    return SkillStandard(
                        skillId: node.id,
                        skillTitle: node.title,
                        tier: tier,
                        criterion: criterion,
                        proofFamily: ProofFamily.inferred(from: criterion)
                    )
                }
            }
            .sorted {
                if $0.skillId == $1.skillId {
                    return $0.tier < $1.tier
                }
                return $0.skillTitle < $1.skillTitle
            }
    }

    static func unlocks(from standards: [SkillStandard]) -> [SkillUnlock] {
        let highestBySkill = Dictionary(grouping: standards, by: \.skillId)
            .compactMap { _, standards -> SkillUnlock? in
                guard let top = standards.max(by: { $0.tier < $1.tier }) else { return nil }
                return SkillUnlock(skillId: top.skillId, skillTitle: top.skillTitle, tier: top.tier)
            }

        return highestBySkill.sorted {
            if $0.skillId == $1.skillId { return $0.tier < $1.tier }
            return $0.skillTitle < $1.skillTitle
        }
    }

    static func multiRankEvent(
        from standards: [SkillStandard],
        currentTierState: UserSkillTierState,
        graph: SkillGraph
    ) -> RankAdvancement? {
        let grouped = Dictionary(grouping: standards, by: \.skillId)
        guard let largest = grouped.max(by: { $0.value.count < $1.value.count }),
              largest.value.count > 1,
              let top = largest.value.max(by: { $0.tier < $1.tier }),
              let node = graph.node(id: top.skillId) else {
            return nil
        }

        let fromTier = currentTierState.perSkill[top.skillId]
        return RankAdvancement(
            skillId: top.skillId,
            skillTitle: node.title,
            fromTier: fromTier,
            toTier: top.tier,
            ranksAdvanced: largest.value.count
        )
    }

    static func proofs(from entries: [ExerciseLogEntry]) -> [AchievedSkillProof] {
        entries.flatMap { entry -> [AchievedSkillProof] in
            let workingSets = entry.sets.filter { !$0.isWarmup && setHasWork($0) }
            guard !workingSets.isEmpty else { return [] }

            var proofs: [AchievedSkillProof] = []
            if let bestReps = workingSets.map(\.reps).max(), bestReps > 0 {
                let family = ProofFamily.inferred(fromExerciseName: entry.exerciseName, defaultFamily: .reps)
                proofs.append(
                    AchievedSkillProof(
                        id: "\(entry.id):reps",
                        skillId: entry.rankStandardMovementId,
                        exerciseName: entry.exerciseName,
                        family: family,
                        magnitude: Double(bestReps),
                        unit: .reps,
                        sourceEntryId: entry.id
                    )
                )
            }

            if let bestWeight = workingSets.compactMap(\.weightKg).max(), bestWeight > 0 {
                proofs.append(
                    AchievedSkillProof(
                        id: "\(entry.id):loaded",
                        skillId: entry.rankStandardMovementId,
                        exerciseName: entry.exerciseName,
                        family: .loaded,
                        magnitude: bestWeight,
                        unit: .kilograms,
                        sourceEntryId: entry.id
                    )
                )
            }

            return proofs
        }
    }

    static func candidateNodes(for entries: [ExerciseLogEntry], in graph: SkillGraph) -> [SkillNode] {
        let directIDs = Set(entries.compactMap(\.rankStandardMovementId))
        if !directIDs.isEmpty {
            return graph.nodes.filter { directIDs.contains($0.id) }
        }

        let exerciseNames = entries.map(\.exerciseName)
        return graph.nodes.filter { node in
            node.tierCriteria.values.contains { criterion in
                criterionReferencesAnyLoggedExercise(criterion, exerciseNames: exerciseNames)
            }
        }
    }

    static func criterionReferencesAnyLoggedExercise(
        _ criterion: TierCriterion,
        exerciseNames: [String]
    ) -> Bool {
        switch criterion {
        case .reps(_, let exerciseName),
             .exerciseSeconds(_, let exerciseName),
             .exerciseWeightKg(_, let exerciseName),
             .exerciseBodyweightRatio(_, let exerciseName),
             .variant(let exerciseName):
            return exerciseNames.contains {
                MovementProofMatcher.namesMatch(logged: $0, required: exerciseName)
            }
        case .compound(let criteria):
            return criteria.contains {
                criterionReferencesAnyLoggedExercise($0, exerciseNames: exerciseNames)
            }
        case .seconds, .weightKg, .bodyweightRatio:
            return false
        }
    }

    static func newBests(from proofs: [AchievedSkillProof]) -> [PersonalBest] {
        var bestByKey: [String: AchievedSkillProof] = [:]
        for proof in proofs {
            let key = "\(MovementCatalog.normalized(proof.exerciseName)):\(proof.family.rawValue):\(proof.unit.rawValue)"
            if let existing = bestByKey[key], existing.magnitude >= proof.magnitude {
                continue
            }
            bestByKey[key] = proof
        }

        return bestByKey.values
            .sorted { $0.exerciseName < $1.exerciseName }
            .map {
                PersonalBest(
                    id: $0.id,
                    exerciseName: $0.exerciseName,
                    family: $0.family,
                    value: $0.magnitude,
                    unit: $0.unit
                )
            }
    }

    static func setHasWork(_ set: SetLog) -> Bool {
        !set.isWarmup && (set.reps > 0 || (set.weightKg ?? 0) > 0)
    }
}
