import Foundation

enum MovementResolver {
    static func resolve(_ rawName: String) -> ResolvedMovement {
        let normalized = MovementCatalog.normalized(rawName)
        let definition = directDefinition(for: normalized) ?? inferredDefinition(for: normalized, rawName: rawName)
        return ResolvedMovement(
            rawName: rawName,
            movementId: definition.id,
            displayName: definition.displayName,
            role: definition.role,
            rankable: definition.rankable,
            rankTemplate: definition.rankTemplate,
            blockKind: definition.blockKind,
            loggerMode: definition.loggerMode,
            canonicalExerciseName: definition.canonicalExerciseName,
            variantOfMovementId: definition.variantOfMovementId,
            rankStandardMovementId: definition.rankStandardMovementId,
            skillId: definition.skillId,
            cardioType: definition.cardioType,
            movementSlot: definition.movementSlot,
            bodyRegions: definition.bodyRegions,
            substitutionGroup: definition.substitutionGroup,
            variationTags: variationTags(for: normalized)
        )
    }

    private static func directDefinition(for normalized: String) -> MovementDefinition? {
        MovementCatalog.aliasIndex[normalized]
    }

    private static func inferredDefinition(for normalized: String, rawName: String) -> MovementDefinition {
        if let cardio = inferCardio(from: normalized) {
            return cardio
        }
        if let carry = inferCarry(from: normalized) {
            return carry
        }
        if let mobility = inferMobility(from: normalized) {
            return mobility
        }
        if let base = inferAliasBase(from: normalized) {
            return base
        }
        return MovementDefinition(
            id: "unresolved.\(MovementCatalog.slug(rawName))",
            displayName: rawName,
            role: .routineStep,
            rankable: false,
            rankTemplate: .unranked,
            blockKind: .routine,
            loggerMode: .routinePlayer,
            aliases: [],
            attributeWeights: [:],
            canonicalExerciseName: nil,
            skillId: nil,
            cardioType: nil,
            defaultMetric: .reps,
            equipment: [],
            difficulty: .beginner,
            muscleGroups: [],
            bodyRegions: [],
            movementSlot: .routine,
            substitutionGroup: "unresolved"
        )
    }

    private static func inferCardio(from normalized: String) -> MovementDefinition? {
        let candidates: [(String, CardioType)] = [
            ("run", .run), ("sprint", .run),
            ("bike", .bike), ("assault bike", .bike),
            ("row", .row), ("rower", .row),
            ("walk", .walk),
            ("swim", .swim),
            ("stairs", .stairs),
            ("elliptical", .elliptical)
        ]
        guard let type = candidates.first(where: { normalized.contains($0.0) })?.1 else { return nil }
        return MovementCatalog.aliasIndex[MovementCatalog.normalized(type.displayName)]
    }

    private static func inferCarry(from normalized: String) -> MovementDefinition? {
        if normalized.contains("sled") { return MovementCatalog.aliasIndex["sled push"] }
        if normalized.contains("suitcase") { return MovementCatalog.aliasIndex["suitcase carry"] }
        if normalized.contains("farmer") { return MovementCatalog.aliasIndex["farmer carry"] }
        if normalized.contains("carry") { return MovementCatalog.aliasIndex["loaded march"] }
        return nil
    }

    private static func inferMobility(from normalized: String) -> MovementDefinition? {
        let mobilityTerms = [
            "stretch", "mobility", "wrist", "thoracic", "hamstring",
            "pigeon", "cat cow", "cat-cow", "frog", "couch", "hip flexor",
            "thread the needle", "spinal twist", "shoulder dislocate"
        ]
        guard mobilityTerms.contains(where: { normalized.contains($0) }) else { return nil }
        if normalized.contains("wrist") { return MovementCatalog.aliasIndex["wrist prep flow"] }
        if normalized.contains("shoulder") { return MovementCatalog.aliasIndex["shoulder dislocates"] }
        if normalized.contains("thoracic") || normalized.contains("thread") || normalized.contains("twist") { return MovementCatalog.aliasIndex["thoracic rotation"] }
        if normalized.contains("hamstring") || normalized.contains("fold") { return MovementCatalog.aliasIndex["hamstring fold"] }
        if normalized.contains("pigeon") || normalized.contains("figure") { return MovementCatalog.aliasIndex["pigeon pose"] }
        if normalized.contains("frog") { return MovementCatalog.aliasIndex["frog stretch"] }
        if normalized.contains("cat") { return MovementCatalog.aliasIndex["cat cow"] }
        return MovementCatalog.aliasIndex["hip flexor stretch"]
    }

    private static func inferAliasBase(from normalized: String) -> MovementDefinition? {
        if (normalized.contains("pull up") || normalized.contains("pullup")) {
            if normalized.contains("machine") && normalized.contains("assisted") {
                return MovementCatalog.aliasIndex["assisted pull up machine"]
            }
            if normalized.contains("assisted") || normalized.contains("band assisted") || normalized.contains("banded") {
                return MovementCatalog.aliasIndex["assisted pull up band"]
            }
            if normalized.contains("negative") || normalized.contains("eccentric") {
                return MovementCatalog.aliasIndex["negative pull up"]
            }
        }

        let stripped = normalized
            .replacingOccurrences(of: "band assisted", with: "")
            .replacingOccurrences(of: "assisted", with: "")
            .replacingOccurrences(of: "negative", with: "")
            .replacingOccurrences(of: "tempo", with: "")
            .replacingOccurrences(of: "strict", with: "")
            .replacingOccurrences(of: "weighted", with: "")
            .replacingOccurrences(of: "wall supported", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return MovementCatalog.aliasIndex[stripped]
    }

    private static func variationTags(for normalized: String) -> Set<MovementVariationTag> {
        var tags: Set<MovementVariationTag> = []
        if normalized.contains("assisted") || normalized.contains("band") { tags.insert(.assisted) }
        if normalized.contains("negative") { tags.insert(.negative) }
        if normalized.contains("tempo") { tags.insert(.tempo) }
        if normalized.contains("weighted") || normalized.contains("loaded") { tags.insert(.weighted) }
        if normalized.contains("strict") { tags.insert(.strict) }
        if normalized.contains("explosive") || normalized.contains("clapping") { tags.insert(.explosive) }
        if normalized.contains("wall") { tags.insert(.wallSupported) }
        if normalized.contains("one arm") || normalized.contains("single leg") || normalized.contains("one leg") || normalized.contains("suitcase") { tags.insert(.unilateral) }
        if normalized.contains("elevated") || normalized.contains("incline") || normalized.contains("box") { tags.insert(.elevated) }
        if normalized.contains("interval") || normalized.contains("repeat") { tags.insert(.interval) }
        return tags
    }
}
