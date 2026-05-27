import XCTest
@testable import UNBOUND

final class CheckpointValidatorTests: XCTestCase {
    func testAccumulatedRecoveryAndSoftCheckInCreateNegativeBias() {
        let result = CheckpointValidator().validate(
            CheckpointValidationInput(
                draft: CheckpointSignalDraft(recoveryStateHint: .accumulated),
                missedSessionSignal: .softCheckIn
            )
        )

        XCTAssertEqual(result.signals.loadAdjustmentBias ?? .nan, -0.24, accuracy: 0.0001)
    }

    func testAttemptedExternalLoadBiasIsIgnoredAndComputedDeterministically() {
        let result = CheckpointValidator().validate(
            CheckpointValidationInput(
                draft: CheckpointSignalDraft(
                    recoveryStateHint: .wellRecovered,
                    attemptedLoadAdjustmentBias: 99
                ),
                standardsCheck: CheckpointStandardsCheck(attemptedCount: 4, clearedCount: 4),
                missedSessionSignal: .onTrack
            )
        )

        XCTAssertEqual(result.ignoredAttemptedLoadAdjustmentBias, 99)
        XCTAssertEqual(result.signals.loadAdjustmentBias ?? .nan, 0.17, accuracy: 0.0001)
    }

    func testModerateCardioMinutesSoftenWellRecoveredRecoveryAndBiasLoadDown() {
        let result = CheckpointValidator().validate(
            CheckpointValidationInput(
                draft: CheckpointSignalDraft(recoveryStateHint: .wellRecovered),
                cardioMinutesLastWeek: 120
            )
        )

        XCTAssertEqual(result.signals.recoveryStateHint, .normal)
        XCTAssertEqual(result.signals.loadAdjustmentBias ?? .nan, -0.04, accuracy: 0.0001)
    }

    func testHighCardioMinutesPushRecoveryAccumulatedAndCreateNegativeBias() {
        let result = CheckpointValidator().validate(
            CheckpointValidationInput(
                draft: CheckpointSignalDraft(),
                cardioMinutesLastWeek: 240
            )
        )

        XCTAssertEqual(result.signals.recoveryStateHint, .accumulated)
        XCTAssertEqual(result.signals.loadAdjustmentBias ?? .nan, -0.28, accuracy: 0.0001)
    }

    func testNormalizeClampsOutOfBoundsBias() {
        let normalized = CheckpointValidator().normalize(
            CheckpointSignals(loadAdjustmentBias: -9, weakRegions: [.chest, .chest])
        )

        XCTAssertEqual(normalized.loadAdjustmentBias, -1.0)
        XCTAssertEqual(normalized.weakRegions, [.chest])
    }

    func testUnknownWeakRegionStringsAreDropped() {
        let result = CheckpointValidator().validate(
            CheckpointValidationInput(
                draft: CheckpointSignalDraft(
                    recoveryStateHint: .normal,
                    weakRegionIDs: ["lats", "Lower Back", "space lasers", "quads", "lats"]
                )
            )
        )

        XCTAssertEqual(result.signals.weakRegions, [.lats, .lowerBack, .quads])
        XCTAssertEqual(result.droppedWeakRegionIDs, ["space lasers"])
    }

    func testMissedSessionSignalUsesRollingMissRatioThresholds() {
        XCTAssertEqual(MissedSessionSignal.fromScheduledSessions(scheduled: 4, missed: 0), .onTrack)
        XCTAssertEqual(MissedSessionSignal.fromScheduledSessions(scheduled: 4, missed: 1), .softCheckIn)
        XCTAssertEqual(MissedSessionSignal.fromScheduledSessions(scheduled: 5, missed: 4), .resetRecommended)
    }
}

