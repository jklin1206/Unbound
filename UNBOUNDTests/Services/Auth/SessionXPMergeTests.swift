import XCTest
@testable import UNBOUND

/// Unit tests for `SessionXPRecord.merging` / `rekeyed` — the streak-preserving
/// logic used when a record is carried across the anonymous → signed-in identity
/// change. Locks the behaviour Codex flagged: a contiguous run must chain (not
/// be discarded for the newer record), a long-dead run must not resurrect, and
/// no path may regress the streak.
final class SessionXPMergeTests: XCTestCase {
    private let cal = Calendar.current

    private func day(_ offset: Int) -> Date {
        let base = cal.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        return cal.date(byAdding: .day, value: offset, to: base)!
    }

    private func record(
        userId: String,
        streak: Int,
        longest: Int,
        total: Int,
        last: Date?
    ) -> SessionXPRecord {
        SessionXPRecord(
            userId: userId,
            totalSessions: total,
            currentStreak: streak,
            longestStreak: longest,
            lastSessionDate: last,
            weeklyCount: streak,
            weekStartDate: last ?? Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    func test_rekeyed_preserves_all_counters_under_new_id() {
        let original = record(userId: "anon", streak: 5, longest: 7, total: 12, last: day(0))
        let moved = original.rekeyed(to: "supabase")
        XCTAssertEqual(moved.userId, "supabase")
        XCTAssertEqual(moved.currentStreak, 5)
        XCTAssertEqual(moved.longestStreak, 7)
        XCTAssertEqual(moved.totalSessions, 12)
        XCTAssertEqual(moved.lastSessionDate, day(0))
    }

    // Finding 1: a 3-day anonymous run ending "yesterday" plus a session "today"
    // under the signed-in id must read as 4 — the older run is NOT discarded.
    func test_merge_chains_contiguous_runs() {
        let legacy = record(userId: "anon", streak: 3, longest: 3, total: 3, last: day(0))
        let target = record(userId: "supabase", streak: 1, longest: 1, total: 1, last: day(1))

        let merged = SessionXPRecord.merging(legacy: legacy, target: target, calendar: cal)

        XCTAssertEqual(merged.userId, "supabase")
        XCTAssertEqual(merged.currentStreak, 4, "Contiguous runs should chain (3 + the new day)")
        XCTAssertEqual(merged.longestStreak, 4)
        XCTAssertEqual(merged.lastSessionDate, day(1))
    }

    // A rest day inside the grace window still chains (Mon run + Wed session).
    func test_merge_chains_across_grace_gap() {
        let legacy = record(userId: "anon", streak: 2, longest: 2, total: 2, last: day(0))
        let target = record(userId: "supabase", streak: 1, longest: 1, total: 1, last: day(2))

        let merged = SessionXPRecord.merging(legacy: legacy, target: target, calendar: cal)

        // 2-day run + a 2-day gap (rest day credited) = 4.
        XCTAssertEqual(merged.currentStreak, 4)
    }

    func test_merge_does_not_resurrect_dead_run() {
        // Legacy run is long but ended ages ago; gap broke it.
        let legacy = record(userId: "anon", streak: 10, longest: 10, total: 30, last: day(0))
        let target = record(userId: "supabase", streak: 2, longest: 2, total: 2, last: day(60))

        let merged = SessionXPRecord.merging(legacy: legacy, target: target, calendar: cal)

        XCTAssertEqual(merged.currentStreak, 2, "A broken old run must not resurrect")
        // But the all-time best is still preserved.
        XCTAssertEqual(merged.longestStreak, 10)
        XCTAssertEqual(merged.totalSessions, 30)
        XCTAssertEqual(merged.lastSessionDate, day(60))
    }

    // Finding 3: same-day tie must take the higher streak, never regress.
    func test_merge_same_day_tie_takes_higher_streak() {
        let legacy = record(userId: "anon", streak: 5, longest: 5, total: 9, last: day(0))
        let target = record(userId: "supabase", streak: 2, longest: 2, total: 2, last: day(0))

        let merged = SessionXPRecord.merging(legacy: legacy, target: target, calendar: cal)

        XCTAssertEqual(merged.currentStreak, 5)
        XCTAssertEqual(merged.longestStreak, 5)
        XCTAssertEqual(merged.totalSessions, 9)
    }

    func test_merge_keeps_best_longest_even_when_newer_run_is_shorter() {
        let legacy = record(userId: "anon", streak: 1, longest: 20, total: 50, last: day(0))
        let target = record(userId: "supabase", streak: 3, longest: 3, total: 4, last: day(1))

        let merged = SessionXPRecord.merging(legacy: legacy, target: target, calendar: cal)

        XCTAssertEqual(merged.longestStreak, 20, "All-time best survives the merge")
        XCTAssertEqual(merged.totalSessions, 50)
    }
}
