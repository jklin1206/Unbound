import XCTest
@testable import UNBOUND

final class SquadV1ModelsTests: XCTestCase {
    func testAccountabilityBadgeTierThresholds() {
        let userId = UUID()
        XCTAssertEqual(AccountabilityBadgeState(userId: userId, clearedCount: 0).currentTier, .none)
        XCTAssertEqual(AccountabilityBadgeState(userId: userId, clearedCount: 1).currentTier, .one)
        XCTAssertEqual(AccountabilityBadgeState(userId: userId, clearedCount: 5).currentTier, .two)
        XCTAssertEqual(AccountabilityBadgeState(userId: userId, clearedCount: 25).currentTier, .three)
    }

    func testCrewStreakBadgeTierThresholds() {
        let squadId = UUID()
        XCTAssertEqual(CrewStreakBadgeState(squadId: squadId, consecutiveWeeks: 4, weekIsoLast: nil).currentTier, .none)
        XCTAssertEqual(CrewStreakBadgeState(squadId: squadId, consecutiveWeeks: 5, weekIsoLast: nil).currentTier, .one)
        XCTAssertEqual(CrewStreakBadgeState(squadId: squadId, consecutiveWeeks: 12, weekIsoLast: nil).currentTier, .two)
        XCTAssertEqual(CrewStreakBadgeState(squadId: squadId, consecutiveWeeks: 26, weekIsoLast: nil).currentTier, .three)
    }

    func testSquadMessageRoundtrip() throws {
        let message = SquadMessage(
            id: UUID(),
            squadId: UUID(),
            authorUserId: UUID(),
            kind: .challengeEvent(.init(title: "Pushups in 60s", detail: "Sam submitted 44", challengeId: UUID())),
            reactions: [
                SquadMessageReaction(
                    id: UUID(),
                    messageId: UUID(),
                    userId: UUID(),
                    emoji: .fire,
                    createdAt: Date()
                )
            ],
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(SquadMessage.self, from: data)
        XCTAssertEqual(decoded, message)
    }

    func testSquadMessageStoragePayloadRoundtripsEveryKind() {
        let challengeId = UUID()
        let shareId = UUID()
        let authorId = UUID()
        let cases: [SquadMessage.Kind] = [
            .text(.init(body: "Still moving.")),
            .workout(.init(title: "Upper Body Power", durationMinutes: 44)),
            .pr(.init(title: "PR", detail: "Bench +10 lb")),
            .vowSeal(.init(title: "Limit Break")),
            .challengeEvent(.init(title: "Crew streak extended", detail: "6 weeks", challengeId: challengeId)),
            .savedWorkoutShare(.init(shareId: shareId, workoutTitle: "Hotel Full Body", sharedById: authorId)),
            .system(.init(body: "Crewmate joined the crew."))
        ]

        for kind in cases {
            let storageKind = SquadMessageStorageCoder.storageKind(for: kind)
            let payload = SquadMessageStorageCoder.payload(for: kind)
            XCTAssertEqual(
                SquadMessageStorageCoder.messageKind(storageKind: storageKind, payload: payload),
                kind
            )
        }
    }

    func testSquadMessageMergeDedupePrefersRemoteAndSortsNewestFirst() {
        let squadId = UUID()
        let authorId = UUID()
        let messageId = UUID()
        let oldDate = Date(timeIntervalSince1970: 10)
        let newDate = Date(timeIntervalSince1970: 20)
        let fallback = SquadMessage(
            id: messageId,
            squadId: squadId,
            authorUserId: authorId,
            kind: .text(.init(body: "pending")),
            reactions: [],
            createdAt: oldDate
        )
        let remote = SquadMessage(
            id: messageId,
            squadId: squadId,
            authorUserId: authorId,
            kind: .text(.init(body: "persisted")),
            reactions: [
                SquadMessageReaction(id: UUID(), messageId: messageId, userId: authorId, emoji: .fire, createdAt: newDate)
            ],
            createdAt: oldDate
        )
        let newest = SquadMessage(
            id: UUID(),
            squadId: squadId,
            authorUserId: nil,
            kind: .system(.init(body: "Crew streak extended.")),
            reactions: [],
            createdAt: newDate
        )

        let merged = SquadMessageService.mergedMessages([remote], [fallback, newest])
        XCTAssertEqual(merged.map(\.id), [newest.id, messageId])
        XCTAssertEqual(merged.last?.kind, .text(.init(body: "persisted")))
        XCTAssertEqual(merged.last?.reactions.first?.emoji, .fire)
    }
}

private final class MockSquadMessageBackend: SquadMessageBackendProtocol {
    var fetchedMessages: [SquadMessage] = []
    var fetchError: Error?
    var insertError: Error?
    var insertedMessages: [SquadMessage] = []
    var clientMessageIds: [String?] = []
    var addedReactions: [SquadMessageReaction] = []
    var deletedReactions: [(UUID, UUID, SquadMessageReaction.Emoji)] = []
    var reports: [(UUID, UUID, String, String?)] = []