final class CardioLogServiceIntegrationTests: XCTestCase {
    func testQueryHelpersFilterByUserAndRollingWindow() async {
        let calendar = utcCalendar
        let asOf = date(year: 2026, month: 5, day: 25, hour: 12)
        let cutoff = calendar.date(byAdding: .day, value: -7, to: asOf)!
        let includedRecent = CardioSession(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            userId: "user-1",
            type: .run,
            durationMinutes: 30,
            perceivedEffort: 6,
            date: date(year: 2026, month: 5, day: 23, hour: 9)
        )
        let includedAtCutoff = CardioSession(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            userId: "user-1",
            type: .bike,
            durationMinutes: 45,
            perceivedEffort: 5,
            date: cutoff
        )
        let outsideWindow = CardioSession(
            userId: "user-1",
            type: .row,
            durationMinutes: 60,
            perceivedEffort: 7,
            date: date(year: 2026, month: 5, day: 17, hour: 12)
        )
        let future = CardioSession(
            userId: "user-1",
            type: .walk,
            durationMinutes: 20,
            perceivedEffort: 3,
            date: date(year: 2026, month: 5, day: 25, hour: 13)
        )
        let otherUser = CardioSession(
            userId: "user-2",
            type: .swim,
            durationMinutes: 90,
            perceivedEffort: 8,
            date: date(year: 2026, month: 5, day: 24, hour: 10)
        )
        let service = MockCardioLogService()
        service.sessions = [outsideWindow, includedRecent, otherUser, future, includedAtCutoff]

        let sessions = await service.sessionsInLastNDays(
            userId: "user-1",
            days: 7,
            asOf: asOf,
            calendar: calendar
        )

        XCTAssertEqual(Set(sessions.map(\.id)), [includedRecent.id, includedAtCutoff.id])
        let minutes = await service.cardioMinutesLastWeek(
            userId: "user-1",
            asOf: asOf,
            calendar: calendar
        )
        XCTAssertEqual(minutes, 75)
    }

    func testMinutesInWeekUsesISOWeekAndUserScope() async {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reference = date(year: 2026, month: 5, day: 20, hour: 12)
        let service = MockCardioLogService()
        service.sessions = [
            cardioSession(
                type: .run,
                durationMinutes: 30,
                date: date(year: 2026, month: 5, day: 18, hour: 8)
            ),
            cardioSession(
                type: .bike,
                durationMinutes: 45,
                date: date(year: 2026, month: 5, day: 24, hour: 22)
            ),
            cardioSession(
                type: .row,
                durationMinutes: 60,
                date: date(year: 2026, month: 5, day: 17, hour: 12)
            ),
            cardioSession(
                type: .walk,
                durationMinutes: 20,
                date: date(year: 2026, month: 5, day: 25, hour: 8)
            ),
            cardioSession(
                userId: "user-2",
                type: .swim,
                durationMinutes: 90,
                date: date(year: 2026, month: 5, day: 20, hour: 10)
            )
        ]

        let minutes = await service.minutesInWeek(
            userId: "user-1",
            of: reference,
            calendar: calendar
        )

        XCTAssertEqual(minutes, 75)
    }

    func testLogPostsCardioLoggedNotificationAfterSuccessfulWrite() async throws {
        let service = CardioLogService(database: MockDatabaseService())
        let session = CardioSession(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            userId: "user-1",
            type: .run,
            durationMinutes: 25,
            perceivedEffort: 6,
            date: date(year: 2026, month: 5, day: 25, hour: 9)
        )
        let posted = expectation(description: "cardioLogged notification posted")
        var receivedSession: CardioSession?
        var receivedSessionId: String?
        let token = NotificationCenter.default.addObserver(
            forName: .cardioLogged,
            object: nil,
            queue: .main
        ) { note in
            guard let logged = note.object as? CardioSession, logged.id == session.id else {
                return
            }
            receivedSession = logged
            receivedSessionId = note.userInfo?["sessionId"] as? String
            posted.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        try await service.log(session: session)
        await fulfillment(of: [posted], timeout: 1)

        XCTAssertEqual(receivedSession, session)
        XCTAssertEqual(receivedSessionId, session.id.uuidString)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return utcCalendar.date(from: components)!
    }

    private func cardioSession(
        userId: String = "user-1",
        type: CardioType,
        durationMinutes: Int,
        date: Date
    ) -> CardioSession {
        CardioSession(
            userId: userId,
            type: type,
            durationMinutes: durationMinutes,
            perceivedEffort: 6,
            date: date
        )
    }
}
