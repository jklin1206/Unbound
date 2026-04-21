import XCTest
@testable import UNBOUND

final class ProgramBlockStoreTests: XCTestCase {

    // In-memory mock that conforms to DatabaseServiceProtocol.
    actor MockDB: DatabaseServiceProtocol {
        var store: [String: [String: Data]] = [:]
        private let encoder = JSONEncoder()
        private let decoder = JSONDecoder()

        nonisolated func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {
            let data = try encoder.encode(object)
            await upsert(collection: collection, documentId: documentId, data: data)
        }
        nonisolated func read<T: Codable>(collection: String, documentId: String) async throws -> T {
            guard let data = await get(collection: collection, documentId: documentId) else {
                throw NSError(domain: "mock", code: 404)
            }
            return try decoder.decode(T.self, from: data)
        }
        nonisolated func update(_ fields: [String: Any], collection: String, documentId: String) async throws { /* not used */ }
        nonisolated func delete(collection: String, documentId: String) async throws {
            await remove(collection: collection, documentId: documentId)
        }
        nonisolated func query<T: Codable>(
            collection: String, field: String, isEqualTo value: Any,
            orderBy: String?, descending: Bool, limit: Int?
        ) async throws -> [T] {
            let coll = await get(collection: collection)
            var results: [T] = []
            for data in coll.values {
                if let decoded: T = try? decoder.decode(T.self, from: data),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let jsonValue = json[field],
                   "\(jsonValue)" == "\(value)" {
                    results.append(decoded)
                }
            }
            return results
        }

        func upsert(collection: String, documentId: String, data: Data) {
            store[collection, default: [:]][documentId] = data
        }
        func get(collection: String, documentId: String) -> Data? {
            store[collection]?[documentId]
        }
        func get(collection: String) -> [String: Data] {
            store[collection] ?? [:]
        }
        func remove(collection: String, documentId: String) {
            store[collection]?.removeValue(forKey: documentId)
        }
    }

    func testSaveAndReadBack() async throws {
        let db = MockDB()
        let store = ProgramBlockStore(database: db)
        let block = sampleBlock(blockNumber: 1, userId: "u-1")
        await store.save(block)
        let fetched = await store.latestBlock(userId: "u-1")
        XCTAssertEqual(fetched?.id, block.id)
        XCTAssertEqual(fetched?.blockNumber, 1)
    }

    func testLatestBlockReturnsHighestBlockNumber() async throws {
        let db = MockDB()
        let store = ProgramBlockStore(database: db)
        await store.save(sampleBlock(blockNumber: 1, userId: "u-1"))
        await store.save(sampleBlock(blockNumber: 3, userId: "u-1"))
        await store.save(sampleBlock(blockNumber: 2, userId: "u-1"))
        let latest = await store.latestBlock(userId: "u-1")
        XCTAssertEqual(latest?.blockNumber, 3)
    }

    func testLatestBlockNilWhenNoneExist() async throws {
        let db = MockDB()
        let store = ProgramBlockStore(database: db)
        let latest = await store.latestBlock(userId: "u-empty")
        XCTAssertNil(latest)
    }

    func testBlocksForUserReturnsAllSortedDescending() async throws {
        let db = MockDB()
        let store = ProgramBlockStore(database: db)
        await store.save(sampleBlock(blockNumber: 2, userId: "u-1"))
        await store.save(sampleBlock(blockNumber: 1, userId: "u-1"))
        await store.save(sampleBlock(blockNumber: 3, userId: "u-1"))
        let blocks = await store.blocks(userId: "u-1")
        XCTAssertEqual(blocks.map(\.blockNumber), [3, 2, 1])
    }

    func testBlocksForUserFiltersByUserId() async throws {
        let db = MockDB()
        let store = ProgramBlockStore(database: db)
        await store.save(sampleBlock(blockNumber: 1, userId: "u-1"))
        await store.save(sampleBlock(blockNumber: 5, userId: "u-2"))
        let u1Blocks = await store.blocks(userId: "u-1")
        XCTAssertEqual(u1Blocks.count, 1)
        XCTAssertEqual(u1Blocks.first?.userId, "u-1")
    }

    // MARK: helper

    private func sampleBlock(blockNumber: Int, userId: String) -> ProgramBlock {
        ProgramBlock(
            id: "b-\(blockNumber)-\(userId)",
            userId: userId,
            programId: "p-1",
            blockNumber: blockNumber,
            startedAt: Date(),
            scanId: nil,
            accessoryBias: [:],
            cutModeActive: false,
            biasRefreshedFromPrevious: false,
            exerciseRotationsThisBlock: []
        )
    }
}
