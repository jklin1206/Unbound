import XCTest
@testable import UNBOUND

/// Proofs for the two Category-A data-loss bugs:
///   Proof A — anonymous scans + their on-disk photo files are re-keyed to the
///             new authenticated UID on sign-in (and the old-UID location no
///             longer holds them).
///   Proof B — the migration is resumable: a mid-migration kill is recovered on
///             relaunch and `migrationCompleted` only flips true once every
///             collection has been migrated.
final class UserDataMigrationScanResumeTests: XCTestCase {

    // MARK: Proof A — scans + photos re-keyed to the authenticated UID

    func test_proofA_scans_and_photos_rekeyed_to_authenticated_uid() async throws {
        let legacyUserId = "anon-legacy"
        let supabaseUserId = UUID().uuidString
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let scans = MockScanMigrationStore()
        let photos = MockPhotoDirectoryMover()
        for i in 0..<3 {
            let id = "scan-\(i)"
            scans.checkpoints[id] = ScanCheckpoint(
                id: id,
                userId: legacyUserId,
                createdAt: now.addingTimeInterval(Double(i)),
                photoFilename: "\(id)-front.jpg",
                buildIdentitySnapshot: BuildIdentity(primary: .power, secondary: nil, shape: .specialist),
                narrative: "arc \(i)",
                deltaFromPrior: nil
            )
        }
        photos.directories[legacyUserId] = ["scan-0/front.jpg", "scan-1/front.jpg", "scan-2/front.jpg"]

        let local = MockMigrationLocalStore2()
        let sut = UserDataMigrationCoordinator(
            local: local,
            remote: MockMigrationRemoteStore2(authenticated: false),
            scanStore: scans,
            photoMover: photos,
            flagStore: MockMigrationFlagStore()
        )

        let summary = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        // All 3 scans now resolve under the NEW uid.
        let newScans = scans.checkpoints.values.filter { $0.userId == supabaseUserId }
        XCTAssertEqual(newScans.count, 3, "all 3 scans should be re-keyed to the authenticated uid")
        XCTAssertEqual(summary.scans.localWrites, 3)

        // Old-uid location no longer holds them.
        let staleScans = scans.checkpoints.values.filter { $0.userId == legacyUserId }
        XCTAssertTrue(staleScans.isEmpty, "no scan should remain keyed under the anonymous uid")

        // Photo directory has moved from old uid → new uid.
        XCTAssertNil(photos.directories[legacyUserId], "old photo directory must be gone")
        XCTAssertEqual(
            photos.directories[supabaseUserId]?.sorted(),
            ["scan-0/front.jpg", "scan-1/front.jpg", "scan-2/front.jpg"],
            "all photo files must resolve under the authenticated uid"
        )
    }

    // MARK: Proof B — resumable migration with a persisted completion flag

    func test_proofB_migration_resumes_after_midmigration_kill_and_sets_flag_only_when_complete() async throws {
        let legacyUserId = "anon-legacy"
        let supabaseUserId = UUID().uuidString
        let now = Date(timeIntervalSince1970: 1_800_000_200)

        let flags = MockMigrationFlagStore()

        // Build a store that throws on the FIRST scan write to simulate a kill
        // after the first collection (workout logs) has been migrated.
        let scans = MockScanMigrationStore()
        scans.failWritesUntilCount = 1 // first write throws, subsequent writes succeed
        scans.checkpoints["scan-0"] = ScanCheckpoint(
            id: "scan-0", userId: legacyUserId, createdAt: now,
            photoFilename: "scan-0-front.jpg",
            buildIdentitySnapshot: BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete),
            narrative: "", deltaFromPrior: nil
        )

        let local = MockMigrationLocalStore2()
        let logId = UUID().uuidString
        local.logs[logId] = WorkoutLog(
            id: logId, userId: legacyUserId, programId: UUID().uuidString,
            dayNumber: 1, plannedWorkoutName: "Push", startedAt: now, completedAt: now,
            exerciseEntries: [], overallNotes: nil, overallRPE: nil, durationMinutes: 30
        )

        let photos = MockPhotoDirectoryMover()
        photos.directories[legacyUserId] = ["scan-0/front.jpg"]

        let sut = UserDataMigrationCoordinator(
            local: local,
            remote: MockMigrationRemoteStore2(authenticated: false),
            scanStore: scans,
            photoMover: photos,
            flagStore: flags
        )

