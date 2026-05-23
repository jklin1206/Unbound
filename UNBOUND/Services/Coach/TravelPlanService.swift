import Foundation

// MARK: - TravelPlanService
//
// Generates a TravelOverride (bodyweight/minimal-equipment plan) for a
// user-specified number of days. Called directly from TravelModeSheet —
// one button press, one result, saved to TravelOverrideStore.

@MainActor
final class TravelPlanService {
    static let shared = TravelPlanService()
    private let claude = ClaudeClient.shared
    private let database = DatabaseService.shared
    private init() {}

    struct TravelPlanResult {
        let override: TravelOverride
        let summary: String
    }

    func generate(
        userId: String,
        days: Int,
        startDate: Date = Date()
    ) async throws -> TravelPlanResult {

        // Pull minimal context for tone
        let endDate = Calendar.current.date(byAdding: .day, value: days - 1, to: startDate) ?? startDate

        let payload: TravelPlanPayload = try await claude.sendStructured(
            TravelPlanPayload.self,
            model: .sonnet46,
            system: systemPrompt(archetype: "athlete", days: days),
            userText: "Generate a \(days)-day travel training plan. No equipment assumed — bodyweight only unless hotel gym is mentioned.",
            tool: planTool,
            maxTokens: 1024
        )

        let travelDays: [TravelDay] = payload.days.enumerated().map { idx, d in
            TravelDay(
                dayOffset: idx,
                title: d.title,
                duration: d.duration,
                exercises: d.exercises,
                isRest: d.isRest
            )
        }

        let override = TravelOverride(
            userId: userId,
            startDate: startDate,
            endDate: endDate,
            summary: payload.summary,
            days: travelDays
        )

        await TravelOverrideStore.shared.save(override)
        return TravelPlanResult(override: override, summary: payload.summary)
    }

    // MARK: - Prompt

    private func systemPrompt(archetype: String, days: Int) -> String {
        """
        You are a concise PT. Generate a \(days)-day bodyweight travel plan.
        Athlete archetype: \(archetype).
        Rules:
        - No equipment. Hotel room safe.
        - Mix push/pull/legs/core days. Include 1 rest day per 3 training days.
        - Each session: 4-5 exercises, sets x reps, ~30-40 min.
        - Title format: "PUSH" / "PULL" / "LEGS" / "FULL BODY" / "REST"
        - Duration: "~30 MIN" / "~40 MIN" / "REST"
        - Keep exercise names simple: "Push-ups", "Lunges", "Plank", etc.
        - Summary: one punchy coach-voice sentence about the plan.
        """
    }

    // MARK: - Tool

    private var planTool: ClaudeClient.Tool {
        ClaudeClient.Tool(
            name: "travel_plan",
            description: "Structured bodyweight travel training plan",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "summary": .object(["type": .string("string")]),
                    "days": .object([
                        "type": .string("array"),
                        "items": .object([
                            "type": .string("object"),
                            "properties": .object([
                                "title": .object(["type": .string("string")]),
                                "duration": .object(["type": .string("string")]),
                                "exercises": .object([
                                    "type": .string("array"),
                                    "items": .object(["type": .string("string")])
                                ]),
                                "isRest": .object(["type": .string("boolean")])
                            ]),
                            "required": .array([.string("title"), .string("duration"), .string("exercises"), .string("isRest")])
                        ])
                    ])
                ]),
                "required": .array([.string("summary"), .string("days")])
            ])
        )
    }
}

// MARK: - Decodable payload

private struct TravelPlanPayload: Decodable {
    struct DayPayload: Decodable {
        let title: String
        let duration: String
        let exercises: [String]
        let isRest: Bool
    }
    let summary: String
    let days: [DayPayload]
}
