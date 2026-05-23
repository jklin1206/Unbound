import XCTest
@testable import UNBOUND

final class DayTemplateTests: XCTestCase {
    func testRestDayFlag() {
        XCTAssertTrue(DayTemplate.rest.isRest)
        XCTAssertFalse(DayTemplate.push.isRest)
        XCTAssertFalse(DayTemplate.weakPoint.isRest)
    }

    func testMuscleGroupsPerTemplate() {
        XCTAssertTrue(DayTemplate.push.muscleGroups.contains(.chest))
        XCTAssertTrue(DayTemplate.push.muscleGroups.contains(.shoulders))
        XCTAssertTrue(DayTemplate.pull.muscleGroups.contains(.back))
        XCTAssertTrue(DayTemplate.pull.muscleGroups.contains(.lats))
        XCTAssertTrue(DayTemplate.legs.muscleGroups.contains(.legs))
        XCTAssertTrue(DayTemplate.legs.muscleGroups.contains(.glutes))
        XCTAssertTrue(DayTemplate.upper.muscleGroups.contains(.back))
        XCTAssertTrue(DayTemplate.upper.muscleGroups.contains(.chest))
        XCTAssertTrue(DayTemplate.lower.muscleGroups.contains(.legs))
        XCTAssertTrue(DayTemplate.fullBody.muscleGroups.contains(.chest))
        XCTAssertTrue(DayTemplate.fullBody.muscleGroups.contains(.legs))
        XCTAssertEqual(DayTemplate.rest.muscleGroups, [])
        XCTAssertEqual(DayTemplate.weakPoint.muscleGroups, [])
    }

    func testAllCasesHaveDisplayLabel() {
        for t in DayTemplate.allCases {
            XCTAssertFalse(t.displayLabel.isEmpty)
        }
    }

    func testCodableRoundtrip() throws {
        let original: DayTemplate = .push
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DayTemplate.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
