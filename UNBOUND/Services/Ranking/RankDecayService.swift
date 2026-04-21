import Foundation
import SwiftUI

// MARK: - RankDecayService
//
// Runs on app foreground. Reads the user's last WorkoutLog timestamp and:
//   • days < 7  → not recalibrating, no decay
//   • days 7-13 → set `unbound.isRecalibrating = true` (banner shows)
//   • days >=14 → decay 1 sub-rank for every additional 7 days of inactivity
//                 past day 14 (weeks = (days - 14)/7 + 1)
//
// Capability unlocks (ProgressionFamilyState tiers) + peak rank never
// decay. `lastDecayAppliedAt` is persisted so re-launches don't re-apply
// the same decay step twice.

@MainActor
final class RankDecayService {
    static let shared = RankDecayService()
    private let logger = LoggingService.shared
    private let rankService: RankServiceProtocol = RankService.shared

    private let kIsRecalibrating = "unbound.isRecalibrating"
    private let kLastDecayAppliedAt = "unbound.lastDecayAppliedAt"
    private let kStreakResetDays = "unbound.streakResetDays"
    private let kStreakDays = "unbound.streakDays"

    private init() {}

    // MARK: Public entry points

    /// Kick off on app foreground / first home appearance. Safe to call
    /// repeatedly — internal persistence stops redundant decay runs.
    func evaluateOnForeground(userId: String) async {
        let defaults = UserDefaults.standard

        // Fetch most recent log
        let lastLogDate: Date? = await lastLogDate(userId: userId)

        guard let last = lastLogDate else {
            // New user / no logs yet — nothing to decay.
            defaults.set(false, forKey: kIsRecalibrating)
            return
        }

        let now = Date()
        let days = Int(now.timeIntervalSince(last) / 86400)

        // Streak reset at configurable day count (default 14)
        let streakResetThreshold = max(1, defaults.integer(forKey: kStreakResetDays) == 0
            ? 14
            : defaults.integer(forKey: kStreakResetDays))
        if days >= streakResetThreshold {
            defaults.set(0, forKey: kStreakDays)
        }

        // Recalibrating window: 7-13 days
        if days < 7 {
            defaults.set(false, forKey: kIsRecalibrating)
            return
        }

        if days < 14 {
            defaults.set(true, forKey: kIsRecalibrating)
            return
        }

        // Day 14+: at least 1 sub-rank decay due.
        defaults.set(true, forKey: kIsRecalibrating)

        let weeksOverdue = ((days - 14) / 7) + 1

        // Skip if we've already applied decay today.
        let lastDecayTs = defaults.double(forKey: kLastDecayAppliedAt)
        if lastDecayTs > 0 {
            let lastDecay = Date(timeIntervalSince1970: lastDecayTs)
            if Calendar.current.isDate(lastDecay, inSameDayAs: now) {
                return
            }
        }

        await applyDecay(userId: userId, steps: weeksOverdue, now: now)
        defaults.set(now.timeIntervalSince1970, forKey: kLastDecayAppliedAt)
    }

    /// Clear recalibrating state once the user logs again.
    func clearRecalibration() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: kIsRecalibrating)
        defaults.set(0, forKey: kLastDecayAppliedAt)
    }

    /// Read-only flag used by the UI banner.
    var isRecalibrating: Bool {
        UserDefaults.standard.bool(forKey: kIsRecalibrating)
    }

    // MARK: Private

    private func lastLogDate(userId: String) async -> Date? {
        do {
            let logs = try await WorkoutLogService.shared.fetchRecentLogs(userId: userId, limit: 1)
            return logs.first?.startedAt
        } catch {
            logger.log("RankDecayService lastLogDate failed: \(error)", level: .warning)
            return nil
        }
    }

    private func applyDecay(userId: String, steps: Int, now: Date) async {
        let ranks = await rankService.fetchAll(userId: userId)
        var changedCount = 0
        for rank in ranks where rank.currentRank > .eMinus {
            var next = rank
            next.currentRank = rank.currentRank.decayed(by: steps)
            // Peak never decays — this is the share-worthy ceiling.
            await rankService.save(next)
            changedCount += 1
        }
        if changedCount > 0 {
            logger.log("Rank decay applied: \(changedCount) ranks decayed by \(steps) sub-rank(s)", level: .info)
        }
    }
}
