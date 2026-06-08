import SwiftUI

extension ProgramOverviewView {
    // MARK: - Week strip

    var weekPresenter: ProgramWeekPresenter {
        ProgramWeekPresenter(
            today: programToday,
            selectedDate: selectedDayDate,
            weekOffset: weekOffset,
            dayResolver: dayResolver
        )
    }

    var weekStart: Date {
        weekPresenter.weekStart
    }

    func weekDates() -> [Date] {
        weekPresenter.dates()
    }

    func weekStrip(program: TrainingProgram) -> some View {
        let presentation = weekPresenter.presentation(
            for: program,
            isCompleted: isCompletedProgramDay
        )

        return ProgramWeekStrip(
            rangeLabel: presentation.rangeLabel,
            tiles: presentation.tiles,
            onPreviousWeek: { shift(weeks: -1) },
            onNextWeek: { shift(weeks: 1) },
            onSelectDate: selectWeekDate
        )
    }

    func shift(weeks: Int) {
        UnboundHaptics.soft()
        withAnimation(.easeInOut(duration: 0.18)) {
            weekOffset += weeks
        }
    }

    func selectWeekDate(_ date: Date) {
        let calendar = Calendar.current
        UnboundHaptics.soft()
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedDayDate = calendar.startOfDay(for: date)
        }
    }

    // MARK: - Day card

    func dayCard(program: TrainingProgram) -> some View {
        let day = programDay(for: selectedDayDate, in: program)
        let isToday = isProgramToday(selectedDayDate)
        let resolvedDraft = day.flatMap { programDraft(from: $0, date: selectedDayDate) }
        let workout = day.flatMap {
            ProgramDayPreviewResolver.previewWorkout(for: $0, draft: resolvedDraft)
        }
        let draftSkillNodes = ProgramSkillFocusResolver.skillNodes(from: resolvedDraft)
        let routedNodes = ProgramSkillFocusResolver.scheduledSkillNodes(on: selectedDayDate)
        let skillNodes = draftSkillNodes.isEmpty ? routedNodes : draftSkillNodes
        let presentation = ProgramSelectedDayPresenter.presentation(
            day: day,
            date: selectedDayDate,
            isToday: isToday,
            isCompleted: isCompletedProgramDay(day),
            workout: workout,
            skillNodes: skillNodes
        )

        let fuelText: String? = day.map { d in
            let target = program.nutritionPlan.target(for: d)
            return ProgramDayFuelSummary.text(
                kcal: target.calories,
                proteinGrams: target.proteinGrams,
                isRestDay: d.isRestDay
            )
        }

        return ProgramSelectedDayCard(
            headerLabel: presentation.headerLabel,
            title: presentation.title,
            contextLabel: presentation.contextLabel,
            badge: presentation.badge,
            heroTint: presentation.heroTint,
            metrics: presentation.metrics,
            skillNodes: presentation.skillNodes,
            fuelText: fuelText
        ) {
            if let day, !day.isRestDay, let workout {
                ProgramModifierSummaryRail(summary: programModifierSummary(for: day))
                ProgramWaveAdjustmentPanel(
                    adjustments: waveAdjustments(for: day),
                    onUndo: revertWaveAdjustment
                )
                ProgramWorkoutExerciseList(exercises: workout.mainExercises)
            }

            dayActionRow(day: day, isToday: isToday)
        }
    }

    func dayActionRow(day: ProgramDay?, isToday: Bool) -> some View {
        let isCompleted = isCompletedProgramDay(day)
        let actionState = ProgramOverviewDayActionResolver.resolve(
            ProgramOverviewDayActionInput(
                hasDay: day != nil,
                isToday: isToday,
                isCompleted: isCompleted,
                isRestDay: day?.isRestDay == true,
                isCalibration: isCalibrationDay(day),
                hasWorkout: day?.workout != nil,
                hasResumableDraft: resumableDraft(for: day) != nil
            )
        )
        return ProgramDayActionRow(
            actionState: actionState,
            isCompleted: isCompleted,
            isCompletingRecoveryDay: isCompletingRecoveryDay,
            onPrimary: {
                UnboundHaptics.medium()
                performDayPrimaryAction(actionState.primaryAction, day: day)
            },
            onAddExtra: {
                UnboundHaptics.soft()
                openStartEmptyWorkout(title: "Extra Session")
            },
            onEdit: {
                guard let day else { return }
                UnboundHaptics.soft()
                if !services.entitlement.isEntitled {
                    showPaywall = true
                    return
                }
                launchSessionEditor(for: day, date: selectedDayDate)
            }
        )
    }

    func performDayPrimaryAction(_ action: ProgramOverviewPrimaryAction, day: ProgramDay?) {
        guard let day else { return }
        if !services.entitlement.isEntitled {
            showPaywall = true
            return
        }

        switch action {
        case .viewLog, .viewDetails:
            selectedDay = day
        case .editWorkout:
            launchSessionEditor(for: day, date: selectedDayDate)
        case .completeRecovery:
            Task { await completeRecoveryDay(day) }
        case .resumeWorkout:
            if let draft = resumableDraft(for: day) {
                resumeDraft = draft
            } else {
                launchActiveWorkout(for: day, date: selectedDayDate)
            }
        case .reviewAndStart, .loadWorkout:
            if day.workout != nil {
                launchActiveWorkout(for: day, date: selectedDayDate)
            } else {
                selectedDay = day
            }
        case .addSession:
            openStartEmptyWorkout(title: "Extra Session")
        case .buildWorkout, .none:
            break
        }
    }

    func programModifierSummary(for day: ProgramDay) -> ProgramModifierSummary {
        guard let draft = programDraft(from: day, date: selectedDayDate) else {
            return ProgramModifierSummary(lines: [], visibleLimit: 3)
        }
        let summary = ProgramModifierSummary.summarize(
            draft: draft,
            isTravelDay: activeTravelOverride?.day(for: selectedDayDate) != nil
        )
        return ProgramModifierSummary(
            lines: summary.lines.filter { $0.kind != .scheduledSkill },
            visibleLimit: summary.visibleLimit
        )
    }

    func waveAdjustments(for day: ProgramDay) -> [WaveAdjustment] {
        viewModel?.activeWaveAdjustments.filter { $0.dayNumber == day.dayNumber } ?? []
    }

    func revertWaveAdjustment(_ adjustment: WaveAdjustment) {
        UnboundHaptics.soft()
        viewModel?.revertWaveAdjustment(adjustment, asOf: selectedDayDate)
    }
}
