import Foundation

struct OverallRankTrialRunResult: Sendable {
    let definition: OverallRankTrialDefinition
    let attempt: OverallRankTrialAttempt
    let evaluation: OverallRankTrialEvaluation
    let progress: OverallRankTrialProgress
    let completionResult: TrainingCompletionResult?
    let didAdvanceRank: Bool
    let wasDuplicate: Bool
    let callouts: [OverallRankTrialRunCallout]

    init(
        definition: OverallRankTrialDefinition,
        attempt: OverallRankTrialAttempt,
        evaluation: OverallRankTrialEvaluation,
        progress: OverallRankTrialProgress,
        completionResult: TrainingCompletionResult?,
        didAdvanceRank: Bool,
        wasDuplicate: Bool,
        callouts: [OverallRankTrialRunCallout]
    ) {
        self.definition = definition
        self.attempt = attempt
        self.evaluation = evaluation
        self.progress = progress
        self.completionResult = completionResult
        self.didAdvanceRank = didAdvanceRank
        self.wasDuplicate = wasDuplicate
        self.callouts = callouts
    }

    var rankUp: RankUp? {
        guard didAdvanceRank else { return nil }
        return RankUp(
            skillId: "overall-rank",
            skillTitle: "Overall Rank",
            fromTier: nil,
            toTier: attempt.targetRank
        )
    }
}

@MainActor
final class OverallRankTrialRunner {
    static let shared = OverallRankTrialRunner()

    private init() {}

    func draft(
        for definition: OverallRankTrialDefinition,
        userId: String,
        date: Date = Date(),
        resolvedTrial: ResolvedRankTrial? = nil,
        bodyweightKg: Double? = nil
    ) -> TrainingSessionDraft {
        let resolved = resolvedTrial ?? RankTrialLoadoutResolver.shared.resolve(
            definition: definition,
            userId: userId,
            equipment: definition.requiredEquipment,
            generatedAt: date
        ).resolvedTrial
        return definition.makeDraft(userId: userId, date: date, resolvedTrial: resolved, bodyweightKg: bodyweightKg)
    }

    @discardableResult
    func complete(
        performanceLog: PerformanceLog,
        services: ServiceContainer,
        store: OverallRankTrialStore = .shared
    ) async throws -> OverallRankTrialRunResult? {
        guard let definition = definition(for: performanceLog) else { return nil }
        let existing = store.load(userId: performanceLog.userId)
        if let duplicate = existing.attempts.first(where: { $0.id == performanceLog.id }) {
            let evaluation = duplicate.evaluation ?? evaluateDetailed(performanceLog, against: definition)
            return OverallRankTrialRunResult(
                definition: definition,
                attempt: duplicate,
                evaluation: evaluation,
                progress: existing,
                completionResult: nil,
                didAdvanceRank: false,
                wasDuplicate: true,
                callouts: callouts(
                    for: duplicate,
                    definition: definition,
                    previousProgress: existing,
                    didAdvanceRank: false,
                    wasDuplicate: true
                )
            )
        }

        let completionResult = try await TrainingCompletionService.shared.complete(performanceLog, services: services)
        let profile = try? await services.user.fetchProfile(userId: performanceLog.userId)
        return recordCompletedAttempt(
            performanceLog: performanceLog,
            completionResult: completionResult,
            store: store,
            bodyweightKg: profile?.weightKg
        )
    }

