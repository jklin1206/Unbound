import XCTest
@testable import UNBOUND

@MainActor
final class ProgramOverviewDayResolverTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testGeneratedDayWrapsAcrossProgramRotation() throws {
        let start = try date(year: 2026, month: 6, day: 1)
        let program = makeProgram(start: start)
        let selected = try XCTUnwrap(calendar.date(byAdding: .day, value: 3, to: start))
        let resolver = ProgramOverviewDayResolver(
            userId: "u1",
            activeTravelOverride: nil,
            scheduleRevision: 0,
            scheduleStore: makeScheduleStore(),
            calendar: calendar
        )

        let day = try XCTUnwrap(resolver.day(for: selected, in: program))

        XCTAssertEqual(day.dayNumber, 2)
        XCTAssertEqual(day.workout?.name, "Pull Base")
    }

    func testTravelOverrideReplacesGeneratedProgramDay() throws {
        let start = try date(year: 2026, month: 6, day: 1)
        let program = makeProgram(start: start)
        let selected = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
        let override = TravelOverride(
            userId: "u1",
            startDate: start,
            endDate: selected,
            summary: "Keep rhythm without gym equipment.",
            days: [
                TravelDay(
                    dayOffset: 1,
                    title: "HOTEL PUSH",
                    duration: "~25 MIN",
                    exercises: ["Pushup"],
                    isRest: false
                )
            ],
            createdAt: start
        )
        let resolver = ProgramOverviewDayResolver(
            userId: "u1",
            activeTravelOverride: override,
            scheduleRevision: 0,
            scheduleStore: makeScheduleStore(),
            calendar: calendar
        )

        let day = try XCTUnwrap(resolver.day(for: selected, in: program))

        XCTAssertEqual(day.dayNumber, 0)
        XCTAssertEqual(day.label, "TRAVEL · HOTEL PUSH")
        XCTAssertEqual(day.workout?.name, "HOTEL PUSH")
    }

    func testScheduledWorkoutWinsBeforeTravelOverride() throws {
        let start = try date(year: 2026, month: 6, day: 1)
        let program = makeProgram(start: start)
        let selected = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("program-day-resolver-\(UUID().uuidString)", isDirectory: true)
        let store = ProgramScheduleStore(directory: directory)
        let scheduledWorkout = makeWorkout(name: "User Pull")
        let occurrence = ProgramScheduleOccurrence(
            userId: "u1",
            programId: program.id,
            date: selected,
            kind: .built,
            title: scheduledWorkout.name,
            draft: TrainingSessionAdapters.draft(
                from: scheduledWorkout,
                userId: "u1",
                programId: program.id,
                dayNumber: 2
            )
        )
        store.replacePrimary(on: selected, userId: "u1", programId: program.id, with: occurrence)
        let override = TravelOverride(
            userId: "u1",
            startDate: start,
            endDate: selected,
            summary: "Travel week.",
            days: [
                TravelDay(
                    dayOffset: 1,
                    title: "HOTEL PUSH",
                    duration: "~25 MIN",
                    exercises: ["Pushup"],
                    isRest: false
                )
            ],
            createdAt: start
        )
        let resolver = ProgramOverviewDayResolver(
            userId: "u1",
            activeTravelOverride: override,
            scheduleRevision: 1,
            scheduleStore: store,
            calendar: calendar
        )

        let day = try XCTUnwrap(resolver.day(for: selected, in: program))

        XCTAssertEqual(day.dayNumber, 2)
        XCTAssertEqual(day.label, "User Pull")
        XCTAssertEqual(day.workout?.name, "User Pull")
        XCTAssertNotNil(day.userWorkoutDraft)
    }

    func testScheduledRestDayWinsBeforeTravelOverride() throws {
        let start = try date(year: 2026, month: 6, day: 1)
        let program = makeProgram(start: start)
        let selected = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
        let store = makeScheduleStore()
        let occurrence = ProgramScheduleOccurrence(
            userId: "u1",
            programId: program.id,
            date: selected,
            kind: .rest,
            title: "Rest",
            attachScheduledSkills: false,
            adaptsWithProgression: false
        )
        store.replacePrimary(on: selected, userId: "u1", programId: program.id, with: occurrence)
        let override = TravelOverride(
            userId: "u1",
            startDate: start,
            endDate: selected,
            summary: "Travel week.",
            days: [
                TravelDay(
                    dayOffset: 1,
                    title: "HOTEL PUSH",
                    duration: "~25 MIN",
                    exercises: ["Pushup"],
                    isRest: false
                )
            ],
            createdAt: start
        )
        let resolver = ProgramOverviewDayResolver(
            userId: "u1",
            activeTravelOverride: override,
            scheduleRevision: 1,
            scheduleStore: store,
            calendar: calendar
        )

        let day = try XCTUnwrap(resolver.day(for: selected, in: program))

        XCTAssertTrue(day.isRestDay)
        XCTAssertEqual(day.dayNumber, 2)
        XCTAssertEqual(day.label, "Rest")
        XCTAssertNil(day.workout)
    }

    private func date(year: Int, month: Int, day: Int) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func makeScheduleStore() -> ProgramScheduleStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("program-day-resolver-\(UUID().uuidString)", isDirectory: true)
        return ProgramScheduleStore(directory: directory)
    }

    private func makeProgram(start: Date) -> TrainingProgram {
        TrainingProgram(
            id: "program-1",
            scanId: "scan-1",
            analysisId: "analysis-1",
            userId: "u1",
            createdAt: start,
            name: "Test Block",
            description: "Fixture",
            durationDays: 2,
            days: [
                makeDay(number: 1, name: "Push Base", role: .push),
                makeDay(number: 2, name: "Pull Base", role: .pull)
            ],
            nutritionPlan: NutritionPlan(
                dailyCalories: 2400,
                proteinGrams: 180,
                carbsGrams: 260,
                fatGrams: 70,
                mealCount: 3,
                meals: [],
                hydrationLiters: 3,
                supplements: [],
                notes: "",
                restDayCalories: 2200,
                restDayProteinGrams: 180,
                restDayCarbsGrams: 210,
                restDayFatGrams: 75
            ),
            recoveryPlan: RecoveryPlan(
                sleepHoursTarget: 8,
                restDaysPerWeek: 2,
                activities: [],
                notes: ""
            ),
            difficultyLevel: .intermediate,
            requiredEquipment: ["bodyweight"],
            estimatedDailyMinutes: 40
        )
    }

    private func makeDay(number: Int, name: String, role: SessionRole) -> ProgramDay {
        ProgramDay(
            id: "day-\(number)",
            dayNumber: number,
            label: name,
            isRestDay: false,
            workout: makeWorkout(name: name),
            sessionRole: role,
            nutritionOverride: nil,
            recoveryActivities: []
        )
    }

    private func makeWorkout(name: String) -> Workout {
        Workout(
            name: name,
            targetMuscleGroups: [.chest],
            warmup: [],
            mainExercises: [
                Exercise(
                    id: "\(name)-exercise",
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
        )
    }
}
