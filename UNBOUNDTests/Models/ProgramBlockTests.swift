import XCTest
@testable import UNBOUND

final class ProgramBlockTests: XCTestCase {
    func testBasicConstruction() {
        let block = ProgramBlock(
            id: "b-1",
            userId: "u-1",
            programId: "p-1",
            blockNumber: 3,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            scanId: "s-42"
        )
        XCTAssertEqual(block.blockNumber, 3)
        XCTAssertNil(block.endedAt)
        XCTAssertTrue(block.accessoryBias.isEmpty)
        XCTAssertFalse(block.cutModeActive)
        XCTAssertFalse(block.biasRefreshedFromPrevious)
        XCTAssertTrue(block.exerciseRotationsThisBlock.isEmpty)
    }

    func testFullConstruction() {
        let block = ProgramBlock(
            id: "b-1",
            userId: "u-1",
            programId: "p-1",
            blockNumber: 3,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: nil,
            scanId: "s-42",
            accessoryBias: [.shoulders: 2, .back: 1],
            cutModeActive: true,
            biasRefreshedFromPrevious: true,
            exerciseRotationsThisBlock: ["barbell_row"]
        )
        XCTAssertEqual(block.accessoryBias[.shoulders], 2)
        XCTAssertEqual(block.accessoryBias[.back], 1)
        XCTAssertTrue(block.cutModeActive)
        XCTAssertTrue(block.biasRefreshedFromPrevious)
        XCTAssertEqual(block.exerciseRotationsThisBlock, ["barbell_row"])
    }

    func testCodableRoundtrip() throws {
        let original = ProgramBlock(
            id: "b-1",
            userId: "u-1",
            programId: "p-1",
            blockNumber: 3,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_701_000_000),
            scanId: "s-42",
            accessoryBias: [.shoulders: 2, .back: 1],
            cutModeActive: true,
            biasRefreshedFromPrevious: true,
            exerciseRotationsThisBlock: ["barbell_row", "pulldown"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProgramBlock.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
