import XCTest
@testable import UNBOUND

final class WorkoutPhotoSummaryTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func log(blocks: [PerformanceBlock], minutes: Double = 42) -> PerformanceLog {
        PerformanceLog(
            id: "log-1",
            userId: "u-1",
            source: .program,
            title: "Push Day",
            startedAt: start,
            completedAt: start.addingTimeInterval(minutes * 60),
            blocks: blocks
        )
    }

    func testBuildsTitleAndDuration() {
        let summary = WorkoutPhotoSummary(performanceLog: log(blocks: [
            PerformanceBlock(kind: .strength, title: "Main", exercises: [
                PerformanceExercise(name: "Bench Press", plannedSets: 3, plannedTarget: "5", sets: [
                    PerformanceSet(setNumber: 1, reps: 5),
                    PerformanceSet(setNumber: 2, reps: 5),
                    PerformanceSet(setNumber: 3, reps: 5),
                ])
            ])
        ]))
        XCTAssertEqual(summary.title, "Push Day")
        XCTAssertEqual(summary.durationMinutes, 42)
    }

    func testUniformRepsLine() {
        let summary = WorkoutPhotoSummary(performanceLog: log(blocks: [
            PerformanceBlock(kind: .strength, title: "Main", exercises: [
                PerformanceExercise(name: "Bench Press", plannedSets: 3, plannedTarget: "5", sets: [
                    PerformanceSet(setNumber: 1, reps: 5),
                    PerformanceSet(setNumber: 2, reps: 5),
                    PerformanceSet(setNumber: 3, reps: 5),
                ])
            ])
        ]))
        XCTAssertEqual(summary.exercises, ["Bench Press · 3×5"])
    }

    func testSkipsSkippedExercises() {
        let summary = WorkoutPhotoSummary(performanceLog: log(blocks: [
            PerformanceBlock(kind: .strength, title: "Main", exercises: [
                PerformanceExercise(name: "Bench Press", plannedSets: 1, plannedTarget: "5", sets: [
                    PerformanceSet(setNumber: 1, reps: 5),
                ]),
                PerformanceExercise(name: "Skipped Fly", plannedSets: 3, plannedTarget: "10", sets: [], skipped: true),
            ])
        ]))
        XCTAssertEqual(summary.exercises.count, 1)
        XCTAssertFalse(summary.exercises.contains { $0.contains("Skipped Fly") })
    }

    func testWarmupSetsExcludedFromCount() {
        let summary = WorkoutPhotoSummary(performanceLog: log(blocks: [
            PerformanceBlock(kind: .strength, title: "Main", exercises: [
                PerformanceExercise(name: "Squat", plannedSets: 2, plannedTarget: "5", sets: [
                    PerformanceSet(setNumber: 1, reps: 10, isWarmup: true),
                    PerformanceSet(setNumber: 2, reps: 5),
                    PerformanceSet(setNumber: 3, reps: 5),
                ])
            ])
        ]))
        XCTAssertEqual(summary.exercises, ["Squat · 2×5"])
    }

    func testMixedRepsFallBackToSetCount() {
        let summary = WorkoutPhotoSummary(performanceLog: log(blocks: [
            PerformanceBlock(kind: .strength, title: "Main", exercises: [
                PerformanceExercise(name: "Row", plannedSets: 2, plannedTarget: "x", sets: [
                    PerformanceSet(setNumber: 1, reps: 8),
                    PerformanceSet(setNumber: 2, reps: 6),
                ])
            ])
        ]))
        XCTAssertEqual(summary.exercises, ["Row · 2 sets"])
    }

    func testUniformHoldLine() {
        let summary = WorkoutPhotoSummary(performanceLog: log(blocks: [
            PerformanceBlock(kind: .skill, title: "Hold", exercises: [
                PerformanceExercise(name: "Plank", plannedSets: 2, plannedTarget: "45s", sets: [
                    PerformanceSet(setNumber: 1, holdSeconds: 45),
                    PerformanceSet(setNumber: 2, holdSeconds: 45),
                ])
            ])
        ]))
        XCTAssertEqual(summary.exercises, ["Plank · 2×45s"])
    }

    func testCardioBlockWithoutExercisesShowsDuration() {
        let summary = WorkoutPhotoSummary(performanceLog: log(blocks: [
            PerformanceBlock(kind: .cardio, title: "Zone 2 Run", exercises: [], durationSeconds: 1200)
        ]))
        XCTAssertEqual(summary.exercises, ["Zone 2 Run · 20 min"])
    }
}