    @discardableResult
    func recordCompletedAttempt(
        performanceLog: PerformanceLog,
        completionResult: TrainingCompletionResult,
        store: OverallRankTrialStore = .shared,
        bodyweightKg: Double? = nil
    ) -> OverallRankTrialRunResult? {
        guard let definition = definition(for: performanceLog) else { return nil }
        let previousProgress = store.load(userId: performanceLog.userId)
        let evaluation = evaluateDetailed(
            performanceLog,
            against: definition,
            bodyweightKg: bodyweightKg,
            enforceLoadPercent: true
        )
        let selectedLoadout = selectedLoadout(in: performanceLog)
        let attempt = OverallRankTrialAttempt(
            id: performanceLog.id,
            userId: performanceLog.userId,
            definitionId: definition.id,
            targetRank: definition.targetRank,
            startedAt: performanceLog.startedAt,
            completedAt: performanceLog.completedAt,
            performanceLogId: performanceLog.id,
            passed: evaluation.passed,
            movementAPGained: completionResult.totalMovementAP,
            overallLevelXPGained: completionResult.overallLevelXPGained,
            resolvedTrialId: selectedLoadout.map { "\(definition.id).\($0.rawValue)" },
            loadout: selectedLoadout,
            evaluation: evaluation
        )
        let record = store.record(attempt, userId: performanceLog.userId)

        if record.didAdvanceRank {
            NotificationCenter.default.post(
                name: .overallRankTrialCompleted,
                object: record.attempt,
                userInfo: [
                    "targetRank": definition.targetRank.token,
                    "definitionId": definition.id
                ]
            )
        }

        return OverallRankTrialRunResult(
            definition: definition,
            attempt: record.attempt,
            evaluation: record.attempt.evaluation ?? evaluation,
            progress: record.progress,
            completionResult: completionResult,
            didAdvanceRank: record.didAdvanceRank,
            wasDuplicate: record.wasDuplicate,
            callouts: callouts(
                for: record.attempt,
                definition: definition,
                previousProgress: previousProgress,
                didAdvanceRank: record.didAdvanceRank,
                wasDuplicate: record.wasDuplicate
            )
        )
    }

    private func callouts(
        for attempt: OverallRankTrialAttempt,
        definition: OverallRankTrialDefinition,
        previousProgress: OverallRankTrialProgress,
        didAdvanceRank: Bool,
        wasDuplicate: Bool
    ) -> [OverallRankTrialRunCallout] {
        if wasDuplicate {
            return [
                OverallRankTrialRunCallout(
                    kind: .duplicateAttempt,
                    title: "Attempt already counted",
                    message: "\(definition.displayName) was already recorded, so rank progress stayed at \(previousProgress.currentRank.displayName)."
                )
            ]
        }

        guard attempt.passed, didAdvanceRank else { return [] }

        let priorAttempts = previousProgress.attempts.filter { $0.definitionId == definition.id }
        let priorFailureCount = priorAttempts.filter { !$0.passed }.count
        let hadPriorPass = priorAttempts.contains { $0.passed }
        guard priorFailureCount > 0, !hadPriorPass else { return [] }

        let attemptNoun = priorFailureCount == 1 ? "attempt" : "attempts"
        return [
            OverallRankTrialRunCallout(
                kind: .comebackPass,
                title: "Comeback clear",
                message: "Cleared \(definition.displayName) after \(priorFailureCount) failed \(attemptNoun)."
            )
        ]
    }

    func evaluatePerformance(
        _ performanceLog: PerformanceLog,
        against definition: OverallRankTrialDefinition
    ) -> Bool {
        evaluateDetailed(performanceLog, against: definition).passed
    }

    func evaluateDetailed(
        _ performanceLog: PerformanceLog,
        against definition: OverallRankTrialDefinition,
        bodyweightKg: Double? = nil,
        enforceLoadPercent: Bool = false
    ) -> OverallRankTrialEvaluation {
        let exerciseMovementIds = movementIds(in: performanceLog)
        let selectedLoadout = selectedLoadout(in: performanceLog)
        let stationGroups = stationCandidates(for: definition, selectedLoadout: selectedLoadout)
        var stationResults = stationGroups.map { candidates -> OverallRankTrialStationResult in
            let station = candidates.first { candidate in
                let titledMovementIds = movementIds(in: performanceLog.blocks.filter { $0.title == candidate.title })
                return !candidate.allowedMovementIds.intersection(titledMovementIds).isEmpty
            } ?? candidates.first { candidate in
                !candidate.allowedMovementIds.intersection(exerciseMovementIds).isEmpty
            } ?? candidates[0]
            let stationBlocks = performanceLog.blocks.filter { $0.title == station.title }
            return evaluateStation(
                station,
                blocks: stationBlocks,
                bodyweightKg: bodyweightKg,
                enforceLoadPercent: enforceLoadPercent
            )
        }
        if let timeCapFailure = totalTimeCapFailure(for: definition, performanceLog: performanceLog) {
            stationResults.insert(timeCapFailure, at: 0)
        }

        return OverallRankTrialEvaluation(
            definitionId: definition.id,
            passed: stationResults.allSatisfy { $0.status == .passed },
            stationResults: stationResults
        )
    }

