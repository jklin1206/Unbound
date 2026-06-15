import Foundation

@MainActor
final class TrialReadinessService {
    static let shared = TrialReadinessService()

    private init() {}

    func evaluate(_ input: OverallRankTrialReadinessInput) -> OverallRankTrialReadiness {
        guard let definition = OverallRankTrialDefinitions.nextTrial(after: input.currentRank) else {
            return OverallRankTrialReadiness(
                status: .passed,
                currentRank: input.currentRank,
                targetRank: nil,
                definition: nil,
                resolvedTrial: nil,
                blockerSummary: nil,
                requirements: [],
                latestAttempt: input.attempts.sorted { $0.completedAt > $1.completedAt }.first
            )
        }

        let resolution = RankTrialLoadoutResolver.shared.resolve(
            definition: definition,
            userId: input.userId,
            equipment: input.equipment,
            attributeScores: AttributeProfileStore.shared.load(userId: input.userId)
                ?? AttributeProfile.empty(userId: input.userId, at: Date())
        )
        let requirements = requirementLines(for: definition, resolution: resolution, input: input)
        let latestAttempt = input.attempts
            .filter { definition.matchesAttemptDefinitionId($0.definitionId) }
            .sorted { $0.completedAt > $1.completedAt }
            .first
        let allMet = requirements.allSatisfy(\.isMet)

        let status: OverallRankTrialStatus
        if latestAttempt?.passed == true {
            status = .passed
        } else if latestAttempt != nil, allMet {
            status = .failed
        } else if latestAttempt != nil {
            status = .attempted
        } else if allMet {
            status = .ready
        } else {
            status = .locked
        }

        return OverallRankTrialReadiness(
            status: status,
            currentRank: input.currentRank,
            targetRank: definition.targetRank,
            definition: definition,
            resolvedTrial: resolution.resolvedTrial,
            blockerSummary: resolution.blockerSummary,
            requirements: requirements,
            latestAttempt: latestAttempt
        )
    }

    func readiness(
        userId: String,
        services: ServiceContainer,
        store: OverallRankTrialStore = .shared
    ) async -> OverallRankTrialReadiness {
        let progress = store.load(userId: userId)
        let overallProgress: OverallLevelProgress? = try? await services.database.read(
            collection: "overall_level_progress",
            documentId: userId
        )

        let aggregateRank = await services.rank.aggregateRank(userId: userId)
        let userProfile = try? await services.user.fetchProfile(userId: userId)
        let equipment = Self.movementEquipment(from: userProfile?.equipment ?? [.bodyweight])
        let workoutLogs = (try? await services.workoutLog.fetchLogs(userId: userId, programId: nil)) ?? []
        let attributeProfile = AttributeProfileStore.shared.load(userId: userId)
        let bodyweightKg = userProfile?.weightKg ?? 0
        let nextFormat = OverallRankTrialDefinitions.nextTrial(after: progress.currentRank)?.format
        let history = WorkoutLogGateKeyHistory(
            workoutLogs: workoutLogs,
            attributeProfile: attributeProfile,
            trialProgress: progress
        )
        let clearedGateKeys = nextFormat.map {
            GateKeys.clearedKeys(for: $0, history: history, bodyweightKg: bodyweightKg)
        } ?? []

        return evaluate(
            OverallRankTrialReadinessInput(
                userId: userId,
                currentRank: progress.currentRank,
                overallLevel: overallProgress?.level ?? 0,
                aggregateRank: aggregateRank,
                equipment: equipment,
                clearedGateKeys: clearedGateKeys,
                attempts: progress.attempts
            )
        )
    }

    static func movementEquipment(from equipment: [Equipment]) -> Set<MovementEquipment> {
        var result: Set<MovementEquipment> = [.bodyweight, .openSpace]
        for item in equipment {
            switch item {
            case .fullGym:
                result.formUnion([
                    .barbell,
                    .dumbbell,
                    .kettlebell,
                    .cable,
                    .machine,
                    .bench,
                    .box,
                    .sled,
                    .cardioMachine,
                    .pullupBar,
                    .bodyweight,
                    .openSpace
                ])
            case .machines:
                result.formUnion([.cable, .machine, .cardioMachine, .bodyweight, .openSpace])
            case .barbell:
                result.formUnion([.barbell, .bodyweight, .openSpace])
            case .dumbbells, .homeWeights:
                result.formUnion([.dumbbell, .kettlebell, .bodyweight, .openSpace])
            case .bench:
                result.formUnion([.bench, .bodyweight])
            case .pullupBar:
                result.formUnion([.pullupBar, .bodyweight])
            case .dipStation:
                result.formUnion([.dipStation, .bodyweight])
            case .rings:
                result.formUnion([.rings, .bodyweight])
            case .bodyweight:
                result.insert(.bodyweight)
            case .bands:
                result.formUnion([.band, .bodyweight])
            }
        }
        return result
    }

    private func requirementLines(
        for definition: OverallRankTrialDefinition,
        resolution: RankTrialResolution,
        input: OverallRankTrialReadinessInput
    ) -> [OverallRankTrialRequirementLine] {
        var lines: [OverallRankTrialRequirementLine] = []

        lines.append(
            OverallRankTrialRequirementLine(
                id: "overall-level",
                kind: .overallLevel,
                label: "Overall LVL",
                current: "LVL \(input.overallLevel)",
                required: "LVL \(definition.minOverallLevel)",
                isMet: input.overallLevel >= definition.minOverallLevel
            )
        )

        // Accumulation gate (Phase 7): the build-weighted aggregate rank must
        // reach the target tier. This is "elite in your build" — fairness lives
        // in the build-weighting, not in a fixed skill/attribute conformity set.
        lines.append(
            OverallRankTrialRequirementLine(
                id: "accumulated-rank",
                kind: .rank,
                label: "Accumulated rank",
                current: input.aggregateRank.displayName,
                required: definition.targetRank.displayName,
                isMet: input.aggregateRank >= definition.targetRank
            )
        )

        let requiredEquipment = resolution.resolvedTrial?.requiredEquipment ?? definition.requiredEquipment
        let missingEquipment = resolution.blockers.reduce(into: Set<MovementEquipment>()) { result, blocker in
            result.formUnion(blocker.missingEquipment)
        }
        lines.append(
            OverallRankTrialRequirementLine(
                id: "equipment",
                kind: .equipment,
                label: "Equipment",
                current: input.equipment.map(\.displayName).sorted().joined(separator: ", "),
                required: missingEquipment.isEmpty
                    ? requiredEquipment.map(\.displayName).sorted().joined(separator: ", ")
                    : missingEquipment.map(\.displayName).sorted().joined(separator: ", "),
                isMet: resolution.isReady
            )
        )

        for key in GateKeys.keys(for: definition.format) {
            let isMet = input.clearedGateKeys.contains(key.id)
            lines.append(
                OverallRankTrialRequirementLine(
                    id: key.id,
                    kind: .gateKey,
                    label: key.label,
                    current: isMet ? "Proven" : "Unproven",
                    required: key.label,
                    isMet: isMet
                )
            )
        }

        return lines
    }
}
