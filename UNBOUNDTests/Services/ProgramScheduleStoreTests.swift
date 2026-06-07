import XCTest
@testable import UNBOUND

@MainActor
final class ProgramScheduleStoreTests: XCTestCase {
    func testReplacePrimaryStoresOneExactDateOccurrenceWithoutExtras() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("program-schedule-\(UUID().uuidString)", isDirectory: true)
        let store = ProgramScheduleStore(directory: directory)
        let date = Date(timeIntervalSince1970: 1_780_000_000)
        let first = ProgramScheduleOccurrence(
            userId: "u1",
            programId: "p1",
            date: date,
            kind: .saved,
            title: "Push A",
            savedWorkoutId: UUID()
        )
        let replacement = ProgramScheduleOccurrence(
            userId: "u1",
            programId: "p1",
            date: date,
            kind: .built,
            title: "Built Push",
            draft: TrainingSessionDraft(
                userId: "u1",
                source: .custom,
                title: "Built Push",
                estimatedMinutes: 20,
                blocks: []
            )
        )
        let extra = ProgramScheduleOccurrence(
            userId: "u1",
            programId: "p1",
            date: date,
            kind: .extra,
            title: "Extra Session"
        )

        store.replacePrimary(on: date, userId: "u1", programId: "p1", with: first)
        store.upsert(extra)
        store.replacePrimary(on: date, userId: "u1", programId: "p1", with: replacement)

        let sameDay = store.occurrences(on: date, userId: "u1", programId: "p1")
        XCTAssertEqual(sameDay.count, 2)
        XCTAssertEqual(store.primaryOccurrence(on: date, userId: "u1", programId: "p1")?.title, "Built Push")
        XCTAssertEqual(sameDay.filter(\.isExtraSession).count, 1)
    }
}