    private func stationCandidates(
        for definition: OverallRankTrialDefinition,
        selectedLoadout: TrialLoadout? = nil
    ) -> [[TrialStation]] {
        if definition.loadoutVariants.isEmpty {
            return definition.performanceStandards.enumerated().map { index, standard in
                [
                    TrialStation(
                        id: "legacy-\(index + 1)",
                        title: standard.displayName,
                        category: .mobilityControl,
                        standard: standard,
                        capSeconds: nil,
                        loadPercentOfBodyweight: nil,
                        movementOptions: [TrialMovementOption(movementId: standard.movementId, displayName: standard.displayName)],
                        restRule: "Legacy rank gate.",
                        qualityFlags: [.clean]
                    )
                ]
            }
        }

        if let selectedLoadout,
           let variant = definition.loadoutVariants.first(where: { $0.loadout == selectedLoadout }) {
            return variant.stations.map { [$0] }
        }

        var orderedIds: [String] = []
        var grouped: [String: [TrialStation]] = [:]
        for station in definition.loadoutVariants.flatMap(\.stations) {
            if grouped[station.id] == nil {
                orderedIds.append(station.id)
                grouped[station.id] = []
            }
            grouped[station.id]?.append(station)
        }
        return orderedIds.compactMap { grouped[$0] }
    }

    private func selectedLoadout(in performanceLog: PerformanceLog) -> TrialLoadout? {
        let markers = [" rank trial station:", " official station:"]
        let notes = ([performanceLog.notes] + performanceLog.blocks.flatMap { block in
            [block.notes] + block.exercises.map(\.notes)
        }).compactMap { $0 }

        for note in notes {
            for marker in markers where note.contains(marker) {
                let label = note
                    .components(separatedBy: marker)
                    .first?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let loadout = TrialLoadout.allCases.first(where: { $0.displayName == label }) {
                    return loadout
                }
            }
        }
        return nil
    }

    private func totalTimeCapFailure(
        for definition: OverallRankTrialDefinition,
        performanceLog: PerformanceLog
    ) -> OverallRankTrialStationResult? {
        let capSeconds = definition.estimatedMinutes * 60
        let elapsed = max(0, Int(performanceLog.completedAt.timeIntervalSince(performanceLog.startedAt).rounded()))
        guard elapsed > capSeconds else { return nil }
        return OverallRankTrialStationResult(
            id: "trial-time-cap",
            title: "Trial Time Cap",
            category: .engine,
            movementId: "trial.time-cap",
            required: capSeconds,
            qualifyingSetsRequired: 1,
            qualifyingSetsCompleted: 0,
            totalValue: elapsed,
            failedQualityFlags: [],
            status: .failed,
            failureReason: "Trial exceeded the official time cap."
        )
    }

    private func movementIds(in performanceLog: PerformanceLog) -> Set<String> {
        movementIds(in: performanceLog.blocks)
    }

    private func movementIds(in blocks: [PerformanceBlock]) -> Set<String> {
        Set(
            blocks.flatMap(\.exercises)
                .flatMap { exercise in
                    [
                        exercise.movementId,
                        exercise.rankStandardMovementId,
                        MovementResolver.resolve(exercise.name).movementId
                    ].compactMap { $0 }
                }
        )
    }

