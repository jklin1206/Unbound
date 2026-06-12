import SwiftUI
import UIKit

extension ProgramRankExerciseDetailView {

    @MainActor
    func loadDetail() async {
        guard let userId = services.auth.currentUserId else {
            isLoading = false
            return
        }

        isLoading = true
        async let progressLoad: [MovementProgressState] = services.database.query(
            collection: "movement_progress",
            field: "userId",
            isEqualTo: userId,
            orderBy: nil,
            descending: true,
            limit: nil
        )
        async let logLoad: [PerformanceLog] = services.database.query(
            collection: "performanceLogs",
            field: "userId",
            isEqualTo: userId,
            orderBy: "completedAt",
            descending: true,
            limit: 80
        )
        async let profileLoad: UserProfile? = services.database.read(
            collection: "users",
            documentId: userId
        )

        let progressStates = (try? await progressLoad) ?? []
        let logs = (try? await logLoad) ?? []
        userProfile = try? await profileLoad
        progress = progressStates.first { $0.rankStandardMovementId == row.sourceId }
        history = ProgramRankExerciseHistoryEntry.entries(
            from: logs,
            rankStandardMovementId: row.sourceId
        )

        if !hasSeededDefaults {
            seedDefaults(from: progress)
            hasSeededDefaults = true
        }
        isLoading = false
    }

    @MainActor
    func submitLog() async {
        guard !isSubmitting else { return }
        guard let definition else {
            errorMessage = "This rank standard is missing from the movement catalog."
            return
        }
        guard let userId = services.auth.currentUserId else {
            errorMessage = "Sign in before saving a rank attempt."
            return
        }

        isSubmitting = true
        errorMessage = nil

        let now = Date()
        let performanceLog = makePerformanceLog(definition: definition, userId: userId, completedAt: now)
        let priorTier = displayedTier

        do {
            let result = try await TrainingCompletionService.shared.complete(performanceLog, services: services)
            let reveal = makeRankReveal(
                from: result,
                definition: definition,
                priorTier: priorTier
            )
            await loadDetail()
            await onLogged()
            if reveal.isRankUp {
                HapticManager.notification(.success)
            } else {
                UnboundHaptics.medium()
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                rankReveal = reveal
            }
        } catch {
            HapticManager.notification(.error)
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    func makePerformanceLog(
        definition: MovementDefinition,
        userId: String,
        completedAt: Date
    ) -> PerformanceLog {
        let set = PerformanceSet(
            setNumber: 1,
            reps: logMode.recordsReps ? selectedReps : logMode.recordsOneRepMax ? 1 : nil,
            weightKg: logMode.recordsOneRepMax ? selectedWeightKg : nil,
            holdSeconds: logMode == .hold ? selectedSeconds : nil,
            durationSeconds: nil,
            distanceMeters: nil,
            calories: nil,
            rpe: nil,
            qualityFlags: [],
            notes: nil
        )
        let exercise = PerformanceExercise(
            name: definition.displayName,
            movementId: definition.id,
            rankStandardMovementId: definition.rankStandardMovementId,
            plannedSets: 1,
            plannedTarget: logSummary,
            sets: [set],
            notes: nil
        )
        let block = PerformanceBlock(
            kind: definition.blockKind,
            title: definition.displayName,
            exercises: [exercise],
            durationSeconds: nil,
            distanceMeters: nil,
            calories: nil,
            notes: "Single rank attempt"
        )

        return PerformanceLog(
            id: "rank-log-\(UUID().uuidString)",
            userId: userId,
            source: .custom,
            title: "\(definition.displayName) Rank Attempt",
            startedAt: completedAt,
            completedAt: completedAt,
            blocks: [block],
            overallRPE: nil,
            notes: nil
        )
    }

    func makeRankReveal(
        from result: TrainingCompletionResult,
        definition: MovementDefinition,
        priorTier: SkillTier
    ) -> ProgramRankAttemptReveal {
        let standardId = definition.rankStandardMovementId
        let updatedProgress = result.movementProgressStates.first {
            $0.rankStandardMovementId == standardId
        }
        let previousTier = resolvedTier(for: result.movementProgressPriorStates[standardId]) ?? priorTier
        let achievedTier = resolvedTier(for: updatedProgress)
            ?? resolvedTier(for: result.movementProgressPriorStates[standardId])
            ?? priorTier

        return ProgramRankAttemptReveal(
            attemptSummary: logSummary,
            tier: achievedTier,
            previousTier: previousTier
        )
    }

    func resolvedTier(for state: MovementProgressState?) -> SkillTier? {
        guard let state else { return nil }
        return MovementProgressTierResolver.provenTier(
            for: state,
            bodyweightKg: userProfile?.weightKg,
            sex: userProfile?.biologicalSex
        )
    }

    var logSummary: String {
        switch logMode {
        case .oneRepMax:
            if definition?.rankTemplate == .weightedBodyweight {
                return "Added 1RM \(addedLoadSummary)"
            }
            return "1RM \(formatDisplayWeight(selectedWeightDisplay))"
        case .reps:
            return "\(selectedReps) reps"
        case .hold:
            return "\(ProgramRankExerciseFormatter.seconds(selectedSeconds)) hold"
        }
    }

    func seedDefaults(from progress: MovementProgressState?) {
        selectedReps = max(1, progress?.bestReps ?? 10)
        switch logMode {
        case .oneRepMax:
            if let oneRepMax = progress?.bestEstimatedOneRepMaxKg ?? progress?.bestLoadKg {
                selectedWeightDisplay = WeightPlatePolicy.editingValue(fromKilograms: oneRepMax, unit: weightUnit)
            } else {
                selectedWeightDisplay = defaultWeightDisplay
            }
        case .reps, .hold:
            selectedWeightDisplay = 0
        }
        selectedSeconds = progress?.bestHoldSeconds
            ?? progress?.bestDurationSeconds
            ?? defaultSeconds
    }

    var defaultWeightDisplay: Double {
        guard logMode == .oneRepMax else { return 0 }
        if definition?.rankTemplate == .weightedBodyweight { return 0 }
        return weightUnit == .pounds ? 135 : 60
    }

    var defaultSeconds: Int {
        switch logMode {
        case .hold: return 30
        default: return 30
        }
    }

    func weightRulerConfig(allowsBodyweight: Bool) -> ProgramRankWeightRulerConfig {
        let step = WeightPlatePolicy.loadIncrement(unit: weightUnit)
        let majorIncrement: Double = weightUnit == .pounds ? 25 : 10
        let start: Double
        let baseEnd: Double

        if definition?.rankTemplate == .weightedBodyweight {
            start = allowsBodyweight ? 0 : step
            baseEnd = weightUnit == .pounds ? 300 : 140
        } else {
            start = weightUnit == .pounds ? 45 : 20
            baseEnd = weightUnit == .pounds ? 1_000 : 450
        }
        let selectedEnd = selectedWeightDisplay > 0
            ? (ceil((selectedWeightDisplay + majorIncrement * 2) / majorIncrement) * majorIncrement)
            : baseEnd
        let end = max(baseEnd, selectedEnd)

        return ProgramRankWeightRulerConfig(
            start: start,
            end: end,
            step: step,
            majorDisplayIncrement: majorIncrement
        )
    }

    func formatDisplayWeight(_ value: Double) -> String {
        "\(WeightPlatePolicy.formatDisplayValue(value))\(weightUnit.shortLabel)"
    }
}
