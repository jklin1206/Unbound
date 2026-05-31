// UNBOUND/Models/Standards/Gates/BadgeStandards.swift
import Foundation

// MARK: - Badge gate standards
//
// The numeric floors that gate session/strength badge unlocks, pulled out of
// BadgeService's detection logic (audit Q2) so the tunable thresholds live in
// one place. BadgeService still owns HOW a badge is detected; this owns the
// numbers it checks against.

enum BadgeStandards {

    /// Cumulative session-count milestones → badge id, in ascending order.
    /// A workout that crosses several at once unlocks all of them.
    static let sessionMilestones: [(threshold: Int, badgeId: String)] = [
        (10, "sessions_10"),
        (25, "sessions_25"),
        (50, "sessions_50"),
        (100, "sessions_100"),
        (250, "sessions_250"),
        (500, "sessions_500")
    ]

    /// A single workout at least this long (minutes) unlocks `hour_glass`.
    static let hourGlassMinutes = 60

    /// One clean working set of at least this many push-ups unlocks
    /// `pushup_50_set`.
    static let pushupSingleSetReps = 50

    /// Bodyweight-multiple strength badges: heaviest clean set's
    /// (load / bodyweight) must reach these ratios.
    static let squatBodyweightMultiple = 2.0
    static let benchBodyweightMultiple = 1.5
    static let deadliftBodyweightMultiple = 3.0
}
