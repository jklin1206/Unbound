import Foundation

protocol CardioLogServiceProtocol: Sendable {
    func log(session: CardioSession) async throws
    func all(userId: String) async -> [CardioSession]
    func recent(userId: String, days: Int) async -> [CardioSession]
    func delete(id: UUID) async throws
}

final class CardioLogService: CardioLogServiceProtocol, @unchecked Sendable {
    static let shared = CardioLogService()
    private let database = DatabaseService.shared
    private let logger = LoggingService.shared

    private init() {}

    func log(session: CardioSession) async throws {
        try await database.create(
            session,
            collection: "cardio_sessions",
            documentId: session.id.uuidString
        )
        logger.log(
            "Cardio logged: \(session.type.displayName) \(session.durationMinutes)m",
            level: .info
        )
    }

    func all(userId: String) async -> [CardioSession] {
        do {
            let sessions: [CardioSession] = try await database.query(
                collection: "cardio_sessions",
                field: "userId",
                isEqualTo: userId,
                orderBy: "date",
                descending: true,
                limit: nil
            )
            return sessions
        } catch {
            logger.log("CardioLogService all failed: \(error)", level: .warning)
            return []
        }
    }

    func recent(userId: String, days: Int) async -> [CardioSession] {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -days,
            to: Date()
        ) ?? Date()
        return await all(userId: userId).filter { $0.date >= cutoff }
    }

    func delete(id: UUID) async throws {
        try await database.delete(
            collection: "cardio_sessions",
            documentId: id.uuidString
        )
    }
}

final class MockCardioLogService: CardioLogServiceProtocol, @unchecked Sendable {
    var sessions: [CardioSession] = []

    func log(session: CardioSession) async throws {
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
    }

    func all(userId: String) async -> [CardioSession] {
        sessions.filter { $0.userId == userId }.sorted { $0.date > $1.date }
    }

    func recent(userId: String, days: Int) async -> [CardioSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return await all(userId: userId).filter { $0.date >= cutoff }
    }

    func delete(id: UUID) async throws {
        sessions.removeAll { $0.id == id }
    }
}
