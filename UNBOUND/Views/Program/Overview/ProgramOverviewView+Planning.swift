import SwiftUI

extension ProgramOverviewView {
    var planningCoordinator: ProgramPlanningCoordinator? {
        guard let userId = services.auth.currentUserId else { return nil }
        return ProgramPlanningCoordinator(
            userId: userId,
            programId: viewModel.program?.id,
            today: programToday,
            scheduleStore: ProgramScheduleStore.shared
        )
    }

    func emptyCustomWorkoutDraft(
        title: String = "Planned Loadout",
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
            ?? emptyCustomWorkoutDraft(title: "Built Loadout", date: date)
        guard let draft else { return }
        planningTargetDate = date
        planningWorkoutDraft = draft
    }

    func openCreateWorkoutEditor(date: Date? = nil) {
        let targetDate = date ?? selectedPlanningDate()
        guard let draft = emptyCustomWorkoutDraft(title: "New Loadout", date: targetDate) else { return }
        planningTargetDate = targetDate
        planningWorkoutDraft = draft
    }

    func selectedPlanningDate() -> Date {
        planningCoordinator?.planningDate(
            selectedDate: selectedDayDate,
            isSelectedDatePast: isProgramPast(selectedDayDate)
        ) ?? selectedDayDate
    }

    func placeSavedWorkoutOnCalendar(_ workout: SavedWorkout, date: Date) {
        applySavedWorkout(workout, to: date, allowExtraSession: false)
    }

    /// Point the week strip at the week containing `date` (Monday-start weeks,
    /// matching ProgramWeekPresenter).
    func alignWeekOffset(to date: Date) {
        var weekCalendar = Calendar.current
        weekCalendar.firstWeekday = 2
        guard let thisWeek = weekCalendar.dateInterval(of: .weekOfYear, for: programToday)?.start,
              let targetWeek = weekCalendar.dateInterval(of: .weekOfYear, for: date)?.start,
              let weeks = weekCalendar.dateComponents([.weekOfYear], from: thisWeek, to: targetWeek).weekOfYear
        else { return }
        weekOffset = weeks
    }

    func startSavedWorkout(_ workout: SavedWorkout) {
        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Saved workout start skipped without authenticated user",
                level: .warning,
                context: ["savedWorkoutId": workout.id.uuidString]
            )
            return
        }

        // Ad-hoc starts get the same progression pass as scheduled days —
        // climbing rep targets + suggested weights — so a loadout never
        // replays stale template numbers.
        let draft = workout.asDraft(
            userId: userId,
            date: programToday,
            programId: nil,
            dayNumber: nil
        )
        activeWorkoutDraft = TrainingPrescriptionResolver.resolve(
            draft: draft,
            progressionStates: viewModel.progressionStates
        )
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
            programId: viewModel.program?.id
        )
    }

    /// One line for the Plan calendar header naming the split and its weekly
    /// rhythm, e.g. "Push · Pull · Legs — 5 days/week".
    func monthPlannerSplitSummary() -> String? {
        guard let program = viewModel.program, !program.days.isEmpty else { return nil }
        let trainingDays = program.days.filter { !$0.isRestDay }
        guard !trainingDays.isEmpty else { return nil }

        var seen = Set<String>()
        var names: [String] = []
        for day in trainingDays {
            let name: String
            if case .custom("unspecified") = day.sessionRole {
                name = day.label.split(separator: " ").first.map { String($0).capitalized } ?? "Train"
            } else {
                name = day.sessionRole.compactLabel.capitalized
            }
            if seen.insert(name).inserted { names.append(name) }
        }

        var split = names.prefix(4).joined(separator: " · ")
        if names.count > 4 { split += " +\(names.count - 4)" }
        if program.days.count == 7 {
            return "\(split) — \(trainingDays.count) days/week"
        }
        return "\(split) — \(trainingDays.count) of \(program.days.count) days training"
    }

    /// Resolves one calendar date into what the Plan sheet paints on its cell:
    /// generated split day, user-placed loadout, travel override, rest, done.
    func monthPlannerDayInfo(for date: Date) -> ProgramPlannerDayInfo? {
        guard let program = viewModel.program,
              let day = programDay(for: date, in: program)
        else { return nil }

        let isPlannedByUser: Bool
        if let userId = services.auth.currentUserId {
            isPlannedByUser = ProgramScheduleStore.shared.primaryOccurrence(
                on: date,
                userId: userId,
                programId: program.id
            ) != nil
        } else {
            isPlannedByUser = false
        }

        let role = day.sessionRole
        // Untagged days (travel overrides and older programs land on
        // .custom("unspecified")) read their tag from the day label instead —
        // "TRAVEL · PUSH" → "TRAVEL".
        let label: String?
        if day.isRestDay {
            label = nil
        } else if case .custom("unspecified") = role {
            label = day.label.split(separator: " ").first.map { String($0.prefix(6)).uppercased() }
        } else {
            label = role.compactLabel
        }

        return ProgramPlannerDayInfo(
            label: label,
            accent: role.accentColor,
            isRest: day.isRestDay,
            isPlannedByUser: isPlannedByUser,
            isCompleted: isCompletedProgramDay(day, on: date)
        )
    }

    func exerciseStarterAlternatives(program: TrainingProgram?) -> [CatalogExercise] {
        let equipment = viewModel.currentProfile?.equipment
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
        let equipment = viewModel.currentProfile?.equipment
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

    func saveWorkoutToLibrary(_ draft: TrainingSessionDraft) {
        autoSaveBuiltWorkoutToLibrary(draft, fallbackTitle: "Saved Loadout")
        savedWorkoutLibraryRevision += 1
        savedWorkoutEditorDraft = nil
    }

    /// A workout the user builds is auto-saved to the reusable library — no
    /// explicit "Save" button. The library entry id is keyed off the draft id so
    /// re-editing the same built workout updates that entry instead of creating a
    /// duplicate.
    private func autoSaveBuiltWorkoutToLibrary(
        _ draft: TrainingSessionDraft,
        fallbackTitle: String = "Built Loadout"
    ) {
        let exerciseCount = draft.blocks.reduce(0) { $0 + $1.prescriptions.count }
        guard exerciseCount > 0 else { return }
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        var saved = SavedWorkout.from(
            draft,
            title: trimmedTitle.isEmpty ? fallbackTitle : trimmedTitle
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
        let day = viewModel.program.flatMap { programDay(for: normalizedDate, in: $0) }
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
        guard let program = viewModel.program,
              let day = programDay(for: date, in: program),
              !day.isRestDay
        else {
            return nil
        }
        return programDraft(from: day, date: date)
    }

    func openStartEmptyWorkout(title: String = "Extra Quest") {
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
            // Single ask, matching the one-number prescription language; the
            // progression window comes from state once the exercise is logged.
            switch definition?.blockKind {
            case .bodyweight:
                return .reps(5)
            case .skill:
                return .reps(3)
            default:
                return .reps(8)
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
