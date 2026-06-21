import XCTest
@testable import UNBOUND

final class HomeSystemVoiceTests: XCTestCase {

    private func ctx(
        hasProgramDay: Bool = true,
        isRestDay: Bool = false,
        hasWorkout: Bool = true,
        questLoggedToday: Bool = false,
        currentStreak: Int = 0,
        daySeed: Int = 100
    ) -> HomeSystemVoice.Context {
        HomeSystemVoice.Context(
            hasProgramDay: hasProgramDay,
            isRestDay: isRestDay,
            hasWorkout: hasWorkout,
            questLoggedToday: questLoggedToday,
            currentStreak: currentStreak,
            daySeed: daySeed
        )
    }

    // MARK: - State selection priority

    func test_loggedToday_takesPriorityOverEverything() {
        // Logged on a rest day with a workout present still resolves to cleared.
        XCTAssertEqual(
            HomeSystemVoice.state(for: ctx(isRestDay: true, hasWorkout: true, questLoggedToday: true)),
            .cleared)
    }

    func test_restBeforeQuest_whenNotLogged() {
        XCTAssertEqual(
            HomeSystemVoice.state(for: ctx(isRestDay: true, hasWorkout: false)),
            .rest)
    }

    func test_quest_whenWorkoutAvailableAndNotLogged() {
        XCTAssertEqual(
            HomeSystemVoice.state(for: ctx(isRestDay: false, hasWorkout: true)),
            .quest)
    }

    func test_awaiting_whenNoProgramDay() {
        XCTAssertEqual(
            HomeSystemVoice.state(for: ctx(hasProgramDay: false, hasWorkout: false)),
            .awaiting)
    }

    // MARK: - Determinism (no strobing across re-renders)

    func test_sameContext_yieldsSameLine() {
        let c = ctx(questLoggedToday: true, currentStreak: 0, daySeed: 4242)
        XCTAssertEqual(HomeSystemVoice.line(for: c), HomeSystemVoice.line(for: c))
    }

    func test_lineIsMemberOfItsPool() {
        XCTAssertTrue(HomeSystemVoice.quest.contains(HomeSystemVoice.line(for: ctx())))
        XCTAssertTrue(HomeSystemVoice.cleared.contains(
            HomeSystemVoice.line(for: ctx(questLoggedToday: true, currentStreak: 0))))
        XCTAssertTrue(HomeSystemVoice.rest.contains(
            HomeSystemVoice.line(for: ctx(isRestDay: true, hasWorkout: false))))
        XCTAssertTrue(HomeSystemVoice.awaiting.contains(
            HomeSystemVoice.line(for: ctx(hasProgramDay: false, hasWorkout: false))))
    }

    // MARK: - Streak beat

    func test_streakAtOrAboveThreshold_interpolatesNumber_andLeavesNoPlaceholder() {
        let line = HomeSystemVoice.line(for: ctx(questLoggedToday: true, currentStreak: 14))
        XCTAssertTrue(line.contains("14"), "expected the streak count in: \(line)")
        XCTAssertFalse(line.contains("{n}"), "placeholder leaked in: \(line)")
    }

    func test_streakBelowThreshold_usesGenericCleared_noDigits() {
        let line = HomeSystemVoice.line(for: ctx(questLoggedToday: true, currentStreak: 2))
        XCTAssertTrue(HomeSystemVoice.cleared.contains(line))
        XCTAssertFalse(line.contains(where: \.isNumber))
    }

    // MARK: - Variety actually exists

    func test_rotation_producesMoreThanOneLineAcrossDays() {
        let lines = Set((0..<60).map { seed in
            HomeSystemVoice.line(for: ctx(daySeed: seed))
        })
        XCTAssertGreaterThan(lines.count, 1, "quest line never rotated across 60 days")
    }

    // MARK: - Pool integrity

    func test_allPoolsNonEmpty() {
        XCTAssertFalse(HomeSystemVoice.quest.isEmpty)
        XCTAssertFalse(HomeSystemVoice.cleared.isEmpty)
        XCTAssertFalse(HomeSystemVoice.clearedStreak.isEmpty)
        XCTAssertFalse(HomeSystemVoice.rest.isEmpty)
        XCTAssertFalse(HomeSystemVoice.awaiting.isEmpty)
        XCTAssertFalse(HomeSystemVoice.completionQuotes.isEmpty)
    }

    // MARK: - Completed-console voice

    func test_consoleCleared_onlyWhenLoggedAndStartable() {
        XCTAssertTrue(HomeSystemVoice.consoleCleared(questLoggedToday: true, canStartWorkout: true))
        XCTAssertFalse(HomeSystemVoice.consoleCleared(questLoggedToday: true, canStartWorkout: false))
        XCTAssertFalse(HomeSystemVoice.consoleCleared(questLoggedToday: false, canStartWorkout: true))
        XCTAssertFalse(HomeSystemVoice.consoleCleared(questLoggedToday: false, canStartWorkout: false))
    }

    func test_completionQuote_isMemberAndDeterministic() {
        let q = HomeSystemVoice.completionQuote(daySeed: 4242)
        XCTAssertTrue(HomeSystemVoice.completionQuotes.contains(q))
        XCTAssertEqual(q, HomeSystemVoice.completionQuote(daySeed: 4242))
    }

    func test_completionQuote_rotatesAcrossDays() {
        let quotes = Set((0..<60).map { HomeSystemVoice.completionQuote(daySeed: $0) })
        XCTAssertGreaterThan(quotes.count, 1, "completion quote never rotated across 60 days")
    }

    // MARK: - Daily seed (local calendar)

    func test_daySeed_stableWithinLocalDay_advancesNextDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        let morning = cal.date(from: DateComponents(year: 2026, month: 6, day: 19, hour: 8))!
        let lateEvening = cal.date(from: DateComponents(year: 2026, month: 6, day: 19, hour: 23))!
        let nextDay = cal.date(from: DateComponents(year: 2026, month: 6, day: 20, hour: 8))!
        // Same local day -> same seed even across the UTC-midnight boundary (~7pm local).
        XCTAssertEqual(HomeSystemVoice.daySeed(asOf: morning, calendar: cal),
                       HomeSystemVoice.daySeed(asOf: lateEvening, calendar: cal))
        // Next local day -> seed advances.
        XCTAssertNotEqual(HomeSystemVoice.daySeed(asOf: morning, calendar: cal),
                          HomeSystemVoice.daySeed(asOf: nextDay, calendar: cal))
    }

    func test_canonicalOriginalStrings_arePreserved() {
        XCTAssertTrue(HomeSystemVoice.quest.contains("Daily quest available"))
        XCTAssertTrue(HomeSystemVoice.rest.contains("Recovery directive issued"))
        XCTAssertTrue(HomeSystemVoice.awaiting.contains("Awaiting quest selection"))
    }
}
