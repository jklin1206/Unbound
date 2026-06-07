import XCTest
@testable import UNBOUND

final class ProgramOverviewStateMachineTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testAppearedTransitionsToLoadingAndRequestsRefresh() {
        var machine = ProgramOverviewStateMachine(
            initialDate: Date(timeIntervalSince1970: 1_780_000_000),
            calendar: calendar
        )

        let transition = machine.send(.appeared)

        XCTAssertTrue(transition.shouldRefresh)
        guard case .loading = machine.state else {
            return XCTFail("Expected loading state after appear")
        }
    }

    func testSelectDateNormalizesToStartOfDay() throws {
        let initial = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 6, hour: 18)))
        let selected = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 14, minute: 42)))
        var machine = ProgramOverviewStateMachine(initialDate: initial, calendar: calendar)

        _ = machine.send(.selectDate(selected))

        let content = try XCTUnwrap(machine.readyContent)
        XCTAssertEqual(content.selectedDate, calendar.startOfDay(for: selected))
    }

    func testResolveSelectedDayUpdatesSourceAndPrimaryAction() throws {
        var machine = ProgramOverviewStateMachine(
            initialDate: Date(timeIntervalSince1970: 1_780_000_000),
            calendar: calendar
        )

        _ = machine.send(.resolveSelectedDay(nil, .customBuild, .reviewAndStart))

        let content = try XCTUnwrap(machine.readyContent)
        guard case .customBuild = content.selectedResolution else {
            return XCTFail("Expected custom build resolution")
        }
        guard case .reviewAndStart = content.primaryAction else {
            return XCTFail("Expected review and start primary action")
        }
    }

    func testLoadWeekReplacesWeekTiles() throws {
        let date = Date(timeIntervalSince1970: 1_780_000_000)
        var machine = ProgramOverviewStateMachine(initialDate: date, calendar: calendar)
        let tile = ProgramOverviewWeekTile(
            date: date,
            resolution: .savedWorkout,
            isToday: true,
            isCompleted: false,
            calendar: calendar
        )

        _ = machine.send(.loadWeek([tile]))

        let content = try XCTUnwrap(machine.readyContent)
        XCTAssertEqual(content.week.count, 1)
        XCTAssertEqual(content.week.first?.id, tile.id)
    }

    func testDayActionResolverDisablesEmptyDay() {
        let state = ProgramOverviewDayActionResolver.resolve(
            ProgramOverviewDayActionInput(hasDay: false, isToday: true)
        )

        guard case .none = state.primaryAction else {
            return XCTFail("Expected no primary action")
        }
        XCTAssertEqual(state.label, "NOTHING PLANNED")
        XCTAssertFalse(state.isEnabled)
        XCTAssertFalse(state.showsAddExtraSession)
        XCTAssertFalse(state.showsEditSession)
    }

    func testDayActionResolverAllowsExtraSessionAfterCompletedToday() {
        let state = ProgramOverviewDayActionResolver.resolve(
            ProgramOverviewDayActionInput(
                hasDay: true,
                isToday: true,
                isCompleted: true,
                hasWorkout: true
            )
        )

        guard case .viewLog = state.primaryAction else {
            return XCTFail("Expected view log action")
        }
        XCTAssertEqual(state.label, "VIEW LOG")
        XCTAssertTrue(state.isEnabled)
        XCTAssertTrue(state.showsAddExtraSession)
        XCTAssertFalse(state.showsEditSession)
    }

    func testDayActionResolverCompletesTodayRestDay() {
        let state = ProgramOverviewDayActionResolver.resolve(
            ProgramOverviewDayActionInput(
                hasDay: true,
                isToday: true,
                isRestDay: true
            )
        )

        guard case .completeRecovery = state.primaryAction else {
            return XCTFail("Expected complete recovery action")
        }
        XCTAssertEqual(state.label, "COMPLETE RECOVERY")
        XCTAssertTrue(state.isEnabled)
        XCTAssertFalse(state.showsAddExtraSession)
        XCTAssertFalse(state.showsEditSession)
    }

    func testDayActionResolverPrefersResumeForTodayDraft() {
        let state = ProgramOverviewDayActionResolver.resolve(
            ProgramOverviewDayActionInput(
                hasDay: true,
                isToday: true,
                hasWorkout: true,
                hasResumableDraft: true
            )
        )

        guard case .resumeWorkout = state.primaryAction else {
            return XCTFail("Expected resume action")
        }
        XCTAssertEqual(state.label, "RESUME SESSION")
        XCTAssertTrue(state.isEnabled)
        XCTAssertFalse(state.showsAddExtraSession)
        XCTAssertTrue(state.showsEditSession)
    }

    func testDayActionResolverBeginsTodayWorkoutWithoutReview() {
        let state = ProgramOverviewDayActionResolver.resolve(
            ProgramOverviewDayActionInput(
                hasDay: true,
                isToday: true,
                hasWorkout: true
            )
        )

        guard case .loadWorkout = state.primaryAction else {
            return XCTFail("Expected direct workout load action")
        }
        XCTAssertEqual(state.label, "BEGIN SESSION")
        XCTAssertTrue(state.isEnabled)
        XCTAssertFalse(state.showsAddExtraSession)
        XCTAssertTrue(state.showsEditSession)
    }

    func testDayActionResolverUsesEditorForNonTodayWorkout() {
        let state = ProgramOverviewDayActionResolver.resolve(
            ProgramOverviewDayActionInput(
                hasDay: true,
                isToday: false,
                hasWorkout: true
            )
        )

        guard case .editWorkout = state.primaryAction else {
            return XCTFail("Expected edit workout action")
        }
        XCTAssertEqual(state.label, "EDIT WORKOUT")
        XCTAssertTrue(state.isEnabled)
        XCTAssertFalse(state.showsAddExtraSession)
        XCTAssertFalse(state.showsEditSession)
    }

    func testDayPreviewResolverUsesVisibleDraftBlocksAndDedupesExercises() {
        let day = makeProgramDay(name: "Push Base")
        let draft = TrainingSessionDraft(
            userId: "u1",
            source: .program,
            title: "Handstand Push",
            estimatedMinutes: 28,
            blocks: [
                TrainingBlock(
                    kind: .skill,
                    title: "Skill",
                    prescriptions: [
                        TrainingBlockPrescription(
                            id: "wall-handstand",
                            exerciseName: "Wall Handstand",
                            sets: 4,
                            target: .holdSeconds(20),
                            restSeconds: 90,
                            muscleGroups: [.shoulders, .core],
                            rpe: 7
                        )
                    ]
                ),
                TrainingBlock(
                    kind: .strength,
                    title: "Strength",
                    prescriptions: [
                        TrainingBlockPrescription(
                            id: "pushup-a",
                            exerciseName: "Pushup",
                            sets: 3,
                            target: .repsRange(8, 10),
                            restSeconds: 75,
                            muscleGroups: [.chest, .shoulders],
                            rpe: 8
                        ),
                        TrainingBlockPrescription(
                            id: "pushup-b",
                            exerciseName: "pushup",
                            sets: 2,
                            target: .reps(12),
                            restSeconds: 60,
                            muscleGroups: [.chest],
                            rpe: 7
                        )
                    ]
                ),
                TrainingBlock(
                    kind: .routine,
                    title: "Hidden Routine",
                    prescriptions: [
                        TrainingBlockPrescription(
                            id: "routine-only",
                            exerciseName: "Jumping Jack",
                            sets: 1,
                            target: .timedSeconds(30),
                            restSeconds: 15,
                            muscleGroups: [.legs]
                        )
                    ]
                )
            ]
        )

        let workout = ProgramDayPreviewResolver.previewWorkout(for: day, draft: draft)

        XCTAssertEqual(workout?.name, "Handstand Push")
        XCTAssertEqual(workout?.estimatedMinutes, 28)
        XCTAssertEqual(workout?.mainExercises.map(\.name), ["Wall Handstand", "Pushup"])
        XCTAssertEqual(workout?.targetMuscleGroups, [.chest, .shoulders, .core])
    }

    func testSelectedDayPresenterSummarizesRestAndCompletedDays() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8)))
        let day = makeProgramDay(name: "Push Base")
        let presentation = ProgramSelectedDayPresenter.presentation(
            day: day,
            date: date,
            isToday: true,
            isCompleted: true,
            workout: day.workout,
            skillNodes: []
        )

        XCTAssertEqual(presentation.headerLabel, "TODAY")
        XCTAssertEqual(presentation.title, "PUSH BASE")
        XCTAssertEqual(presentation.metrics.map(\.title), ["1 moves", "~30M", "LIVE"])
        guard case .completed = presentation.badge else {
            return XCTFail("Expected completed badge")
        }

        let restDay = ProgramDay(
            id: "rest",
            dayNumber: 2,
            label: "Recovery",
            isRestDay: true,
            workout: nil,
            nutritionOverride: nil,
            recoveryActivities: []
        )
        let restPresentation = ProgramSelectedDayPresenter.presentation(
            day: restDay,
            date: date,
            isToday: false,
            isCompleted: false,
            workout: nil,
            skillNodes: []
        )

        XCTAssertEqual(restPresentation.title, "REST DAY")
        XCTAssertEqual(restPresentation.metrics.map(\.title), ["0 moves", "REC", "REC"])
        guard case .rest = restPresentation.badge else {
            return XCTFail("Expected rest badge")
        }
    }

    private func makeProgramDay(name: String) -> ProgramDay {
        ProgramDay(
            id: "day-\(name)",
            dayNumber: 1,
            label: name,
            isRestDay: false,
            workout: Workout(
                name: name,
                targetMuscleGroups: [.chest],
                warmup: [],
                mainExercises: [
                    Exercise(
                        id: "pushup",
                        name: "Pushup",
                        muscleGroups: [.chest, .shoulders],
                        sets: 3,
                        reps: "8",
                        restSeconds: 90,
                        rpe: 7,
                        notes: nil,
                        substitution: nil
                    )
                ],
                cooldown: [],
                estimatedMinutes: 30,
                notes: nil,
                blockType: nil
            ),
            sessionRole: .push,
            nutritionOverride: nil,
            recoveryActivities: []
        )
    }
}

private extension ProgramOverviewStateMachine {
    var readyContent: ProgramOverviewContentState? {
        guard case .ready(let content) = state else { return nil }
        return content
    }
}
