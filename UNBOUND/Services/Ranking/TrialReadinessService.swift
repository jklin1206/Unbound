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

        let userProfile = try? await services.user.fetchProfile(userId: userId)
        let equipment = Self.movementEquipment(from: userProfile?.equipment ?? [.bodyweight])
        let workoutLogs = (try? await services.workoutLog.fetchLogs(userId: userId, programId: nil)) ?? []
        let attributeProfile = AttributeProfileStore.shared.load(userId: userId)
        let bodyweightKg = userProfile?.weightKg ?? 0
        let nextFormat = OverallRankTrialDefinitions.nextTrial(after: progress.currentRank)?.format
        // Pool for the `movementsAtRank` gate key: proven skill tiers + every
        // loaded movement StrengthStandards ranks, deduped by canonical
        // identity (see gateKeyMovementTierPool). One indexed query over the
        // per-standard movement_progress rows - the same store the rank
        // library reads for its earned tiers.
        let progressStates: [MovementProgressState] = (try? await services.database.query(
            collection: "movement_progress",
            field: "userId",
            isEqualTo: userId,
            orderBy: nil,
            descending: true,
            limit: nil
        )) ?? []
        let movementTiers = Self.gateKeyMovementTierPool(
            skillTiers: UserSkillTierStore.shared.load(userId: userId),
            progressStates: progressStates,
            bodyweightKg: userProfile?.weightKg,
            sex: userProfile?.biologicalSex
        )
        let history = WorkoutLogGateKeyHistory(
            workoutLogs: workoutLogs,
            attributeProfile: attributeProfile,
            trialProgress: progress,
            movementTiers: movementTiers
        )
        let clearedGateKeys = nextFormat.map {
            GateKeys.clearedKeys(for: $0, history: history, bodyweightKg: bodyweightKg)
        } ?? []

        return evaluate(
            OverallRankTrialReadinessInput(
                userId: userId,
                currentRank: progress.currentRank,
                overallLevel: overallProgress?.level ?? 0,
                equipment: equipment,
                clearedGateKeys: clearedGateKeys,
                gateKeyMovementTiers: movementTiers,
                attempts: progress.attempts
            )
        )
    }

    // MARK: - movementsAtRank pool

    /// The movement pool the `movementsAtRank` gate key counts: one tier per
    /// proven movement, deduped by canonical identity.
    ///
    ///   - Skills: per-skill tiers from `UserSkillTierStore` (identity = skill
    ///     node id) - SkillStandards stays their single rank source.
    ///   - Loaded movements: every `movement_progress` standard
    ///     StrengthStandards ranks (the 6 compounds incl. barbell row,
    ///     weighted pull-up, the accessory families), tiered by
    ///     `MovementProgressTierResolver` - the SAME computation the rank
    ///     library displays, never a parallel ladder. Compound variants
    ///     collapse to their canonical compound (mirroring
    ///     `RankService.bestBarbellLiftTiers`); accessories count per FAMILY -
    ///     one family = one movement - so five curl variants can never be
    ///     five movements.
    ///   - A loaded standard owned by a skill node (weighted pull-up, goblet
    ///     squat) is excluded here: the rank library's owning-skill join makes
    ///     the skill the single rank source for it, so the skill-store tier
    ///     already represents that movement and it never counts twice.
    ///
    /// Display-only surfaces (`LiftTierService`, `RankService.aggregateTier`)
    /// are deliberately untouched - this pool gates trials, not cosmetics.
    static func gateKeyMovementTierPool(
        skillTiers: UserSkillTierState,
        progressStates: [MovementProgressState],
        bodyweightKg: Double?,
        sex: BiologicalSex?
    ) -> [RankTier] {
        var loadedBest: [String: RankTier] = [:]
        for state in progressStates {
            guard MovementCatalog.owningSkillId(forMovementId: state.rankStandardMovementId) == nil,
                  let identity = loadedMovementIdentity(for: state.displayName)
            else { continue }
            let tier = MovementProgressTierResolver.provenTier(
                for: state,
                bodyweightKg: bodyweightKg,
                sex: sex
            )
            loadedBest[identity] = max(loadedBest[identity] ?? .initiate, tier)
        }
        return Array(skillTiers.perSkill.values) + Array(loadedBest.values)
    }

    /// Canonical counting identity for a loaded exercise, or nil when
    /// StrengthStandards doesn't rank it: compounds (and their variants) and
    /// weighted pull-up collapse via `StrengthStandards.canonicalKey`;
    /// accessories collapse to their family.
    static func loadedMovementIdentity(for exerciseKey: String) -> String? {
        guard !StrengthStandards.isUnranked(exerciseKey: exerciseKey) else { return nil }
        if let compound = StrengthStandards.canonicalKey(for: exerciseKey) {
            return "lift:\(compound)"
        }
        if let family = StrengthStandards.accessoryFamily(for: exerciseKey) {
            return "family:\(family)"
        }
        return nil
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
                    .parallettes,
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

        // Strength is gated by the attribute keys ("any K attributes at rank R",
        // appended below) — a legible, build-expressive check — so the opaque
        // accumulated-rank line was folded out (see AP-GATE-REDESIGN-PROPOSAL §5).

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
                    current: gateKeyCurrent(for: key, input: input, isMet: isMet),
                    required: key.label,
                    isMet: isMet
                )
            )
        }

        return lines
    }

    /// `current` string for a gate-key line, in the existing line style.
    /// Movement keys show a live count ("3 of 5") when the caller computed the
    /// tier pool; every other key keeps the Proven/Unproven pattern.
    private func gateKeyCurrent(
        for key: GateKeyDefinition,
        input: OverallRankTrialReadinessInput,
        isMet: Bool
    ) -> String {
        if case .movementsAtRank(let count, let rank) = key.metric,
           !input.gateKeyMovementTiers.isEmpty {
            let met = input.gateKeyMovementTiers.filter { $0 >= rank }.count
            return "\(min(met, count)) of \(count)"
        }
        return isMet ? "Proven" : "Unproven"
    }
}
