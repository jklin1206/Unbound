import Foundation

// MARK: - TravelPlanService
//
// Builds a TravelOverride (bodyweight/minimal-equipment plan) for a
// user-specified number of days. Called directly from TravelModeSheet —
// one button press, one result, saved to TravelOverrideStore.

@MainActor
final class TravelPlanService {
    static let shared = TravelPlanService()
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

        let endDate = Calendar.current.date(byAdding: .day, value: days - 1, to: startDate) ?? startDate
        let templates = Self.travelTemplates
        let travelDays: [TravelDay] = (0..<max(1, days)).map { idx in
            let template = (idx + 1).isMultiple(of: 4)
                ? Self.restTemplate
                : templates[idx % templates.count]
            return TravelDay(
                dayOffset: idx,
                title: template.title,
                duration: template.duration,
                exercises: template.exercises,
                isRest: template.isRest
            )
        }
        let summary = "\(days)-day travel block loaded: bodyweight sessions keep rhythm without rewriting the main arc."

        let override = TravelOverride(
            userId: userId,
            startDate: startDate,
            endDate: endDate,
            summary: summary,
            days: travelDays
        )

        await TravelOverrideStore.shared.save(override)
        return TravelPlanResult(override: override, summary: summary)
    }

    private struct TravelTemplate {
        let title: String
        let duration: String
        let exercises: [String]
        let isRest: Bool
    }

    private static let travelTemplates: [TravelTemplate] = [
        .init(
            title: "PUSH",
            duration: "~30 MIN",
            exercises: ["Push-ups", "Pike Push-ups", "Chair Dips", "Plank Shoulder Taps", "Hollow Hold"],
            isRest: false
        ),
        .init(
            title: "LEGS",
            duration: "~35 MIN",
            exercises: ["Split Squats", "Reverse Lunges", "Single-Leg Glute Bridge", "Wall Sit", "Calf Raises"],
            isRest: false
        ),
        .init(
            title: "FULL BODY",
            duration: "~30 MIN",
            exercises: ["Tempo Squats", "Push-ups", "Prone Swimmers", "Mountain Climbers", "Side Plank"],
            isRest: false
        )
    ]

    private static let restTemplate = TravelTemplate(
        title: "REST",
        duration: "REST",
        exercises: ["Walk 20 minutes", "Couch Stretch", "Thread the Needle", "Deep Breathing"],
        isRest: true
    )
}
