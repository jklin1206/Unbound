// UNBOUNDTests/Services/ScanCheckpointStoreTests.swift
import XCTest
@testable import UNBOUND

final class ScanCheckpointStoreTests: XCTestCase {
    private var tmpDir: URL!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }
    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    func testSaveAndLoadRoundtrip() throws {
        let store = ScanCheckpointStore(directory: tmpDir)
        let identity = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        let checkpoint = ScanCheckpoint(
            id: "s1", userId: "u-1", createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            photoFilename: "s1-front.jpg", buildIdentitySnapshot: identity,
            narrative: "Your arc begins.", deltaFromPrior: nil
        )
        try store.save(checkpoint)
        let loaded = try store.load(id: "s1")
        XCTAssertEqual(loaded, checkpoint)
    }

    func testHistoryOrderedNewestLast() throws {
        let store = ScanCheckpointStore(directory: tmpDir)
        let identity = BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete)
        let older = ScanCheckpoint(
            id: "s1", userId: "u-1", createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            photoFilename: "a.jpg", buildIdentitySnapshot: identity,
            narrative: "", deltaFromPrior: nil
        )
        let newer = ScanCheckpoint(
            id: "s2", userId: "u-1", createdAt: Date(timeIntervalSince1970: 1_702_000_000),
            photoFilename: "b.jpg", buildIdentitySnapshot: identity,
            narrative: "", deltaFromPrior: nil
        )
        try store.save(older)
        try store.save(newer)
        let history = try store.history(userId: "u-1")
        XCTAssertEqual(history.map(\.id), ["s1", "s2"])
    }

    func testMostRecentReturnsNewest() throws {
        let store = ScanCheckpointStore(directory: tmpDir)
        let identity = BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete)
        let older = ScanCheckpoint(
            id: "s1", userId: "u-1", createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            photoFilename: "a.jpg", buildIdentitySnapshot: identity,
            narrative: "", deltaFromPrior: nil
        )
        let newer = ScanCheckpoint(
            id: "s2", userId: "u-1", createdAt: Date(timeIntervalSince1970: 1_702_000_000),
            photoFilename: "b.jpg", buildIdentitySnapshot: identity,
            narrative: "", deltaFromPrior: nil
        )
        try store.save(older)
        try store.save(newer)
        XCTAssertEqual(try store.mostRecent(userId: "u-1")?.id, "s2")
    }

    func testMostRecentNilWhenEmpty() throws {
        let store = ScanCheckpointStore(directory: tmpDir)
        XCTAssertNil(try store.mostRecent(userId: "u-1"))
    }
}
