import SwiftUI

extension ProgramOverviewView {
    var planningCoordinator: ProgramPlanningCoordinator? {
        guard let userId = services.auth.currentUserId else { return nil }
        return ProgramPlanningCoordinator(
            userId: userId,
            programId: viewModel?.program?.id,
            today: programToday,
            scheduleStore: ProgramScheduleStore.shared
        )
    }

    func emptyCustomWorkoutDraft(
        title: String = "Planned Workout",
        date: Date? = nil
    ) -> TrainingSessionDraft? {
        guard let planningCoordinator else {
            LoggingService.shared.log(
                "Custom workout launch skipped without authenticated user",
                level: .warning
            )
            return nil
        }
        return planningCoordinator.emptyDraft(title: title, date: date)
    }

    func openPlanAheadEditor() {
        let date = selectedPlanningDate()
        let draft = draftForBuildEditor(on: date)
            ?? emptyCustomWorkoutDraft(title: "Built Workout", date: date)
        guard let draft else { return }
        planningTargetDate = date
        planningWorkoutDraft = draft
    }

    func openCreateWorkoutEditor(date: Date? = nil) {
        let targetDate = date ?? selectedPlanningDate()
        guard let draft = emptyCustomWorkoutDraft(title: "New Workout", date: targetDate) else { return }
        planningTargetDate = targetDate
        planningWorkoutDraft = draft
    }

    func selectedPlanningDate() -> Date {
        planningCoordinator?.planningDate(
            selectedDate: selectedDayDate,
            isSelectedDatePast: isProgramPast(selectedDayDate)
        ) ?? selectedDayDate
    }

