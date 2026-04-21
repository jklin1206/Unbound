import XCTest
@testable import UNBOUND

final class ProgressPhotoTests: XCTestCase {
    func testBasicConstruction() {
        let p = ProgressPhoto(
            id: "pp-1",
            userId: "u-1",
            storageUrl: "https://x.y/p.jpg",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            source: .manual
        )
        XCTAssertEqual(p.id, "pp-1")
        XCTAssertNil(p.note)
        XCTAssertNil(p.angle)
        XCTAssertNil(p.blockNumber)
        XCTAssertEqual(p.source, .manual)
    }

    func testFullConstruction() {
        let p = ProgressPhoto(
            id: "pp-1",
            userId: "u-1",
            storageUrl: "https://x.y/p.jpg",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            note: "after workout",
            angle: .front,
            blockNumber: 3,
            source: .scan
        )
        XCTAssertEqual(p.note, "after workout")
        XCTAssertEqual(p.angle, .front)
        XCTAssertEqual(p.blockNumber, 3)
        XCTAssertEqual(p.source, .scan)
    }

    func testCodableRoundtrip() throws {
        let original = ProgressPhoto(
            id: "pp-1",
            userId: "u-1",
            storageUrl: "https://x.y/p.jpg",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            note: "after workout",
            angle: .front,
            blockNumber: 3,
            source: .manual
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProgressPhoto.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testSourceCodableRawValue() throws {
        XCTAssertEqual(ProgressPhoto.Source.manual.rawValue, "manual")
        XCTAssertEqual(ProgressPhoto.Source.scan.rawValue, "scan")
    }
}
