// UNBOUNDTests/Models/ScanCheckpointTests.swift
import XCTest
@testable import UNBOUND

final class ScanCheckpointTests: XCTestCase {
    func testCodableRoundtripFirstCheckpoint() throws {
        let identity = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        let checkpoint = ScanCheckpoint(
            id: "scan-1",
            userId: "u-1",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            photoFilename: "scan-1-front.jpg",
            buildIdentitySnapshot: identity,
            narrative: "Your arc begins.",
            deltaFromPrior: nil
        )
        let data = try JSONEncoder().encode(checkpoint)
        let decoded = try JSONDecoder().decode(ScanCheckpoint.self, from: data)
        XCTAssertEqual(decoded, checkpoint)
    }

    func testCodableRoundtripWithDelta() throws {
        let identity = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        let delta = BuildIdentityDelta(perAxis: [.power: 12, .agility: -2])
        let checkpoint = ScanCheckpoint(
            id: "scan-2",
            userId: "u-1",
            createdAt: Date(timeIntervalSince1970: 1_702_592_000),
            photoFilename: "scan-2-front.jpg",
            buildIdentitySnapshot: identity,
            narrative: "Your Power grew +12.",
            deltaFromPrior: delta
        )
        let data = try JSONEncoder().encode(checkpoint)
        let decoded = try JSONDecoder().decode(ScanCheckpoint.self, from: data)
        XCTAssertEqual(decoded, checkpoint)
        XCTAssertEqual(decoded.deltaFromPrior?.positiveDeltas[.power], 12)
    }

    func testIsFirstScan() {
        let identity = BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete)
        let first = ScanCheckpoint(
            id: "s1", userId: "u-1", createdAt: .now,
            photoFilename: "p.jpg", buildIdentitySnapshot: identity,
            narrative: "", deltaFromPrior: nil
        )
        XCTAssertTrue(first.isFirstScan)
    }
}
