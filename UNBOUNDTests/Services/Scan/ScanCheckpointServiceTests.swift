// UNBOUNDTests/Services/ScanCheckpointServiceTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class ScanCheckpointServiceTests: XCTestCase {

    private var tmpDir: URL!
    private var store: ScanCheckpointStore!
    private var attribute: MockAttributeService!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        store = ScanCheckpointStore(directory: tmpDir)
        attribute = MockAttributeService()
    }
    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    func testFirstCommitProducesNoDelta() async throws {
        var profile = AttributeProfile.empty(userId: "u-1", at: .now)
        profile.set(.power, AttributeValue(xp: AttributeLevelCurve.xpRequired(forLevel: 53), lastContributionAt: .now))
        attribute.profileByUser["u-1"] = profile

        let service = ScanCheckpointService(
            store: store,
            attribute: attribute,
            photoWriter: StubPhotoWriter(),
            narrative: { _ in "first arc narrative" },
            evolutionNarrative: { _, _, _ in "should not be called" }
        )
        let checkpoint = try await service.commit(
            userId: "u-1",
            photoData: Data([0xFF, 0xD8]),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertTrue(checkpoint.isFirstScan)
        XCTAssertNil(checkpoint.deltaFromPrior)
        XCTAssertEqual(checkpoint.narrative, "first arc narrative")
    }

    func testSecondCommitProducesPositiveDelta() async throws {
        // First scan: power=50.
        var first = AttributeProfile.empty(userId: "u-1", at: .now)
        first.set(.power, AttributeValue(xp: AttributeLevelCurve.xpRequired(forLevel: 50), lastContributionAt: .now))
        attribute.profileByUser["u-1"] = first

        let service = ScanCheckpointService(
            store: store, attribute: attribute, photoWriter: StubPhotoWriter(),
            narrative: { _ in "n1" },
            evolutionNarrative: { _, _, _ in "n2-evolution" }
        )
        _ = try await service.commit(
            userId: "u-1", photoData: Data([0xFF]),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        // Second scan: power=62.
        var second = AttributeProfile.empty(userId: "u-1", at: .now)
        second.set(.power, AttributeValue(xp: AttributeLevelCurve.xpRequired(forLevel: 62), lastContributionAt: .now))
        attribute.profileByUser["u-1"] = second

        let cp = try await service.commit(
            userId: "u-1", photoData: Data([0xFF]),
            now: Date(timeIntervalSince1970: 1_702_592_000)
        )
        XCTAssertFalse(cp.isFirstScan)
        XCTAssertEqual(cp.deltaFromPrior?.positiveDeltas[.power], 12)
        XCTAssertEqual(cp.narrative, "n2-evolution")
    }

    func testCommitPersistsCheckpoint() async throws {
        var profile = AttributeProfile.empty(userId: "u-1", at: .now)
        profile.set(.power, AttributeValue(xp: AttributeLevelCurve.xpRequired(forLevel: 50), lastContributionAt: .now))
        attribute.profileByUser["u-1"] = profile

        let writer = StubPhotoWriter()
        let service = ScanCheckpointService(
            store: store, attribute: attribute, photoWriter: writer,
            narrative: { _ in "n" },
            evolutionNarrative: { _, _, _ in "n2" }
        )
        let cp = try await service.commit(
            userId: "u-1", photoData: Data([0xFF, 0xD8, 0xFF]),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertEqual(writer.written.count, 1)
        XCTAssertEqual(writer.written.first?.filename, cp.photoFilename)
        let reloaded = try store.load(id: cp.id)
        XCTAssertEqual(reloaded, cp)
    }
}

private final class StubPhotoWriter: ScanPhotoWriting {
    var written: [(filename: String, data: Data)] = []
    func write(_ data: Data, filename: String) throws {
        written.append((filename, data))
    }
}
