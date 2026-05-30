import Foundation

enum SkillProofUnit: String, Codable, Hashable, Sendable {
    case reps
    case seconds
    case kilograms
    case bodyweightRatio
    case occurrence
}

struct AchievedSkillProof: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var skillId: String?
    var exerciseName: String
    var family: ProofFamily
    var magnitude: Double
    var unit: SkillProofUnit
    var sourceEntryId: String?

    init(
        id: String = UUID().uuidString,
        skillId: String? = nil,
        exerciseName: String,
        family: ProofFamily,
        magnitude: Double,
        unit: SkillProofUnit,
        sourceEntryId: String? = nil
    ) {
        self.id = id
        self.skillId = skillId
        self.exerciseName = exerciseName
        self.family = family
        self.magnitude = magnitude
        self.unit = unit
        self.sourceEntryId = sourceEntryId
    }
}

struct ClearedSkillPrereq: Codable, Hashable, Sendable, Identifiable {
    var childSkillId: String?
    var requirement: SkillUnlockRequirement
    var proof: AchievedSkillProof

    var id: String {
        [childSkillId ?? "direct", requirement.id, proof.id].joined(separator: ":")
    }
}

enum PrereqClearer {
    static func autoClearedPrereqs(
        from proofs: [AchievedSkillProof],
        requirements: [SkillUnlockRequirement],
        graph: SkillGraph = .shared
    ) -> [ClearedSkillPrereq] {
        var seen = Set<String>()
        var cleared: [ClearedSkillPrereq] = []

        for proof in proofs {
            for requirement in requirements {
                guard canAutoClear(proof: proof, requirement: requirement, graph: graph) else { continue }
                let id = "\(requirement.id):\(proof.id)"
                guard seen.insert(id).inserted else { continue }
                cleared.append(ClearedSkillPrereq(childSkillId: nil, requirement: requirement, proof: proof))
            }
        }

        return cleared
    }

    static func autoClearedPrereqs(
        from proofs: [AchievedSkillProof],
        graph: SkillGraph = .shared
    ) -> [ClearedSkillPrereq] {
        var seen = Set<String>()
        var cleared: [ClearedSkillPrereq] = []

        for child in graph.nodes {
            let requirements = SkillUnlockStandards.groups(for: child, in: graph).flatMap(\.requirements)
            for proof in proofs {
                for requirement in requirements {
                    guard canAutoClear(proof: proof, requirement: requirement, graph: graph) else { continue }
                    let id = "\(child.id):\(requirement.id):\(proof.id)"
                    guard seen.insert(id).inserted else { continue }
                    cleared.append(ClearedSkillPrereq(childSkillId: child.id, requirement: requirement, proof: proof))
                }
            }
        }

        return cleared
    }

    static func canAutoClear(
        proof: AchievedSkillProof,
        requirement: SkillUnlockRequirement,
        graph: SkillGraph = .shared
    ) -> Bool {
        guard requirement.autoClearFromHigherProof else { return false }
        guard !requirement.safetyRequired else { return false }
        guard requirement.proofFamilyCovered.contains(proof.family) else { return false }
        guard let threshold = threshold(for: requirement, graph: graph) else { return false }
        guard threshold.family == proof.family else { return false }
        guard threshold.matchesExerciseLine(proof.exerciseName) else { return false }
        guard proof.unit == threshold.unit || threshold.unit == .occurrence else { return false }
        return proof.magnitude >= threshold.magnitude
    }
}

private struct ProofThreshold {
    var family: ProofFamily
    var exerciseName: String?
    var magnitude: Double
    var unit: SkillProofUnit

    func matchesExerciseLine(_ exerciseName: String) -> Bool {
        guard let required = self.exerciseName, !required.isEmpty else { return true }
        return MovementProofMatcher.namesMatch(logged: exerciseName, required: required)
    }
}

private extension PrereqClearer {
    static func threshold(for requirement: SkillUnlockRequirement, graph: SkillGraph) -> ProofThreshold? {
        guard let source = graph.node(id: requirement.sourceSkillId) else { return nil }
        if let criterion = source.tierCriteria[requirement.requiredTier] {
            return threshold(
                for: criterion,
                preferredFamily: requirement.directProofFamily
            )
        }
        return threshold(
            for: source.target,
            preferredFamily: requirement.directProofFamily
        )
    }

    static func threshold(for criterion: TierCriterion, preferredFamily: ProofFamily) -> ProofThreshold? {
        switch criterion {
        case .reps(let count, let exerciseName):
            return ProofThreshold(
                family: ProofFamily.inferred(from: criterion),
                exerciseName: exerciseName,
                magnitude: Double(count),
                unit: .reps
            )
        case .seconds(let seconds):
            return ProofThreshold(
                family: .hold,
                exerciseName: nil,
                magnitude: Double(seconds),
                unit: .seconds
            )
        case .exerciseSeconds(let seconds, let exerciseName):
            return ProofThreshold(
                family: .hold,
                exerciseName: exerciseName,
                magnitude: Double(seconds),
                unit: .seconds
            )
        case .weightKg(let weight):
            return ProofThreshold(family: .loaded, exerciseName: nil, magnitude: weight, unit: .kilograms)
        case .exerciseWeightKg(let weight, let exerciseName):
            return ProofThreshold(family: .loaded, exerciseName: exerciseName, magnitude: weight, unit: .kilograms)
        case .bodyweightRatio(let ratio):
            return ProofThreshold(family: .loaded, exerciseName: nil, magnitude: ratio, unit: .bodyweightRatio)
        case .exerciseBodyweightRatio(let ratio, let exerciseName):
            return ProofThreshold(family: .loaded, exerciseName: exerciseName, magnitude: ratio, unit: .bodyweightRatio)
        case .variant(let name):
            return ProofThreshold(
                family: ProofFamily.inferred(from: criterion),
                exerciseName: name,
                magnitude: 1,
                unit: .occurrence
            )
        case .compound(let criteria):
            let preferred = criteria.first { ProofFamily.inferred(from: $0) == preferredFamily }
            return (preferred ?? criteria.first).flatMap {
                threshold(for: $0, preferredFamily: preferredFamily)
            }
        }
    }

    static func threshold(for requirement: NodeRequirement, preferredFamily: ProofFamily) -> ProofThreshold? {
        switch requirement {
        case .weightMultiplier(let exercise, let multiplier):
            return ProofThreshold(family: .loaded, exerciseName: exercise, magnitude: multiplier, unit: .bodyweightRatio)
        case .reps(let exercise, let count, _):
            return ProofThreshold(
                family: ProofFamily.inferred(from: requirement),
                exerciseName: exercise,
                magnitude: Double(count),
                unit: .reps
            )
        case .hold(let exercise, let seconds):
            return ProofThreshold(family: .hold, exerciseName: exercise, magnitude: Double(seconds), unit: .seconds)
        case .steps(let exercise, let count):
            return ProofThreshold(family: .unilateral, exerciseName: exercise, magnitude: Double(count), unit: .reps)
        case .carry(let exercise, let seconds, _):
            return ProofThreshold(family: .loaded, exerciseName: exercise, magnitude: Double(seconds), unit: .seconds)
        case .composite(let requirements):
            let preferred = requirements.first { ProofFamily.inferred(from: $0) == preferredFamily }
            return (preferred ?? requirements.first).flatMap {
                threshold(for: $0, preferredFamily: preferredFamily)
            }
        }
    }
}
