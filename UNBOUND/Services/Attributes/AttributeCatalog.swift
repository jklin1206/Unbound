// UNBOUND/Services/Attributes/AttributeCatalog.swift
import Foundation

@MainActor
final class AttributeCatalog: AttributeCatalogProtocol {
    static let shared = AttributeCatalog()

    private let byExercise: [String: AttributeContribution]
    private let bySkillNode: [String: AttributeContribution]

    init() {
        if let url = Bundle.main.url(forResource: "AttributeContributions", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let payload = try? JSONDecoder().decode(Payload.self, from: data)
        {
            // Normalize keys at load: trim + lowercase so lookups always match
            // regardless of how the JSON was authored. This mirrors how
            // LiftRank.exerciseKey is stored (space-lowercase from CatalogExercise.name).
            self.byExercise  = Dictionary(uniqueKeysWithValues:
                payload.exercises.map { (key, dict) in
                    (key.trimmingCharacters(in: .whitespaces).lowercased(),
                     AttributeContribution(weights: dict.toAttributeWeights()))
                }
            )
            self.bySkillNode = payload.skill_nodes.mapValues { AttributeContribution(weights: $0.toAttributeWeights()) }
        } else {
            self.byExercise  = [:]
            self.bySkillNode = [:]
            LoggingService.shared.log(
                "AttributeContributions.json missing or invalid — every contribution will be zero.",
                level: .warning
            )
            #if DEBUG
            assertionFailure("AttributeContributions.json failed to load — build configuration error, not runtime.")
            #endif
        }
    }

    func contribution(forExerciseName name: String) -> AttributeContribution {
        byExercise[name.trimmingCharacters(in: .whitespaces).lowercased()] ?? .zero
    }

    func contribution(forSkillNodeId id: String) -> AttributeContribution {
        bySkillNode[id] ?? .zero
    }
}

// MARK: - JSON shapes

private struct Payload: Decodable {
    let exercises: [String: WeightDict]
    let skill_nodes: [String: WeightDict]
}

private struct WeightDict: Decodable {
    let power: Double?
    let agility: Double?
    let control: Double?
    let endurance: Double?
    let mobility: Double?
    let explosiveness: Double?

    func toAttributeWeights() -> [AttributeKey: Double] {
        var out: [AttributeKey: Double] = [:]
        if let v = power, v > 0         { out[.power] = v }
        if let v = agility, v > 0       { out[.agility] = v }
        if let v = control, v > 0       { out[.control] = v }
        if let v = endurance, v > 0     { out[.endurance] = v }
        if let v = mobility, v > 0      { out[.mobility] = v }
        if let v = explosiveness, v > 0 { out[.explosiveness] = v }
        return out
    }
}