        // First run: scan write throws -> migration must NOT be marked complete.
        let first = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)
        XCTAssertGreaterThan(first.scans.failures, 0, "first run should record a scan failure")
        XCTAssertFalse(
            flags.isCompleted(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId),
            "migrationCompleted must NOT be set while a collection failed"
        )

        // Relaunch: the transient failure has cleared, migration resumes.
        let second = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)
        XCTAssertEqual(second.scans.failures, 0, "resumed run should complete the scan migration")

        // Scan + photos now resolved under the new uid.
        XCTAssertEqual(scans.checkpoints["scan-0"]?.userId, supabaseUserId)
        XCTAssertNil(photos.directories[legacyUserId])
        XCTAssertEqual(photos.directories[supabaseUserId], ["scan-0/front.jpg"])

        // Flag flips true ONLY after a fully clean run.
        XCTAssertTrue(
            flags.isCompleted(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId),
            "migrationCompleted must be set true once every collection has migrated"
        )

        // Third run is a no-op fast path because the flag is set.
        let third = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)
        XCTAssertEqual(third.scans.scanned, 0, "completed migration must short-circuit on subsequent runs")
    }
}

// MARK: - Mocks

private final class MockMigrationLocalStore2: UserDataMigrationLocalStoring, @unchecked Sendable {
    var logs: [String: WorkoutLog] = [:]
    var weights: [String: WorkingWeight] = [:]
    var progress: [String: UserSkillProgress] = [:]

    func workoutLogs(userId: String) async throws -> [WorkoutLog] { logs.values.filter { $0.userId == userId } }
    func workoutLog(id: String) async throws -> WorkoutLog? { logs[id] }
    func writeWorkoutLog(_ log: WorkoutLog, enqueueForSync: Bool) async throws { logs[log.id] = log }
    func workingWeights(userId: String) async throws -> [WorkingWeight] { weights.values.filter { $0.userId == userId } }
    func workingWeight(id: String) async throws -> WorkingWeight? { weights[id] }
    func writeWorkingWeight(_ weight: WorkingWeight) async throws { weights[weight.id] = weight }
    func skillProgress(userId: String) async throws -> UserSkillProgress? { progress[userId] }
    func writeSkillProgress(_ value: UserSkillProgress) async throws { progress[value.userId] = value }
}

private final class MockMigrationRemoteStore2: UserDataMigrationRemoteWriting, @unchecked Sendable {
    let authenticated: Bool
    init(authenticated: Bool) { self.authenticated = authenticated }
    func canWrite(as userId: String) async -> Bool { authenticated }
    func upsertWorkingWeight(_ weight: WorkingWeight) async throws {}
    func upsertSkillProgress(_ progress: UserSkillProgress) async throws {}
}

private final class MockScanMigrationStore: UserDataMigrationScanStoring, @unchecked Sendable {
    var checkpoints: [String: ScanCheckpoint] = [:]
    /// When > 0, the next `failWritesUntilCount` write calls throw, then succeed.
    var failWritesUntilCount = 0
    private var writeCallCount = 0

    struct WriteError: Error {}

    func scanCheckpoints(userId: String) async throws -> [ScanCheckpoint] {
        checkpoints.values.filter { $0.userId == userId }
    }

    func writeScanCheckpoint(_ checkpoint: ScanCheckpoint) async throws {
        writeCallCount += 1
        if writeCallCount <= failWritesUntilCount {
            throw WriteError()
        }
        checkpoints[checkpoint.id] = checkpoint
    }
}

private final class MockPhotoDirectoryMover: UserDataMigrationPhotoMoving, @unchecked Sendable {
    /// userId -> relative photo file paths.
    var directories: [String: [String]] = [:]

    func movePhotoDirectory(from legacyUserId: String, to supabaseUserId: String) async throws {
        guard let files = directories[legacyUserId] else { return }
        directories[supabaseUserId] = (directories[supabaseUserId] ?? []) + files
        directories[legacyUserId] = nil
    }
}

private final class MockMigrationFlagStore: UserDataMigrationFlagStoring, @unchecked Sendable {
    private var completed: Set<String> = []
    private func key(_ a: String, _ b: String) -> String { "\(a)->\(b)" }
    func isCompleted(legacyUserId: String, supabaseUserId: String) -> Bool {
        completed.contains(key(legacyUserId, supabaseUserId))
    }
    func markCompleted(legacyUserId: String, supabaseUserId: String) {
        completed.insert(key(legacyUserId, supabaseUserId))
    }
}
