// UNBOUND/Views/Profile/ProfileView+Showcase.swift
//
// Trophy showcase resolution: builds the skill/lift showcase option lists
// from proven skills + logged lifts and applies the persisted selection.
import SwiftUI

extension ProfileView {

    func resolveProfileShowcase(
        userId: String,
        workoutLogs: [WorkoutLog],
        bodyweightKg: Double?,
        sex: BiologicalSex?
    ) {
        let selection = ProfileShowcaseStore.load(userId: userId)
        let skillOptions = Self.skillShowcaseOptions(userId: userId)
        let liftOptions = Self.loggedLiftCandidates(
            logs: workoutLogs,
            bodyweightKg: bodyweightKg,
            sex: sex
        )

        showcaseSkillOptions = skillOptions
        showcaseLiftOptions = liftOptions
        applyProfileShowcase(selection: selection, skillOptions: skillOptions, liftOptions: liftOptions)
    }

    func applyProfileShowcase(
        selection: ProfileShowcaseSelection,
        skillOptions: [ProfileShowcaseOption],
        liftOptions: [ProfileShowcaseOption]
    ) {
        let skill = Self.selectedShowcaseOption(selection.skillId, options: skillOptions) ?? skillOptions.first
        showcaseSkillId = skill?.id
        showcaseSkillName = skill?.name ?? "None yet"
        showcaseSkillTier = skill?.tier ?? .initiate

        let lift = Self.selectedShowcaseOption(selection.liftId, options: liftOptions) ?? liftOptions.first
        showcaseLiftId = lift?.id
        showcaseLiftName = lift?.name ?? "None yet"
        showcaseLiftTier = lift?.tier ?? .initiate
    }

    private static func selectedShowcaseOption(
        _ id: String?,
        options: [ProfileShowcaseOption]
    ) -> ProfileShowcaseOption? {
        guard let id else { return nil }
        return options.first { $0.id == id }
    }

    private static func skillShowcaseOptions(userId: String) -> [ProfileShowcaseOption] {
        let skillTiers = UserSkillTierStore.shared.load(userId: userId).perSkill
        let nodeStates = SkillProgressService.shared.nodeStates
        let options = SkillGraph.shared.nodes.compactMap { node -> ProfileShowcaseOption? in
            guard nodeStates[node.id] == .proven else { return nil }
            return ProfileShowcaseOption(
                id: node.id,
                name: node.title,
                tier: skillTiers[node.id] ?? .initiate,
                metricSort: Double(node.placementRank.rawValue),
                repsSort: node.tier
            )
        }
        return sortedShowcaseOptions(options)
    }

    private static func displayLiftName(_ lift: String) -> String {
        lift.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func loggedLiftCandidates(
        logs: [WorkoutLog],
        bodyweightKg: Double?,
        sex: BiologicalSex?
    ) -> [ProfileShowcaseOption] {
        var bestById: [String: ProfileShowcaseOption] = [:]
        for entry in logs.flatMap(\.exerciseEntries) {
            let rankKey = rankExerciseKey(for: entry)
            let liftId = MovementCatalog.normalized(entry.exerciseName)
            let liftName = displayLiftName(entry.exerciseName)

            for set in entry.sets {
                guard !set.isWarmup, let weightKg = set.weightKg, weightKg > 0 else { continue }
                guard let tier = Self.liftTier(
                    for: rankKey,
                    weightKg: weightKg,
                    bodyweightKg: bodyweightKg,
                    sex: sex
                ) else { continue }
                let option = ProfileShowcaseOption(
                    id: liftId,
                    name: liftName,
                    tier: tier,
                    metricSort: weightKg,
                    repsSort: set.reps
                )
                if let existing = bestById[liftId] {
                    if isShowcaseOption(option, betterThan: existing) {
                        bestById[liftId] = option
                    }
                } else {
                    bestById[liftId] = option
                }
            }
        }
        return sortedShowcaseOptions(Array(bestById.values))
    }

    private static func liftTier(
        for lift: String,
        weightKg: Double,
        bodyweightKg: Double?,
        sex: BiologicalSex?
    ) -> SkillTier? {
        guard weightKg > 0 else { return nil }
        if let bodyweightKg, bodyweightKg > 0 {
            return StrengthStandards.progressToNextRank(
                metricValue: weightKg,
                bodyweightKg: bodyweightKg,
                exerciseKey: lift,
                sex: sex
            )?.current
        }

        if StrengthStandards.canonicalKey(for: lift) != nil ||
            StrengthStandards.accessoryFamily(for: lift) != nil {
            return .initiate
        }

        return nil
    }

    private static func rankExerciseKey(for entry: ExerciseLogEntry) -> String {
        if let key = canonicalMovementExerciseKey(for: entry.rankStandardMovementId) {
            return key
        }
        if let key = canonicalMovementExerciseKey(for: entry.movementId) {
            return key
        }

        let resolved = MovementResolver.resolve(entry.exerciseName)
        if let key = canonicalMovementExerciseKey(for: resolved.rankStandardMovementId) {
            return key
        }
        return MovementResolution.normalizedKey(entry.exerciseName)
    }

    private static func canonicalMovementExerciseKey(for movementId: String?) -> String? {
        guard let movementId, let definition = MovementCatalog.definition(for: movementId) else {
            return nil
        }
        if let canonical = definition.canonicalExerciseName {
            return MovementResolution.normalizedKey(canonical)
        }
        return MovementResolution.normalizedKey(definition.displayName)
    }

    private static func sortedShowcaseOptions(_ options: [ProfileShowcaseOption]) -> [ProfileShowcaseOption] {
        options.sorted { lhs, rhs in
            isShowcaseOption(lhs, betterThan: rhs)
        }
    }

    private static func isShowcaseOption(
        _ lhs: ProfileShowcaseOption,
        betterThan rhs: ProfileShowcaseOption
    ) -> Bool {
        if lhs.tier != rhs.tier { return lhs.tier > rhs.tier }
        if lhs.metricSort != rhs.metricSort { return lhs.metricSort > rhs.metricSort }
        if lhs.repsSort != rhs.repsSort { return lhs.repsSort > rhs.repsSort }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func rankTitle(for tier: SkillTier) -> RankTitle {
        tier.rankTitle
    }
}
