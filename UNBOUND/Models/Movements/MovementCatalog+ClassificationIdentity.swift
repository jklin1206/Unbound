import Foundation

// Rank-standard identity: which canonical movement a logged exercise counts as
// (variant roll-ups, exercise/skill twins, drill canonical standards) plus the
// attribute-weight feed each exercise banks into.
extension MovementCatalog {
    static let variantRankStandardNames: [String: String] = [
        "lat pulldown neutral": "lat pulldown",
        "wide grip lat pulldown": "lat pulldown",
        "close grip lat pulldown": "lat pulldown",
        "reverse grip lat pulldown": "lat pulldown",
        "single arm pulldown": "lat pulldown",
        "low to high cable fly": "cable fly",
        "high to low cable fly": "cable fly",
        "plate loaded chest press": "machine chest press",
        "hammer strength chest press": "machine chest press",
        "converging chest press": "machine chest press",
        "plate loaded shoulder press": "seated machine press",
        "wide grip cable row": "cable row seated",
        "single arm cable row": "cable row seated",
        "plate loaded row": "machine row",
        "hammer strength row": "machine row",
        "hammer strength low row": "machine row",
        "machine chest supported row": "machine row",
        "rope cable curl": "cable curl",
        "rope hammer curl": "hammer curl",
        "straight bar tricep pushdown": "tricep pushdown",
        "rope tricep pushdown": "tricep pushdown",
        "rope overhead tricep extension": "overhead tricep extension",
        "single leg extension": "leg extension",
        "leg curl seated": "leg curl lying",
        "single leg curl": "leg curl lying",
        "smith machine calf raise": "standing calf raise",
        "leg press calf raise": "standing calf raise"
    ]

    static func variantOfMovementId(for exercise: CatalogExercise) -> String? {
        guard let baseName = variantRankStandardNames[normalized(exercise.name)] else { return nil }
        return "exercise.\(slug(baseName))"
    }

    static func rankStandardMovementId(for exercise: CatalogExercise) -> String {
        variantOfMovementId(for: exercise) ?? "exercise.\(slug(exercise.name))"
    }

    /// The authoritative "this library exercise IS this skill's own movement"
    /// join - beyond the precise `skillId` that drill/target definitions already
    /// carry. Used by `MovementProofMatcher`/`owningSkillId` so logging the
    /// library exercise advances the SAME rank as the drill or the skill block
    /// (the "one rank, fed from any surface" unification), and (P4) so the rank
    /// library can fold by this explicit map instead of fragile name-matching.
    ///
    /// Only the movement that IS the skill belongs here, never a merely-
    /// associated one or a regression: the Hollow Body Hold exercise IS the
    /// hollow-body hold, but "Hollow Rock" (dynamic) and "Tuck L-Sit" (an easier
    /// regression) are excluded - they keep their own identity.
    ///
    /// Every pair is metric-compatible (a hold skill twins only a hold exercise,
    /// a rep/loaded skill only a rep/loaded exercise), audited via
    /// `MovementFoldMapDumpTests`. `CanonicalTwinMapTests` locks soundness +
    /// completeness so the map can never silently drift as the catalog grows.
    static let exerciseSkillTwins: [String: String] = [
        // Calisthenics push / holds
        "exercise.pushup": "cal.pushup",
        "exercise.incline-pushup": "cal.incline-pushup",
        "exercise.decline-pushup": "cal.decline-pushup",
        "exercise.diamond-pushup": "cal.diamond-pushup",
        "exercise.archer-pushup": "cal.archer-pushup",
        "exercise.pike-pushup": "cal.pike-pushup",
        "exercise.pseudo-planche-pushup": "cal.pseudo-planche-pushup",
        "exercise.plank": "cal.plank-30",
        "exercise.l-sit": "cal.l-sit-10",
        // Core levers
        "exercise.hollow-hold": "cl.hollow-body-30",
        "exercise.dragon-flag": "cl.dragon-flag",
        "exercise.decline-situp": "cl.decline-situp",
        "exercise.hanging-knee-raise": "cl.hanging-knee-raise",
        "exercise.hanging-leg-raise": "cl.hanging-leg-raise",
        "exercise.tuck-front-lever": "cl.tuck-front-lever",
        // Pull power
        "exercise.pullup": "pp.pullup",
        "exercise.chin-up": "pp.chin-up",
        "exercise.weighted-pullup": "pp.weighted-pullup",
        "exercise.muscle-up": "pp.muscle-up",
        // Leg dominance
        "exercise.pistol-squat": "ld.pistol-squat",
        "exercise.weighted-pistol": "ld.weighted-pistol",
        "exercise.shrimp-squat": "ld.shrimp-squat",
        "exercise.split-squat": "ld.split-squat",
        "exercise.bulgarian-split-squat": "ld.bulgarian-split-squat",
        "exercise.step-up": "ld.step-up",
        "exercise.glute-bridge": "ld.glute-bridge",
        "exercise.goblet-squat": "ld.goblet-20",
        "exercise.nordic-curl": "ld.nordic-curl",
        "exercise.bodyweight-leg-extension": "ld.leg-extensions"
    ]

    /// Skill drills that ARE the same physical movement as a rankable library
    /// exercise route their XP into that ONE canonical standard, so a single
    /// movement never banks into two `movement_progress` rows (P3 of the
    /// movement unification). Only true-twin drills (the drill == the skill's
    /// criterion movement) that ALSO have an exercise twin belong here -
    /// regressions like Tuck L-Sit keep their own standard.
    ///
    /// Today this is just the hollow body hold (the only movement with two
    /// rankable true-twins). The skill-drill factory reads this to set the
    /// drill's `rankStandardMovementId`, and
    /// `MovementProgressConsolidationMigration` merges any pre-existing split
    /// rows on upgrade. `CanonicalTwinMapTests` locks the routing.
    static let skillDrillCanonicalStandard: [String: String] = [
        "skill-drill.hollow-body-hold": "exercise.hollow-hold"
    ]

    /// The skill a movement *is* (its own rank source), or nil if it is not a
    /// skill movement. Drills and skill targets carry a precise `skillId`;
    /// exercise twins resolve through `exerciseSkillTwins`. Deliberately
    /// excludes mere `skillAssociations`, which are too broad — Hollow Rock and
    /// Hanging Knee Raise both associate with the hollow-body skill yet are
    /// distinct movements that must not advance it.
    static func owningSkillId(forMovementId movementId: String?) -> String? {
        guard let movementId else { return nil }
        if let definition = definition(for: movementId),
           let skillId = definition.skillId,
           SkillGraph.shared.node(id: skillId) != nil {
            return skillId
        }
        return exerciseSkillTwins[movementId]
    }

    static let exerciseAttributeWeights: [String: [AttributeKey: Double]] = {
        guard let url = Bundle.main.url(forResource: "AttributeContributions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(AttributePayload.self, from: data)
        else { return [:] }

        return payload.exercises.mapValues { dict in
            var out: [AttributeKey: Double] = [:]
            if let value = dict.power, value > 0 { out[.power] = value }
            if let value = dict.vitality ?? dict.legacyAgility, value > 0 { out[.vitality] = value }
            if let value = dict.control, value > 0 { out[.control] = value }
            if let value = dict.endurance, value > 0 { out[.endurance] = value }
            if let value = dict.mobility, value > 0 { out[.mobility] = value }
            if let value = dict.explosiveness, value > 0 { out[.explosiveness] = value }
            return out
        }
    }()

    static func attributeWeights(for exerciseName: String) -> [AttributeKey: Double] {
        exerciseAttributeWeights[exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] ?? [:]
    }
}
