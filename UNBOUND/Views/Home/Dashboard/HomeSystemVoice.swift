import Foundation

// MARK: - HomeSystemVoice
//
// The System's voice on Home. Picks a terse directive line from a pool based
// on the day's training state, so the [ SYSTEM ] line at the top of the hero
// feels like it's reacting to you instead of repeating one of three strings.
//
// The line is DETERMINISTIC per `daySeed`: stable across SwiftUI re-renders
// within a day (no strobing on every redraw), and it rotates day-to-day. The
// state machine adds the missing "you just cleared it" beat — the moment that
// carries the streak.
//
// Rendering constraint (HomeSystemDirectiveLine): the message is shown
// UPPERCASED on a single monospaced line with minimumScaleFactor(0.72). Keep
// every line terse (~2-4 words) or it scales down and reads cramped.
enum HomeSystemVoice {

    enum State: Equatable {
        case cleared   // a session was logged today — the reward beat
        case rest      // rest day, nothing logged yet
        case quest     // a workout is available, not logged yet
        case awaiting  // no program day resolved
    }

    struct Context {
        var hasProgramDay: Bool
        var isRestDay: Bool
        var hasWorkout: Bool
        var loggedToday: Bool
        var currentStreak: Int
        var daySeed: Int
    }

    /// Streak length at which the cleared beat starts naming the number.
    static let streakThreshold = 3

    static func state(for ctx: Context) -> State {
        // loggedToday wins: once you've done the work, the System acknowledges
        // it regardless of what kind of day it was.
        if ctx.loggedToday { return .cleared }
        if ctx.hasProgramDay && ctx.isRestDay { return .rest }
        if ctx.hasWorkout { return .quest }
        return .awaiting
    }

    static func line(for ctx: Context) -> String {
        switch state(for: ctx) {
        case .cleared:
            if ctx.currentStreak >= streakThreshold {
                let template = pick(clearedStreak, seed: ctx.daySeed, salt: 7)
                return template.replacingOccurrences(of: "{n}", with: "\(ctx.currentStreak)")
            }
            return pick(cleared, seed: ctx.daySeed, salt: 1)
        case .rest:
            return pick(rest, seed: ctx.daySeed, salt: 2)
        case .quest:
            return pick(quest, seed: ctx.daySeed, salt: 3)
        case .awaiting:
            return pick(awaiting, seed: ctx.daySeed, salt: 4)
        }
    }

    /// Days since the Unix epoch — stable within a calendar day, advances daily.
    static func daySeed(asOf now: Date = Date()) -> Int {
        Int(now.timeIntervalSince1970 / 86_400)
    }

    /// Deterministic pool index. `salt` keeps different states from landing on
    /// the same rotation phase on the same day. Modulo is normalized so a
    /// negative product can't trap (no `abs`, no Int.min edge case).
    private static func pick(_ pool: [String], seed: Int, salt: Int) -> String {
        guard !pool.isEmpty else { return "" }
        let h = (seed &* 31) &+ salt
        let idx = ((h % pool.count) + pool.count) % pool.count
        return pool[idx]
    }

    // MARK: - Line pools
    //
    // Internal (not private) so the test target can assert membership and that
    // none are empty. The original three directive strings are preserved inside
    // their pools so nothing about the prior copy is lost.

    static let quest: [String] = [
        "Daily quest available",
        "Directive issued",
        "A challenge has appeared",
        "Today's path is marked",
        "The System summons you",
        "Answer the directive",
        "Quest standing by"
    ]

    static let cleared: [String] = [
        "Quest cleared",
        "Directive complete",
        "Discipline logged",
        "The System acknowledges you",
        "Cleared — stand down",
        "Work recorded"
    ]

    static let clearedStreak: [String] = [
        "{n} days unbroken",
        "Streak holds — {n} days",
        "{n} in a row",
        "Chain intact — {n} days",
        "{n}-day streak logged"
    ]

    static let rest: [String] = [
        "Recovery directive issued",
        "Recovery sanctioned",
        "Stand down and recover",
        "Recovery cycle active",
        "Rest is the program"
    ]

    static let awaiting: [String] = [
        "Awaiting quest selection",
        "No directive assigned",
        "Choose your path"
    ]
}