    private func evaluateStation(
        _ station: TrialStation,
        blocks: [PerformanceBlock],
        bodyweightKg: Double?,
        enforceLoadPercent: Bool
    ) -> OverallRankTrialStationResult {
        let standard = station.standard

        // Collect matching exercises (retaining movementId for per-option floor resolution).
        let matchingExercises = blocks.flatMap(\.exercises)
            .filter { exercise in
                station.allowedMovementIds.contains(exercise.movementId ?? "")
                    || station.allowedMovementIds.contains(exercise.rankStandardMovementId ?? "")
                    || station.allowedMovementIds.contains(MovementResolver.resolve(exercise.name).movementId)
            }

        // Derive the performed movement id from the first matched exercise so we can
        // consult per-option floor overrides (Task 3: floorOverride on TrialMovementOption).
        let performedMovementId: String = matchingExercises.first.map { ex in
            ex.movementId
                ?? ex.rankStandardMovementId
                ?? MovementResolver.resolve(ex.name).movementId
        } ?? standard.movementId
        let effectiveMinimum = station.resolvedMinimum(forMovementId: performedMovementId)

        let matchingSets = matchingExercises
            .flatMap(\.sets)
            .filter { !$0.isWarmup }

        let failedQualityFlags = Set(
            matchingSets
                .flatMap(\.qualityFlags)
                .filter { $0 == .formBreak || $0 == .pain }
        )
        if !failedQualityFlags.isEmpty {
            return stationResult(
                station,
                qualifyingSetsCompleted: 0,
                totalValue: 0,
                failedQualityFlags: failedQualityFlags,
                status: .failed,
                failureReason: "Pain or form-break flag recorded."
            )
        }

        let cleanSets = matchingSets.filter { set in
            !set.qualityFlags.contains(.formBreak) && !set.qualityFlags.contains(.pain)
        }
        let values = cleanSets.map { set in
            value(for: set, metric: standard.metric)
        }

        guard !values.isEmpty else {
            return stationResult(
                station,
                qualifyingSetsCompleted: 0,
                totalValue: 0,
                failedQualityFlags: [],
                status: .missing,
                failureReason: "No logged set for this station."
            )
        }

        if let capSeconds = station.capSeconds {
            let blockSeconds = blocks.compactMap(\.durationSeconds).reduce(0, +)
            if blockSeconds > capSeconds {
                return stationResult(
                    station,
                    qualifyingSetsCompleted: 0,
                    totalValue: values.reduce(0, +),
                    failedQualityFlags: [],
                    status: .failed,
                    failureReason: "Station exceeded the official time cap."
                )
            }
        }

        if enforceLoadPercent, let loadPercent = station.loadPercentOfBodyweight {
            guard let bodyweightKg else {
                return stationResult(
                    station,
                    qualifyingSetsCompleted: 0,
                    totalValue: values.reduce(0, +),
                    failedQualityFlags: [],
                    status: .failed,
                    failureReason: "Bodyweight is required for the load standard."
                )
            }
            let minimumLoad = bodyweightKg * loadPercent
            let loadedSetExists = cleanSets.contains { ($0.weightKg ?? 0) >= minimumLoad }
            if !loadedSetExists {
                return stationResult(
                    station,
                    qualifyingSetsCompleted: 0,
                    totalValue: values.reduce(0, +),
                    failedQualityFlags: [],
                    status: .failed,
                    failureReason: "Logged load missed the bodyweight percentage standard."
                )
            }
        }

        // Use effectiveMinimum (respects per-option floorOverride) instead of
        // raw standard.minimumValue so substitution options get correct floors.
        let qualifyingSetCount = values.filter { $0 >= effectiveMinimum }.count
        let status: OverallRankTrialStationStatus = qualifyingSetCount >= standard.minimumQualifyingSets ? .passed : .failed
        return stationResult(
            station,
            qualifyingSetsCompleted: qualifyingSetCount,
            totalValue: values.reduce(0, +),
            failedQualityFlags: [],
            status: status,
            failureReason: status == .passed ? nil : "Station floor was not cleared."
        )
    }

    private func stationResult(
        _ station: TrialStation,
        qualifyingSetsCompleted: Int,
        totalValue: Int,
        failedQualityFlags: Set<PerformanceQualityFlag>,
        status: OverallRankTrialStationStatus,
        failureReason: String?
    ) -> OverallRankTrialStationResult {
        OverallRankTrialStationResult(
            id: station.id,
            title: station.title,
            category: station.category,
            movementId: station.standard.movementId,
            required: station.standard.minimumValue,
            qualifyingSetsRequired: station.standard.minimumQualifyingSets,
            qualifyingSetsCompleted: qualifyingSetsCompleted,
            totalValue: totalValue,
            failedQualityFlags: failedQualityFlags,
            status: status,
            failureReason: failureReason
        )
    }

    private func value(for set: PerformanceSet, metric: TrainingMetricKind) -> Int {
        switch metric {
        case .reps:
            return set.reps ?? 0
        case .holdSeconds:
            return set.holdSeconds ?? 0
        case .durationSeconds:
            return set.durationSeconds ?? 0
        case .distanceMeters:
            return set.distanceMeters ?? 0
        case .calories:
            return set.calories ?? 0
        }
    }

