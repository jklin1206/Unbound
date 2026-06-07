import Foundation

struct ProgramOverviewDayActionInput {
    var hasDay: Bool
    var isToday: Bool
    var isCompleted: Bool
    var isRestDay: Bool
    var isCalibration: Bool
    var hasWorkout: Bool
    var hasResumableDraft: Bool

    init(
        hasDay: Bool,
        isToday: Bool,
        isCompleted: Bool = false,
        isRestDay: Bool = false,
        isCalibration: Bool = false,
        hasWorkout: Bool = false,
        hasResumableDraft: Bool = false
    ) {
        self.hasDay = hasDay
        self.isToday = isToday
        self.isCompleted = isCompleted
        self.isRestDay = isRestDay
        self.isCalibration = isCalibration
        self.hasWorkout = hasWorkout
        self.hasResumableDraft = hasResumableDraft
    }
}

struct ProgramOverviewDayActionState {
    let primaryAction: ProgramOverviewPrimaryAction
    let label: String
    let isEnabled: Bool
    let showsAddExtraSession: Bool
    let showsEditSession: Bool
}

enum ProgramOverviewDayActionResolver {
    static func resolve(_ input: ProgramOverviewDayActionInput) -> ProgramOverviewDayActionState {
        guard input.hasDay else {
            return ProgramOverviewDayActionState(
                primaryAction: .none,
                label: "NOTHING PLANNED",
                isEnabled: false,
                showsAddExtraSession: false,
                showsEditSession: false
            )
        }

        if input.isCompleted {
            return ProgramOverviewDayActionState(
                primaryAction: .viewLog,
                label: input.isRestDay ? "VIEW RECOVERY" : "VIEW LOG",
                isEnabled: true,
                showsAddExtraSession: input.isToday,
                showsEditSession: false
            )
        }

        if input.isRestDay {
            return ProgramOverviewDayActionState(
                primaryAction: input.isToday ? .completeRecovery : .none,
                label: input.isToday ? "COMPLETE RECOVERY" : "REST DAY",
                isEnabled: input.isToday,
                showsAddExtraSession: false,
                showsEditSession: false
            )
        }

        if input.isCalibration {
            return ProgramOverviewDayActionState(
                primaryAction: input.hasWorkout ? (input.isToday ? .loadWorkout : .editWorkout) : .none,
                label: input.hasWorkout
                    ? (input.isToday ? "BEGIN SESSION" : "EDIT WORKOUT")
                    : "NOTHING PLANNED",
                isEnabled: input.hasWorkout,
                showsAddExtraSession: false,
                showsEditSession: input.isToday && input.hasWorkout
            )
        }

        if input.isToday, input.hasResumableDraft {
            return ProgramOverviewDayActionState(
                primaryAction: .resumeWorkout,
                label: "RESUME SESSION",
                isEnabled: true,
                showsAddExtraSession: false,
                showsEditSession: input.hasWorkout
            )
        }

        if input.isToday, input.hasWorkout {
            return ProgramOverviewDayActionState(
                primaryAction: .loadWorkout,
                label: "BEGIN SESSION",
                isEnabled: true,
                showsAddExtraSession: false,
                showsEditSession: true
            )
        }

        return ProgramOverviewDayActionState(
            primaryAction: input.hasWorkout ? .editWorkout : .none,
            label: input.hasWorkout ? "EDIT WORKOUT" : "NOTHING PLANNED",
            isEnabled: input.hasWorkout,
            showsAddExtraSession: false,
            showsEditSession: false
        )
    }
}
