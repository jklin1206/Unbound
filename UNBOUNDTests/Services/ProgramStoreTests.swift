import XCTest
@testable import UNBOUND

@MainActor
final class ProgramStoreTests: XCTestCase {

    private func makeProgram(id: String = "p-1", userId: String = "u-1") -> TrainingProgram {
        TrainingProgram(
            id: id, scanId: "s-1", analysisId: "a-1", userId: userId,
            createdAt: Date(), name: "Test", description: "Test program",
            durationDays: 14, days: [],
            nutritionPlan: NutritionPlan(
                dailyCalories: 2000, proteinGrams: 150, carbsGrams: 200, fatGrams: 60,
                mealCount: 4, meals: [], hydrationLiters: 3, supplements: [], notes: "",
                restDayCalories: 1800, restDayProteinGrams: 150,
                restDayCarbsGrams: 150, restDayFatGrams: 60),
            recoveryPlan: RecoveryPlan(sleepHoursTarget: 8, restDaysPerWeek: 3,
                                       activities: [], notes: ""),
            difficultyLevel: .intermediate, requiredEquipment: [],
            estimatedDailyMinutes: 45, rationale: nil)
    }

    private final class MockProgramRemote: ProgramRemote, @unchecked Sendable {
        var programsById: [String: TrainingProgram] = [:]
        private(set) var fetchCalls = 0
        func persist(_ program: TrainingProgram, userId: String) async -> Bool { true }
        func fetchProgram(id: String) async throws -> TrainingProgram {
            fetchCalls += 1
            guard let p = programsById[id] else { throw NSError(domain: "mock", code: 404) }
            return p
        }
    }

    private func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func test_save_thenLoadLocal_survivesNewInstance() async {
        let dir = tempDir(); let remote = MockProgramRemote()
        let ob = OutboxStore(directory: tempDir())
        let s1 = ProgramStore(directory: dir, remote: remote, outbox: ob)
        await s1.save(makeProgram(), userId: "u-1")
        let s2 = ProgramStore(directory: dir, remote: remote, outbox: ob)
        XCTAssertEqual(s2.loadLocal(userId: "u-1")?.id, "p-1")
    }

    func test_save_enqueues_program_and_user_upsert() async {
        let dir = tempDir(); let remote = MockProgramRemote()
        let ob = OutboxStore(directory: tempDir())
        let s = ProgramStore(directory: dir, remote: remote, outbox: ob)
        await s.save(makeProgram(id: "p-9"), userId: "u-1")
        let q = ob.peekBatch(limit: 10)
        XCTAssertTrue(q.contains { $0.collection == "programs" && $0.docId == "p-9" && $0.op == .upsert })
        XCTAssertTrue(q.contains { $0.collection == "users" && $0.docId == "u-1" })
    }

    func test_save_localStillReads_beforeFlush() async {
        let dir = tempDir(); let remote = MockProgramRemote()
        let ob = OutboxStore(directory: tempDir())
        let s = ProgramStore(directory: dir, remote: remote, outbox: ob)
        await s.save(makeProgram(), userId: "u-1")
        XCTAssertEqual(ProgramStore(directory: dir, remote: remote, outbox: ob)
            .loadLocal(userId: "u-1")?.id, "p-1")
    }

    func test_revalidate_sameId_isNoOp_localWins() async {
        let dir = tempDir(); let remote = MockProgramRemote()
        let ob = OutboxStore(directory: tempDir())
        let s = ProgramStore(directory: dir, remote: remote, outbox: ob)
        await s.save(makeProgram(), userId: "u-1")
        await s.revalidate(userId: "u-1", expectedProgramId: "p-1")
        XCTAssertEqual(remote.fetchCalls, 0)
        XCTAssertEqual(s.program?.id, "p-1")
    }

    func test_revalidate_newId_fetchesAndReplaces() async {
        let dir = tempDir(); let remote = MockProgramRemote()
        let ob = OutboxStore(directory: tempDir())
        remote.programsById["p-2"] = makeProgram(id: "p-2")
        let s = ProgramStore(directory: dir, remote: remote, outbox: ob)
        await s.save(makeProgram(id: "p-1"), userId: "u-1")
        await s.revalidate(userId: "u-1", expectedProgramId: "p-2")
        XCTAssertEqual(remote.fetchCalls, 1)
        XCTAssertEqual(s.program?.id, "p-2")
        XCTAssertEqual(ProgramStore(directory: dir, remote: remote, outbox: ob)
            .loadLocal(userId: "u-1")?.id, "p-2")
    }

    func test_loadLocal_wrongUser_nil_andClearWipes() async {
        let dir = tempDir(); let remote = MockProgramRemote()
        let ob = OutboxStore(directory: tempDir())
        let s = ProgramStore(directory: dir, remote: remote, outbox: ob)
        await s.save(makeProgram(userId: "u-1"), userId: "u-1")
        XCTAssertNil(s.loadLocal(userId: "u-2"))
        s.clear()
        XCTAssertNil(ProgramStore(directory: dir, remote: remote, outbox: ob).loadLocal(userId: "u-1"))
    }

    func test_adopt_doesNotEnqueue() async {
        let dir = tempDir(); let remote = MockProgramRemote()
        let ob = OutboxStore(directory: tempDir())
        let s = ProgramStore(directory: dir, remote: remote, outbox: ob)
        s.adopt(makeProgram(), userId: "u-1")
        XCTAssertEqual(ob.pendingCount, 0)
        XCTAssertEqual(s.program?.id, "p-1")
    }
}
