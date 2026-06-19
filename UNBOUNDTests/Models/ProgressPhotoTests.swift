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
        XCTAssertEqual(ProgressPhoto.Source.workout.rawValue, "workout")
    }

    func testCodableRoundtripWithWorkout() throws {
        let workout = WorkoutPhotoSummary(
            title: "Push Day",
            completedAt: Date(timeIntervalSince1970: 1_700_000_000),
            durationMinutes: 42,
            exercises: ["Bench Press · 3×5", "Incline DB · 3×10"]
        )
        let original = ProgressPhoto(
            id: "pp-w",
            userId: "u-1",
            storageUrl: "/x/p.jpg",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            source: .workout,
            workout: workout
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProgressPhoto.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.source, .workout)
        XCTAssertEqual(decoded.workout?.title, "Push Day")
        XCTAssertEqual(decoded.workout?.exercises.count, 2)
    }

    func testDecodeOldRowWithoutWorkoutField() throws {
        // A photo encoded before the field existed has no "workout" key; it must
        // still decode (workout == nil) — the migration-free guarantee.
        let legacy = ProgressPhoto(
            id: "pp-old",
            userId: "u-1",
            storageUrl: "/x/p.jpg",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            source: .manual
        )
        let data = try JSONEncoder().encode(legacy)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("workout"))
        let decoded = try JSONDecoder().decode(ProgressPhoto.self, from: data)
        XCTAssertNil(decoded.workout)
    }
}
