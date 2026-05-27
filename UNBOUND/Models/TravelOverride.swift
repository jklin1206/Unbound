import Foundation

// MARK: - TravelOverride
//
// A deterministic bodyweight plan that replaces the user's normal
// `TrainingProgram.days` for a bounded window (typically 3–14 days).
// Persisted in the `travel_overrides` collection and consumed by
// `TrainingProgram.effectiveDay(for:)` + home / Program tab lookups so
// the user sees the travel plan where the normal session would've been.
//
// Per plan, scoped narrowly — only touches the active window, expires
// automatically after `endDate`. Not abused because it's user-initiated
// via the Travel action chip.

struct TravelOverride: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    let startDate: Date
    let endDate: Date           // Inclusive — last day of travel
    let summary: String         // Coach-style one-liner from deterministic template
    let days: [TravelDay]
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        startDate: Date,
        endDate: Date,
        summary: String,
        days: [TravelDay],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.startDate = startDate
        self.endDate = endDate
        self.summary = summary
        self.days = days
        self.createdAt = createdAt
    }

    /// Active if today falls within [startDate, endDate] inclusive.
    func isActive(on date: Date = Date()) -> Bool {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        return day >= cal.startOfDay(for: startDate) && day <= cal.startOfDay(for: endDate)
    }

    /// Returns the override day corresponding to `date`, or nil if outside
    /// the window. Matches by day-offset from `startDate`.
    func day(for date: Date) -> TravelDay? {
        guard isActive(on: date) else { return nil }
        let cal = Calendar.current
        let offset = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: startDate),
            to: cal.startOfDay(for: date)
        ).day ?? 0
        return days.first { $0.dayOffset == offset }
    }
}

struct TravelDay: Codable, Hashable, Sendable {
    /// 0 = startDate, 1 = startDate + 1, etc. Days without an entry are
    /// treated as rest.
    let dayOffset: Int
    let title: String            // e.g. "BODYWEIGHT PUSH" / "REST / WALK"
    let duration: String         // e.g. "~30 MIN"
    let exercises: [String]      // Human-readable names, rendered as-is
    let isRest: Bool
}

extension TravelDay {
    func workout(summary: String) -> Workout? {
        guard !isRest else { return nil }

        let main = exercises.map(Self.exercise)
        let groups = orderedGroups(from: main)
        let warmup = Self.warmup(for: title)
        let cooldown = Self.cooldown(for: title)

        return Workout(
            name: title,
            targetMuscleGroups: groups,
            warmup: warmup,
            mainExercises: main,
            cooldown: cooldown,
            estimatedMinutes: parseMinutes(from: duration),
            notes: summary,
            blockType: .accumulation
        )
    }

    private func orderedGroups(from exercises: [Exercise]) -> [MuscleGroup] {
        let used = Set(exercises.flatMap(\.muscleGroups))
        return MuscleGroup.allCases.filter { used.contains($0) }
    }

    private func parseMinutes(from text: String) -> Int {
        let digits = text.compactMap { $0.isNumber ? $0 : nil }
        if let n = Int(String(digits)), n > 0 { return n }
        return 30
    }

    private static func warmup(for title: String) -> [Exercise] {
        let lower = title.lowercased()
        if lower.contains("leg") {
            return [
                supportExercise("Hip Opener Flow", groups: [.legs, .glutes, .core], reps: "45s", notes: "Move slowly."),
                supportExercise("Tempo Air Squat", groups: [.legs, .glutes, .core], reps: "8", notes: "Three-second lower.")
            ]
        }
        if lower.contains("push") {
            return [
                supportExercise("Scap Pushup", groups: [.chest, .shoulders, .back], reps: "10", notes: "Wake up shoulders."),
                supportExercise("Wrist Prep Flow", groups: [.forearms], reps: "45s", notes: "Prep hands and wrists.")
            ]
        }
        return [
            supportExercise("World's Greatest Stretch", groups: [.legs, .glutes, .back, .core], reps: "45s", notes: "Full-body prep."),
            supportExercise("Jumping Jack", groups: [.legs, .calves, .shoulders], reps: "45s", notes: "Easy pulse raise.")
        ]
    }

    private static func cooldown(for title: String) -> [Exercise] {
        let lower = title.lowercased()
        let stretch = lower.contains("leg")
            ? supportExercise("Couch Stretch", groups: [.legs, .glutes], reps: "45s", notes: "Hip flexor reset.")
            : supportExercise("Child's Pose Reach", groups: [.back, .lats, .shoulders], reps: "45s", notes: "Easy reset.")
        return [
            stretch,
            supportExercise("Box Breathing", groups: [.core], reps: "60s", notes: "Downshift before you leave.")
        ]
    }

    private static func exercise(_ name: String) -> Exercise {
        let lower = name.lowercased()
        let groups: [MuscleGroup]
        let reps: String
        let notes: String

        if lower.contains("row") || lower.contains("pulldown") || lower.contains("pull-down") {
            groups = [.back, .lats, .arms]
            reps = "8-12"
            notes = "Pull elbows toward ribs; keep shoulders down."
        } else if lower.contains("romanian") || lower.contains("rdl") || lower.contains("deadlift") || lower.contains("hinge") {
            groups = [.glutes, .legs, .back, .core]
            reps = "8-12"
            notes = "Hinge cleanly; stop when hamstrings limit the range."
        } else if lower.contains("push") || lower.contains("dip") {
            groups = [.chest, .shoulders, .arms, .core]
            reps = "8-15"
            notes = "Stop 1-2 reps before form breaks."
        } else if lower.contains("squat") || lower.contains("lunge") || lower.contains("wall sit") {
            groups = [.legs, .glutes, .core]
            reps = lower.contains("wall sit") ? "30-45s" : "10-14/side"
            notes = "Control the descent; keep the knee tracking clean."
        } else if lower.contains("glute") {
            groups = [.glutes, .legs, .core]
            reps = "10-14/side"
            notes = "Pause at the top."
        } else if lower.contains("calf") {
            groups = [.calves, .legs]
            reps = "15-25"
            notes = "Full stretch and full lockout."
        } else if lower.contains("plank") || lower.contains("hollow") || lower.contains("mountain") {
            groups = [.core, .shoulders]
            reps = lower.contains("mountain") ? "30-40s" : "20-40s"
            notes = "Keep ribs down and breathe."
        } else if lower.contains("swimmer") {
            groups = [.back, .shoulders, .traps]
            reps = "10-15"
            notes = "Squeeze shoulder blades without shrugging."
        } else {
            groups = [.core]
            reps = "8-12"
            notes = "Controlled travel-session work."
        }

        return Exercise(
            id: UUID().uuidString,
            name: name,
            muscleGroups: groups,
            sets: 3,
            reps: reps,
            restSeconds: 60,
            rpe: 7,
            notes: notes,
            substitution: nil
        )
    }

    private static func supportExercise(
        _ name: String,
        groups: [MuscleGroup],
        reps: String,
        notes: String
    ) -> Exercise {
        Exercise(
            id: UUID().uuidString,
            name: name,
            muscleGroups: groups,
            sets: 1,
            reps: reps,
            restSeconds: 20,
            rpe: 5,
            notes: notes,
            substitution: nil
        )
    }
}
