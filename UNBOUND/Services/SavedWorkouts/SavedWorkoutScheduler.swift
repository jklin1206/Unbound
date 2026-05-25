import Foundation

enum SavedWorkoutScheduler {
    enum ScheduleError: Error, Equatable {
        case dayNotFound(Int)
        case emptyWorkout(UUID)
        case customizedDayCollision(Int)
    }

    static func schedule(
        _ savedWorkout: SavedWorkout,
        on dayNumbers: [Int],
        in program: TrainingProgram,
        userId: String,
        replacingCustomizedDays: Bool = false
    ) throws -> TrainingProgram {
        guard savedWorkout.exerciseCount > 0 else {
            throw ScheduleError.emptyWorkout(savedWorkout.id)
        }

        var updated = program
        let uniqueDayNumbers = Array(Set(dayNumbers)).sorted()

        for dayNumber in uniqueDayNumbers {
            guard let index = updated.days.firstIndex(where: { $0.dayNumber == dayNumber }) else {
                throw ScheduleError.dayNotFound(dayNumber)
            }

            if updated.days[index].savedWorkoutId != nil && !replacingCustomizedDays {
                throw ScheduleError.customizedDayCollision(dayNumber)
            }

            let draft = savedWorkout.asDraft(
                userId: userId,
                date: scheduledDate(for: dayNumber, program: program),
                programId: program.id,
                dayNumber: dayNumber
            )
            let workout = TrainingSessionAdapters.workout(from: draft)
            updated.days[index].label = savedWorkout.title
            updated.days[index].isRestDay = false
            updated.days[index].workout = workout
            updated.days[index].sessionRole = SessionRole.fromStorageValue(savedWorkout.sessionRole) ?? .custom("saved")
            updated.days[index].savedWorkoutId = savedWorkout.id
            updated.days[index].recoveryActivities = []
        }

        return updated
    }

    static func unschedule(
        dayNumber: Int,
        in program: TrainingProgram,
        fallbackDay: ProgramDay? = nil
    ) throws -> TrainingProgram {
        var updated = program
        guard let index = updated.days.firstIndex(where: { $0.dayNumber == dayNumber }) else {
            throw ScheduleError.dayNotFound(dayNumber)
        }

        if let fallbackDay {
            updated.days[index] = fallbackDay
        } else {
            updated.days[index].savedWorkoutId = nil
        }
        return updated
    }

    private static func scheduledDate(for dayNumber: Int, program: TrainingProgram) -> Date {
        Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: max(0, dayNumber - 1),
            to: program.createdAt
        ) ?? program.createdAt
    }
}
