import XCTest
@testable import UNBOUND

final class HomeSystemVoiceTests: XCTestCase {

    private func ctx(
        hasProgramDay: Bool = true,
        isRestDay: Bool = false,
        hasWorkout: Bool = true,
        loggedToday: Bool = false,
        currentStreak: Int = 0,
        daySeed: Int = 100
    ) -> HomeSystemVoice.Context {
        HomeSystemVoice.Context(
            hasProgramDay: hasProgramDay,
            isRestDay: isRestDay,
            hasWorkout: hasWorkout,
            loggedToday: loggedToday,
            currentStreak: currentStreak,
            daySeed: daySeed
        )
    }

    // MARK: - State selection priority

    func test_loggedToday_takesPriorityOverEverything() {
        // Logged on a rest day with a workout present still resolves to cleared.
        XCTAssertEqual(
            HomeSystemVoice.state(for: ctx(isRestDay: true, hasWorkout: true, loggedToday: true)),
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
        let c = ctx(loggedToday: true, currentStreak: 0, daySeed: 4242)
        XCTAssertEqual(HomeSystemVoice.line(for: c), HomeSystemVoice.line(for: c))
    }

    func test_lineIsMemberOfItsPool() {
        XCTAssertTrue(HomeSystemVoice.quest.contains(HomeSystemVoice.line(for: ctx())))
        XCTAssertTrue(HomeSystemVoice.cleared.contains(
            HomeSystemVoice.line(for: ctx(loggedToday: true, currentStreak: 0))))
        XCTAssertTrue(HomeSystemVoice.rest.contains(
            HomeSystemVoice.line(for: ctx(isRestDay: true, hasWorkout: false))))
        XCTAssertTrue(HomeSystemVoice.awaiting.contains(
            HomeSystemVoice.line(for: ctx(hasProgramDay: false, hasWorkout: false))))
    }

    // MARK: - Streak beat

    func test_streakAtOrAboveThreshold_interpolatesNumber_andLeavesNoPlaceholder() {
        let line = HomeSystemVoice.line(for: ctx(loggedToday: true, currentStreak: 14))
        XCTAssertTrue(line.contains("14"), "expected the streak count in: \(line)")
        XCTAssertFalse(line.contains("{n}"), "placeholder leaked in: \(line)")
    }

    func test_streakBelowThreshold_usesGenericCleared_noDigits() {
        let line = HomeSystemVoice.line(for: ctx(loggedToday: true, currentStreak: 2))
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
        XCTAssertTrue(HomeSystemVoice.consoleCleared(loggedToday: true, canStartWorkout: true))
        XCTAssertFalse(HomeSystemVoice.consoleCleared(loggedToday: true, canStartWorkout: false))
        XCTAssertFalse(HomeSystemVoice.consoleCleared(loggedToday: false, canStartWorkout: true))
        XCTAssertFalse(HomeSystemVoice.consoleCleared(loggedToday: false, canStartWorkout: false))
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

    func test_canonicalOriginalStrings_arePreserved() {
        XCTAssertTrue(HomeSystemVoice.quest.contains("Daily quest available"))
        XCTAssertTrue(HomeSystemVoice.rest.contains("Recovery directive issued"))
        XCTAssertTrue(HomeSystemVoice.awaiting.contains("Awaiting quest selection"))
    }
}