    func fetchRecentMessages(squadId: UUID, limit: Int) async throws -> [SquadMessage] {
        if let fetchError { throw fetchError }
        return Array(fetchedMessages.prefix(limit))
    }

    func insertMessage(_ message: SquadMessage, clientMessageId: String?) async throws -> SquadMessage {
        if let insertError { throw insertError }
        insertedMessages.append(message)
        clientMessageIds.append(clientMessageId)
        return message
    }

    func addReaction(_ reaction: SquadMessageReaction, squadId: UUID) async throws -> SquadMessageReaction {
        addedReactions.append(reaction)
        return reaction
    }

    func deleteReaction(messageId: UUID, userId: UUID, emoji: SquadMessageReaction.Emoji) async throws {
        deletedReactions.append((messageId, userId, emoji))
    }

    func reportMessage(messageId: UUID, reporterUserId: UUID, reason: String, detail: String?) async throws {
        reports.append((messageId, reporterUserId, reason, detail))
    }
}

private enum SquadMessageTestError: Error {
    case forced
}

@MainActor
final class SquadMessageServiceTests: XCTestCase {
    func testFetchRecentMergesRemoteMessagesWithActivityFallback() async {
        let squadId = UUID()
        let backend = MockSquadMessageBackend()
        let remote = SquadMessage(
            id: UUID(),
            squadId: squadId,
            authorUserId: UUID(),
            kind: .text(.init(body: "Remote chat")),
            reactions: [],
            createdAt: Date(timeIntervalSince1970: 30)
        )
        let activityFallback = SquadMessage(
            id: UUID(),
            squadId: squadId,
            authorUserId: nil,
            kind: .challengeEvent(.init(title: "Crew streak extended", detail: "6 weeks", challengeId: nil)),
            reactions: [],
            createdAt: Date(timeIntervalSince1970: 20)
        )
        backend.fetchedMessages = [remote]

        let service = SquadMessageService(backend: backend)
        let result = await service.fetchRecent(squadId: squadId, fallbackMessages: [activityFallback])

        XCTAssertEqual(result.map(\.id), [remote.id, activityFallback.id])
    }

    func testSendPersistsMessageWithClientDedupeId() async {
        let backend = MockSquadMessageBackend()
        let service = SquadMessageService(backend: backend)
        let saved = await service.sendText(squadId: UUID(), authorUserId: UUID(), body: "  Progress check  ")

        XCTAssertEqual(backend.insertedMessages, [saved])
        XCTAssertEqual(backend.clientMessageIds, [saved.id.uuidString])
        XCTAssertEqual(saved.kind, .text(.init(body: "Progress check")))
    }

    func testSendFallsBackLocallyWhenBackendFails() async {
        let squadId = UUID()
        let backend = MockSquadMessageBackend()
        backend.insertError = SquadMessageTestError.forced
        backend.fetchError = SquadMessageTestError.forced
        let service = SquadMessageService(backend: backend)

        let saved = await service.sendText(squadId: squadId, authorUserId: UUID(), body: "Offline rep")
        let result = await service.fetchRecent(squadId: squadId, fallbackMessages: [])

        XCTAssertEqual(result, [saved])
    }

    func testSetReactionAddsAndRemovesBackendReaction() async {
        let backend = MockSquadMessageBackend()
        let service = SquadMessageService(backend: backend)
        let messageId = UUID()
        let userId = UUID()

        await service.setReaction(emoji: .fire, messageId: messageId, squadId: UUID(), userId: userId, shouldAdd: true)
        await service.setReaction(emoji: .fire, messageId: messageId, squadId: UUID(), userId: userId, shouldAdd: false)

        XCTAssertEqual(backend.addedReactions.first?.messageId, messageId)
        XCTAssertEqual(backend.addedReactions.first?.userId, userId)
        XCTAssertEqual(backend.addedReactions.first?.emoji, .fire)
        XCTAssertEqual(backend.deletedReactions.count, 1)
        XCTAssertEqual(backend.deletedReactions.first?.0, messageId)
        XCTAssertEqual(backend.deletedReactions.first?.1, userId)
        XCTAssertEqual(backend.deletedReactions.first?.2, .fire)
    }

    func testReportMessageWritesReportOnlyWhenReporterExists() async {
        let backend = MockSquadMessageBackend()
        let service = SquadMessageService(backend: backend)
        let messageId = UUID()
        let reporterId = UUID()

        await service.report(messageId: messageId, reporterUserId: nil)
        await service.report(messageId: messageId, reporterUserId: reporterId, reason: "spam", detail: "Repeated")

        XCTAssertEqual(backend.reports.count, 1)
        XCTAssertEqual(backend.reports.first?.0, messageId)
        XCTAssertEqual(backend.reports.first?.1, reporterId)
        XCTAssertEqual(backend.reports.first?.2, "spam")
        XCTAssertEqual(backend.reports.first?.3, "Repeated")
    }
}