    func performanceLog(
        from draft: TrainingSessionDraft,
        userId: String,
        startedAt: Date,
        completedAt: Date,
        passing: Bool
    ) -> PerformanceLog {
        let definition = draft.programId.flatMap(OverallRankTrialDefinitions.definition)
        let selectedLoadout = selectedLoadout(inDraft: draft)

        return PerformanceLog(
            id: draft.id,
            userId: userId,
            draftId: draft.id,
            source: draft.source,
            title: draft.title,
            startedAt: startedAt,
            completedAt: completedAt,
            programId: draft.programId,
            dayNumber: draft.dayNumber,
            blocks: draft.blocks.map { block in
                PerformanceBlock(
                    id: block.id,
                    kind: block.kind,
                    title: block.title,
                    skillId: block.skillId,
                    routineId: block.routineId,
                    cardioType: block.cardioType,
                    exercises: block.prescriptions.map { prescription in
                        let metric = prescription.target.metricKind
                        let target = prescription.target.metricLowerBound ?? 1
                        let loadoutStations = selectedLoadout
                            .flatMap { selected in
                                definition?.loadoutVariants.first(where: { $0.loadout == selected })?.stations
                            } ?? definition?.loadoutVariants.flatMap(\.stations) ?? []
                        let station = loadoutStations
                            .first { station in
                                station.allowedMovementIds.contains(prescription.movementId ?? "")
                                    || station.allowedMovementIds.contains(prescription.rankStandardMovementId ?? "")
                                    || station.allowedMovementIds.contains(MovementResolver.resolve(prescription.exerciseName).movementId)
                            }
                        let standard = definition?.performanceStandards.first { standard in
                            prescription.movementId == standard.movementId
                                || prescription.rankStandardMovementId == standard.movementId
                                || MovementResolver.resolve(prescription.exerciseName).movementId == standard.movementId
                        } ?? station?.standard
                        let setCount = max(1, standard?.minimumQualifyingSets ?? prescription.sets)
                        let achieved = passing ? target : max(0, target - 1)
                        let loadKg = station?.loadPercentOfBodyweight == nil ? nil : 50.0
                        return PerformanceExercise(
                            id: prescription.id,
                            name: prescription.exerciseName,
                            movementId: prescription.movementId,
                            rankStandardMovementId: prescription.rankStandardMovementId,
                            plannedSets: prescription.sets,
                                    plannedTarget: prescription.displayTargetText,
                            sets: (1...setCount).map { setNumber in
                                PerformanceSet(
                                    setNumber: setNumber,
                                    reps: metric == .reps ? achieved : nil,
                                    weightKg: loadKg,
                                    holdSeconds: metric == .holdSeconds ? achieved : nil,
                                    durationSeconds: metric == .durationSeconds ? achieved : nil,
                                    distanceMeters: metric == .distanceMeters ? achieved : nil,
                                    calories: metric == .calories ? achieved : nil,
                                    rpe: passing ? 8 : 7,
                                    qualityFlags: passing ? [.clean] : []
                                )
                            },
                            notes: prescription.notes
                        )
                    },
                    notes: block.notes
                )
            }
        )
    }

    private func selectedLoadout(inDraft draft: TrainingSessionDraft) -> TrialLoadout? {
        let markers = [" rank trial station:", " official station:"]
        let notes = draft.blocks.flatMap { block in
            [block.notes] + block.prescriptions.map(\.notes)
        }.compactMap { $0 }

        for note in notes {
            for marker in markers where note.contains(marker) {
                let label = note
                    .components(separatedBy: marker)
                    .first?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let loadout = TrialLoadout.allCases.first(where: { $0.displayName == label }) {
                    return loadout
                }
            }
        }
        return nil
    }

    private func definition(for performanceLog: PerformanceLog) -> OverallRankTrialDefinition? {
        guard performanceLog.source == .overallRankTrial,
              let definitionId = performanceLog.programId
        else { return nil }
        return OverallRankTrialDefinitions.definition(id: definitionId)
    }
}

extension Notification.Name {
    static let overallRankTrialCompleted = Notification.Name("unbound.overallRankTrialCompleted")
}
