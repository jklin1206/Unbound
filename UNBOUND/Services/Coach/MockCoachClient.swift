import Foundation

final class MockCoachClient: CoachClientProtocol, @unchecked Sendable {
    static let shared = MockCoachClient()

    private init() {}

    func send(messages: [CoachMessage], context: String) async throws -> CoachResponse {
        try? await Task.sleep(nanoseconds: 800_000_000)
        let lastUser = messages.last(where: { $0.role == .user })?.content.lowercased() ?? ""
        return respond(to: lastUser, context: context)
    }

    // MARK: Rule-based responder

    private func respond(to prompt: String, context: String) -> CoachResponse {
        if prompt.isEmpty {
            return CoachResponse(
                text: "Tell me what's on your mind — progression, a swap, deload, or just what to do next session.",
                actions: []
            )
        }

        // Plateau / stuck lift
        if let lift = matchedLift(in: prompt, keywords: ["stuck", "stalled", "plateau", "not progressing", "hasn't moved"]) {
            let weight = parseCurrentWeight(for: lift, in: context)
            let text = """
            Your \(lift) has stalled. That's a signal, not a failure — your CNS is asking for different stimulus.

            Three-week unstall plan:
            1. This week: drop to \(suggestRetreat(weight))kg, pause-rep every set, RPE 7. Rebuild the groove.
            2. Week 2: back to your old working weight, but add a back-off set at 80% for 8.
            3. Week 3: test. Same weight, top of rep range, RPE 9. Should move.

            If it's still stuck after that, we swap the variation for 4-6 weeks.
            """
            return CoachResponse(
                text: text,
                actions: [.acknowledgePlateau(exerciseKey: lift.lowercased())]
            )
        }

        // Swap / replace
        if prompt.contains("swap") || prompt.contains("replace") {
            if let target = matchedLift(in: prompt, keywords: []) {
                let alternatives = ExerciseCatalog.alternatives(to: target).prefix(2).map(\.displayName)
                let altList = alternatives.isEmpty ? ["dumbbell row", "cable row (seated)"] : alternatives
                let to = altList.first ?? "dumbbell row"
                let text = """
                Two clean swaps for \(target) that hit the same pattern:
                1. \(altList[0]) — closest transfer
                \(altList.count > 1 ? "2. \(altList[1]) — if the first feels off" : "")

                I'd go with \(to) this session. Same sets/reps, start 10-15% lighter to find the groove.
                """
                return CoachResponse(
                    text: text,
                    actions: [.swapExercise(from: target.lowercased(), to: to.lowercased(), scope: .session)]
                )
            }
        }

        // Deload
        if prompt.contains("deload") || prompt.contains("rest week") || prompt.contains("too tired") {
            let text = """
            You've earned it. Deload week looks like:
            - Same sessions, same exercises.
            - Weights at 60-70% of working weight.
            - Stop 3 reps short of failure on every set.
            - Sleep 8+. Eat maintenance.

            You'll come back stronger than where you stopped.
            """
            return CoachResponse(
                text: text,
                actions: [.insertDeload(week: 1)]
            )
        }

        // Next session
        if prompt.contains("next session") || prompt.contains("what should i do") || prompt.contains("today's workout") {
            let text = """
            Based on your recent sessions, you're running an upper-lower rotation. Today is \(contextualNextDay(context)).

            Hit the signature first, push for the top of the rep range at RPE 8, then accessories at RPE 7-8 with short rest. Keep the volume — don't skip sets to save time.
            """
            return CoachResponse(text: text, actions: [])
        }

        // First time / build my programme
        if prompt.contains("build my programme") || prompt.contains("build my program") || prompt.contains("first time") || prompt.contains("get started") {
            let text = """
            Your adaptive protocol is already running from your onboarding. The phases it cycles through:
            - Accumulation: volume and technique.
            - Intensification: heavier, fewer reps.
            - Realization: peak strength (unlocks at rank B-).
            - Deload: when your signals say back off.

            The home tab shows the current phase and today's session. Long-press any exercise in the logger to swap it. Tell me when something isn't working and I'll adjust.
            """
            return CoachResponse(text: text, actions: [])
        }

        // Default — contextual follow-up
        let observation = observationFromContext(context)
        let text = """
        Got you. \(observation)

        What's your aim here — more strength, more size, fewer minutes per session, or something's not feeling right in the body?
        """
        return CoachResponse(text: text, actions: [])
    }

    // MARK: Context helpers

    private func matchedLift(in prompt: String, keywords: [String]) -> String? {
        let lifts = [
            "bench press", "bench", "squat", "back squat", "front squat",
            "deadlift", "overhead press", "ohp", "pullup", "pull-up",
            "row", "dumbbell row", "curl", "dip"
        ]
        let hasKeyword = keywords.isEmpty || keywords.contains { prompt.contains($0) }
        guard hasKeyword else { return nil }
        return lifts.first(where: { prompt.contains($0) })
    }

    private func parseCurrentWeight(for lift: String, in context: String) -> Double {
        let lines = context.components(separatedBy: "\n")
        for line in lines where line.lowercased().contains(lift.lowercased()) {
            if let range = line.range(of: #"(\d+(\.\d+)?)kg"#, options: .regularExpression) {
                let str = line[range].replacingOccurrences(of: "kg", with: "")
                if let v = Double(str) { return v }
            }
        }
        return 60
    }

    private func suggestRetreat(_ weight: Double) -> String {
        let retreat = max(0, weight * 0.85)
        return retreat.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", retreat)
            : String(format: "%.1f", retreat)
    }

    private func contextualNextDay(_ context: String) -> String {
        if context.lowercased().contains("last 5 sessions") && context.lowercased().contains("push") {
            return "a pull + legs day"
        }
        return "a full session"
    }

    private func observationFromContext(_ context: String) -> String {
        let lower = context.lowercased()
        if lower.contains("bench press") {
            return "I see bench is in your rotation — it's moving steady."
        }
        if lower.contains("deadlift") {
            return "Your deadlifts are anchoring the programme."
        }
        if lower.contains("no sessions logged yet") {
            return "You haven't logged anything yet — once you run a session I'll have more to go on."
        }
        return "Looking at your recent logs, you've been consistent."
    }
}
