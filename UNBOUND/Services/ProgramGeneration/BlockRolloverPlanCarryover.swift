import Foundation

/// Carries the USER's planning layer across a block rollover.
///
/// `BlockRolloverService.performRollover` regenerates the arc from scratch,
/// which is correct for the generated plan but must never erase what the user
/// authored. Two carries happen here:
///
/// 1. **Re-key future plans.** `ProgramScheduleOccurrence`s are stored against
///    the program id; a fresh arc gets a fresh id, which would orphan every
///    plan the user placed past the boundary. Future-dated occurrences move to
///    the new id so they keep resolving.
/// 2. **Stamp the weekly pattern.** A weekday the user repeatedly overrode in
///    the finished arc (>= `patternThreshold` same-weekday occurrences) is
///    treated as "their" day: the most recent workout on that weekday is
///    stamped onto every matching weekday of the new arc. The generated day
///    stays underneath as the fallback, and each stamp is an ordinary
///    occurrence the user can clear per-day.
///
/// Pure planning only — the caller applies the result to `ProgramScheduleStore`.
enum BlockRolloverPlanCarryover {
    /// Same-weekday user-authored occurrences needed before a weekday counts
    /// as an established pattern. One-off sessions stay one-offs.
    static let patternThreshold = 2

    struct Plan {
        /// Existing occurrences whose `programId` moved to the new arc.
        var rekeyed: [ProgramScheduleOccurrence] = []
        /// New occurrences stamped onto the new arc from the weekly pattern.
        var stamped: [ProgramScheduleOccurrence] = []

        var isEmpty: Bool { rekeyed.isEmpty && stamped.isEmpty }
    }

    /// Convenience overload used by the rollover flow.
    static func plan(
        previousProgram: TrainingProgram?,
        occurrences: [ProgramScheduleOccurrence],
        userId: String,
        newProgram: TrainingProgram,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Plan {
        let newStart = BlockRolloverScheduler.activeStartDate(for: newProgram)
        let newDuration = newProgram.currentArc == nil
            ? newProgram.durationDays
            : Arc.durationDays
        guard let previousProgram else {
            return plan(
                previousStart: nil,
                previousDurationDays: 0,
                previousUserOwnedDays: [],
                previousProgramId: nil,
                occurrences: occurrences,
                userId: userId,
                newProgramId: newProgram.id,
                newStart: newStart,
                newDurationDays: newDuration,
                calendar: calendar,
                now: now
            )
        }
        let previousStart = BlockRolloverScheduler.activeStartDate(for: previousProgram)
        let previousDuration = previousProgram.currentArc == nil
            ? previousProgram.durationDays
            : Arc.durationDays
        return plan(
            previousStart: previousStart,
            previousDurationDays: previousDuration,
            previousUserOwnedDays: previousProgram.days.filter(\.isUserOwnedWorkout),
            previousProgramId: previousProgram.id,
            occurrences: occurrences,
            userId: userId,
            newProgramId: newProgram.id,
            newStart: newStart,
            newDurationDays: newDuration,
            calendar: calendar,
            now: now
        )
    }

    static func plan(
        previousStart: Date?,
        previousDurationDays: Int,
        previousUserOwnedDays: [ProgramDay],
        previousProgramId: String?,
        occurrences: [ProgramScheduleOccurrence],
        userId: String,
        newProgramId: String,
        newStart: Date,
        newDurationDays: Int,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Plan {
        var plan = Plan()
        let newStartDay = calendar.startOfDay(for: newStart)
        let userOccurrences = occurrences.filter { $0.userId == userId }

        // 1. Re-key plans the user placed on/after the new arc's first day.
        //    nil-programId occurrences already pass the store's filters.
        for occurrence in userOccurrences {
            guard let previousProgramId,
                  occurrence.programId == previousProgramId,
                  occurrence.date >= newStartDay
            else { continue }
            var moved = occurrence
            moved.programId = newProgramId
            moved.updatedAt = now
            plan.rekeyed.append(moved)
        }

        // Dates in the new arc already claimed by an explicit plan — a
        // pattern stamp never overwrites one.
        var claimedDates = Set(
            (plan.rekeyed + userOccurrences.filter { $0.programId == nil })
                .filter { !$0.isExtraSession }
                .map { calendar.startOfDay(for: $0.date) }
        )

        // 2. Collect the user's authored days inside the finished arc window.
        guard let previousStart, previousDurationDays > 0 else { return plan }
        let windowStart = calendar.startOfDay(for: previousStart)
        guard let windowEnd = calendar.date(byAdding: .day, value: previousDurationDays, to: windowStart) else {
            return plan
        }

        var sources: [PatternSource] = userOccurrences.compactMap { occurrence in
            guard occurrence.kind == .saved || occurrence.kind == .built,
                  occurrence.date >= windowStart, occurrence.date < windowEnd,
                  occurrence.programId == nil || occurrence.programId == previousProgramId
            else { return nil }
            return PatternSource(
                date: calendar.startOfDay(for: occurrence.date),
                kind: occurrence.kind,
                title: occurrence.title,
                savedWorkoutId: occurrence.savedWorkoutId,
                draft: occurrence.draft,
                attachScheduledSkills: occurrence.attachScheduledSkills,
                adaptsWithProgression: occurrence.adaptsWithProgression
            )
        }

        // User-owned days written into the program document (saved-workout
        // slots / drafts) count toward the same pattern.
        for day in previousUserOwnedDays {
            guard day.dayNumber >= 1, day.dayNumber <= previousDurationDays,
                  let date = calendar.date(byAdding: .day, value: day.dayNumber - 1, to: windowStart)
            else { continue }
            sources.append(
                PatternSource(
                    date: date,
                    kind: day.savedWorkoutId != nil ? .saved : .built,
                    title: day.userWorkoutDraft?.title ?? day.label,
                    savedWorkoutId: day.savedWorkoutId,
                    draft: day.userWorkoutDraft,
                    attachScheduledSkills: true,
                    adaptsWithProgression: true
                )
            )
        }

        // 3. Group by weekday; a weekday with enough distinct authored dates
        //    is a pattern, represented by its most recent workout.
        let byWeekday = Dictionary(grouping: sources) {
            calendar.component(.weekday, from: $0.date)
        }
        var representatives: [Int: PatternSource] = [:]
        for (weekday, entries) in byWeekday {
            let distinctDates = Set(entries.map(\.date))
            guard distinctDates.count >= patternThreshold,
                  let latest = entries.max(by: { $0.date < $1.date })
            else { continue }
            representatives[weekday] = latest
        }
        guard !representatives.isEmpty else { return plan }

        // 4. Stamp each pattern weekday across the new arc window.
        for offset in 0..<newDurationDays {
            guard let date = calendar.date(byAdding: .day, value: offset, to: newStartDay) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            guard let source = representatives[weekday], !claimedDates.contains(date) else { continue }
            claimedDates.insert(date)
            plan.stamped.append(
                ProgramScheduleOccurrence(
                    userId: userId,
                    programId: newProgramId,
                    date: date,
                    kind: source.kind,
                    title: source.title,
                    savedWorkoutId: source.savedWorkoutId,
                    draft: source.draft,
                    attachScheduledSkills: source.attachScheduledSkills,
                    adaptsWithProgression: source.adaptsWithProgression,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }
        return plan
    }

    private struct PatternSource {
        let date: Date
        let kind: ProgramScheduleOccurrenceKind
        let title: String
        let savedWorkoutId: UUID?
        let draft: TrainingSessionDraft?
        let attachScheduledSkills: Bool
        let adaptsWithProgression: Bool
    }
}
