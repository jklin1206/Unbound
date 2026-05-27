import Foundation

protocol CardioLogServiceProtocol: Sendable {
    func log(session: CardioSession) async throws
    func all(userId: String) async -> [CardioSession]
    func recent(userId: String, days: Int) async -> [CardioSession]
    func delete(id: UUID) async throws
}

extension CardioLogServiceProtocol {
    func sessionsInRange(
        userId: String,
        from startDate: Date,
        through endDate: Date
    ) async -> [CardioSession] {
        guard startDate <= endDate else { return [] }
        return await all(userId: userId).filter {
            $0.date >= startDate && $0.date <= endDate
        }
    }

    func sessionsInLastNDays(
        userId: String,
        days: Int,
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) async -> [CardioSession] {
        guard days > 0 else { return [] }
        let cutoff = calendar.date(byAdding: .day, value: -days, to: date) ?? date
        return await sessionsInRange(userId: userId, from: cutoff, through: date)
    }

    func minutesInLastNDays(
        userId: String,
        days: Int,
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) async -> Int {
        await sessionsInLastNDays(
            userId: userId,
            days: days,
            asOf: date,
            calendar: calendar
        )
        .reduce(0) { $0 + max(0, $1.durationMinutes) }
    }

    func cardioMinutesLastWeek(
        userId: String,
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) async -> Int {
        await minutesInLastNDays(userId: userId, days: 7, asOf: date, calendar: calendar)
    }

    func minutesInWeek(
        userId: String,
        of date: Date,
        calendar: Calendar = Calendar(identifier: .iso8601)
    ) async -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return 0
        }

        return await all(userId: userId)
            .filter { $0.date >= interval.start && $0.date < interval.end }
            .reduce(0) { $0 + max(0, $1.durationMinutes) }
    }
}

final class CardioLogService: CardioLogServiceProtocol, @unchecked Sendable {
    static let shared = CardioLogService()
    private let database: any DatabaseServiceProtocol
    private let logger: LoggingService

    init(
        database: any DatabaseServiceProtocol = DatabaseService.shared,
        logger: LoggingService = .shared
    ) {
        self.database = database
        self.logger = logger
    }

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
        NotificationCenter.default.post(
            name: .cardioLogged,
            object: session,
            userInfo: [
                "sessionId": session.id.uuidString,
                "userId": session.userId
            ]
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