    func openSavedWorkoutForToday(_ workout: SavedWorkout) {
        if !services.entitlement.isEntitled {
            showPaywall = true
            return
        }
        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Saved workout quick start skipped without authenticated user",
                level: .warning,
                context: ["savedWorkoutId": workout.id.uuidString]
            )
            return
        }

        sessionEditorDraft = workout.asDraft(
            userId: userId,
            date: programToday,
            programId: nil,
            dayNumber: nil
        )
    }

    func placeSavedWorkoutOnCalendar(_ workout: SavedWorkout, date: Date) {
        applySavedWorkout(workout, to: date, allowExtraSession: false)
    }

    func markRestDayOnCalendar(_ date: Date) {
        guard let planningCoordinator else { return }
        let savedDate = planningCoordinator.markRestDay(date: date)
        programScheduleRevision += 1
        selectedDayDate = savedDate
    }

    func clearPlannedDayOnCalendar(_ date: Date) {
        guard let planningCoordinator else { return }
        let clearedDate = planningCoordinator.clearPlannedDay(date: date)
        programScheduleRevision += 1
        selectedDayDate = clearedDate
    }

    func monthPlannerOccurrences() -> [ProgramScheduleOccurrence] {
        guard let userId = services.auth.currentUserId else { return [] }
        return ProgramScheduleStore.shared.all(
            userId: userId,
            programId: viewModel?.program?.id
        )
    }

    func exerciseStarterAlternatives(program: TrainingProgram?) -> [CatalogExercise] {
        let equipment = currentProfile?.equipment
            ?? program.map(currentEquipmentFallback(program:))
            ?? [Equipment.bodyweight]
        var seen: Set<String> = []
        return MovementCatalog.programDefinitions(
            style: effectiveTrainingStyle(),
            userEquipment: equipment
        )
        .compactMap(MovementCatalog.catalogExercise(for:))
        .filter { exercise in
            guard !seen.contains(exercise.name) else { return false }
            seen.insert(exercise.name)
            return true
        }
    }

    func exerciseStarterSheetAlternatives(program: TrainingProgram?) -> [CatalogExercise] {
        let key = exerciseStarterCacheKey(program: program)
        guard key == exerciseStarterAlternativesCacheKey else {
            return exerciseStarterAlternatives(program: program)
        }
        return exerciseStarterAlternativesCache
    }

    func refreshExerciseStarterAlternativesCache(program: TrainingProgram?) {
        let key = exerciseStarterCacheKey(program: program)
        guard key != exerciseStarterAlternativesCacheKey || exerciseStarterAlternativesCache.isEmpty else { return }
        exerciseStarterAlternativesCache = exerciseStarterAlternatives(program: program)
        exerciseStarterAlternativesCacheKey = key
    }

    func exerciseStarterCacheKey(program: TrainingProgram?) -> String {
        let equipment = currentProfile?.equipment
            ?? program.map(currentEquipmentFallback(program:))
            ?? [Equipment.bodyweight]
        let equipmentKey = equipment
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
        return "\(effectiveTrainingStyle().rawValue)|\(equipmentKey)"
    }

    func openExerciseStarter(_ exercise: CatalogExercise) {
        if !services.entitlement.isEntitled {
            showPaywall = true
            return
        }
        guard let draft = starterDraft(from: exercise) else { return }
        sessionEditorDraft = draft
    }

    func savePlannedWorkoutAndOpenSchedule(_ draft: TrainingSessionDraft) {
        guard let planningCoordinator else { return }
        let date = planningTargetDate ?? selectedPlanningDate()
        let savedDate = planningCoordinator.saveBuiltWorkout(
            draft,
            date: date,
            generatedDayNumber: generatedDayNumber(for: date)
        )
        autoSaveBuiltWorkoutToLibrary(draft)
        programScheduleRevision += 1
        selectedDayDate = savedDate
        planningTargetDate = nil
        planningWorkoutDraft = nil
    }

    /// A workout the user builds is auto-saved to the reusable library — no
    /// explicit "Save" button. The library entry id is keyed off the draft id so
    /// re-editing the same built workout updates that entry instead of creating a
    /// duplicate.
    private func autoSaveBuiltWorkoutToLibrary(_ draft: TrainingSessionDraft) {
        let exerciseCount = draft.blocks.reduce(0) { $0 + $1.prescriptions.count }
        guard exerciseCount > 0 else { return }
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        var saved = SavedWorkout.from(
            draft,
            title: trimmedTitle.isEmpty ? "Built Workout" : trimmedTitle
        )
        if let stableId = UUID(uuidString: draft.id) {
            saved.id = stableId
        }
        SavedWorkoutStore.shared.save(saved)
    }

    func applySavedWorkout(
        _ workout: SavedWorkout,
        to date: Date,
        allowExtraSession: Bool
    ) {
        guard let planningCoordinator else { return }
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let day = viewModel?.program.flatMap { programDay(for: normalizedDate, in: $0) }
        switch planningCoordinator.savedWorkoutApplication(
            workout: workout,
            date: normalizedDate,
            allowExtraSession: allowExtraSession,
            isToday: isProgramToday(normalizedDate),
            isCompletedProgramDay: isCompletedProgramDay(day)
        ) {
        case .extraSessionDraft(let draft):
            sessionEditorDraft = draft
        case .scheduledOccurrence(let date, let occurrence):
            planningCoordinator.saveSavedWorkoutOccurrence(occurrence, date: date)
            programScheduleRevision += 1
            selectedDayDate = date
        }
    }

    func draftForBuildEditor(on date: Date) -> TrainingSessionDraft? {
        guard let program = viewModel?.program,
              let day = programDay(for: date, in: program),
              !day.isRestDay
        else {
            return nil
        }
        return programDraft(from: day, date: date)
    }

    func openStartEmptyWorkout(title: String = "Extra Session") {
        if !services.entitlement.isEntitled {
            showPaywall = true
            return
        }
        sessionEditorDraft = emptyCustomWorkoutDraft(title: title, date: programToday)
    }

    private func starterDraft(from exercise: CatalogExercise) -> TrainingSessionDraft? {
        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Exercise starter skipped without authenticated user",
                level: .warning,
                context: ["exercise": exercise.name]
            )
            return nil
        }

        let definition = MovementCatalog.canonicalExercise(named: exercise.name)
        let prescription = TrainingBlockPrescription(
            exerciseName: exercise.displayName,
            movementId: definition?.id,
            rankStandardMovementId: definition?.rankStandardMovementId,
            sets: starterSets(for: definition),
            target: starterTarget(for: definition),
            restSeconds: starterRest(for: definition),
            muscleGroups: definition?.muscleGroups ?? exercise.muscleGroups,
            rpe: starterRPE(for: definition)
        )

        return TrainingSessionDraft(
            userId: userId,
            source: .custom,
            title: exercise.displayName,
            date: programToday,
            estimatedMinutes: starterEstimatedMinutes(for: prescription),
            blocks: [
                TrainingBlock(
                    kind: definition?.blockKind ?? .strength,
                    title: "Main Work",
                    prescriptions: [prescription]
                )
            ]
        )
    }

    private func starterSets(for definition: MovementDefinition?) -> Int {
        switch definition?.defaultMetric {
        case .holdSeconds, .durationSeconds, .distanceMeters, .calories:
            return 3
        case .reps, .none:
            return 3
        }
    }

    private func starterTarget(for definition: MovementDefinition?) -> TrainingTarget {
        switch definition?.defaultMetric {
        case .holdSeconds:
            return .holdSeconds(20)
        case .durationSeconds:
            return .timedSeconds(300)
        case .distanceMeters:
            return .distanceMeters(400)
        case .calories:
            return .calories(30)
        case .reps, .none:
            switch definition?.blockKind {
            case .bodyweight:
                return .repsRange(5, 10)
            case .skill:
                return .repsRange(3, 5)
            default:
                return .repsRange(8, 12)
            }
        }
    }

    private func starterRest(for definition: MovementDefinition?) -> Int {
        switch definition?.blockKind {
        case .skill, .carry:
            return 120
        case .bodyweight:
            return 90
        case .cardio:
            return 60
        case .routine:
            return 30
        case .strength, .custom, .none:
            return 90
        }
    }

    private func starterRPE(for definition: MovementDefinition?) -> Int? {
        switch definition?.blockKind {
        case .cardio, .routine:
            return nil
        case .skill:
            return 7
        case .strength, .bodyweight, .carry, .custom, .none:
            return 8
        }
    }

    private func starterEstimatedMinutes(for prescription: TrainingBlockPrescription) -> Int {
        let workSeconds: Int
        switch prescription.target {
        case .holdSeconds(let seconds), .timedSeconds(let seconds):
            workSeconds = seconds
        case .distanceMeters, .calories:
            workSeconds = 90
        case .reps, .repsRange, .amrap:
            workSeconds = 45
        }
        let totalSeconds = (workSeconds + prescription.restSeconds) * max(1, prescription.sets)
        return max(8, Int(ceil(Double(totalSeconds) / 60.0)))
    }
}
