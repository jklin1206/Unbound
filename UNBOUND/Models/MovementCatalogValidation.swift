import Foundation

enum MovementCatalogValidation {
    static func issues() -> [String] {
        var issues: [String] = []
        let definitions = MovementCatalog.definitions
        let definitionsById = MovementCatalog.definitionsById
        let skillIds = Set(SkillGraph.shared.nodes.map(\.id))
        let exerciseNames = Set(ExerciseCatalog.allExercises.map(\.name))

        let duplicateIds = duplicateValues(definitions.map(\.id))
        if !duplicateIds.isEmpty {
            issues.append("Duplicate movement ids: \(duplicateIds.joined(separator: ", "))")
        }

        let canonicalExercises = definitions.filter { $0.role == .canonicalExercise }
        if canonicalExercises.count != ExerciseCatalog.allExercises.count {
            issues.append("Canonical exercise count \(canonicalExercises.count) does not match ExerciseCatalog count \(ExerciseCatalog.allExercises.count).")
        }

        for definition in definitions {
            if let variantOf = definition.variantOfMovementId {
                guard let base = definitionsById[variantOf] else {
                    issues.append("\(definition.id) variantOfMovementId points at missing \(variantOf).")
                    continue
                }
                if definition.rankStandardMovementId != variantOf {
                    issues.append("\(definition.id) variant and rank standard disagree: \(variantOf) vs \(definition.rankStandardMovementId).")
                }
                if base.rankStandardMovementId != base.id {
                    issues.append("\(definition.id) rolls into another variant instead of direct standard \(base.id).")
                }
                if !base.rankable {
                    issues.append("\(definition.id) rolls into non-rankable base \(base.id).")
                }
            }

            for skillId in definition.skillAssociations where !skillIds.contains(skillId) {
                issues.append("\(definition.id) links missing skill \(skillId).")
            }

            if definition.role == .canonicalExercise {
                if definition.rankTemplate == .unranked {
                    issues.append("\(definition.id) is canonical but unranked.")
                }
                if definition.equipment.isEmpty {
                    issues.append("\(definition.id) has no equipment.")
                }
                if definition.muscleGroups.isEmpty {
                    issues.append("\(definition.id) has no muscle groups.")
                }
                if definition.bodyRegions.isEmpty {
                    issues.append("\(definition.id) has no body regions.")
                }
                if definition.substitutionGroup.isEmpty {
                    issues.append("\(definition.id) has no substitution group.")
                }
                if definition.attributeWeights.isEmpty {
                    issues.append("\(definition.id) has no attribute weights.")
                } else {
                    let sum = definition.attributeWeights.values.reduce(0, +)
                    if abs(sum - 1.0) > 0.02 {
                        issues.append("\(definition.id) attribute weights sum to \(sum), expected 1.0.")
                    }
                }
                issues.append(contentsOf: loggerIssues(for: definition))
            }
        }

        for exercise in ExerciseCatalog.allExercises {
            if let substitute = exercise.defaultSubstitute,
               !exerciseNames.contains(substitute) {
                issues.append("\(exercise.name) default substitute points at missing \(substitute).")
            }
        }

        issues.append(contentsOf: policyIssues(definitions: definitions))
        return issues.sorted()
    }

    private static func loggerIssues(for definition: MovementDefinition) -> [String] {
        if definition.rankTemplate == .holdControl && definition.loggerMode != .hold {
            return ["\(definition.id) is Hold / Control but does not use hold logger."]
        }
        if definition.rankTemplate == .bodyweightReps && definition.loggerMode != .bodyweightSets {
            return ["\(definition.id) is Bodyweight Reps but does not use bodyweight set logger."]
        }
        if [.barbellStrength, .machineStrength, .weightedBodyweight].contains(definition.rankTemplate),
           definition.loggerMode != .strengthSets,
           definition.loggerMode != .bodyweightSets {
            return ["\(definition.id) is strength-ranked but uses \(definition.loggerMode.rawValue)."]
        }
        return []
    }

    private static func policyIssues(definitions: [MovementDefinition]) -> [String] {
        var issues: [String] = []
        let byId = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })

        let holdIds = [
            "exercise.l-sit",
            "exercise.l-sit-tucked",
            "exercise.tuck-front-lever",
            "exercise.advanced-tuck-front-lever"
        ]
        for id in holdIds {
            guard let definition = byId[id] else { continue }
            if definition.rankTemplate != .holdControl || definition.loggerMode != .hold {
                issues.append("\(id) must be Hold / Control with the hold logger.")
            }
        }

        if let hollowRock = byId["exercise.hollow-rock"],
           hollowRock.rankTemplate != .bodyweightReps || hollowRock.loggerMode != .bodyweightSets {
            issues.append("exercise.hollow-rock must stay Bodyweight Reps with the rep logger.")
        }

        for definition in definitions where definition.movementSlot == .horizontalPull {
            if definition.skillAssociations.contains("pp.pullup") || definition.skillAssociations.contains("pp.strict-pullup") {
                issues.append("\(definition.id) is horizontal pull but credits vertical pull skills.")
            }
        }

        for id in ["exercise.straight-arm-pulldown", "exercise.machine-pullover"] {
            if let definition = byId[id],
               definition.skillAssociations.contains("pp.pullup") || definition.skillAssociations.contains("pp.strict-pullup") {
                issues.append("\(id) is lat isolation but credits pull-up skill.")
            }
        }

        for id in ["exercise.assisted-dip-machine", "exercise.dip-machine"] {
            if byId[id]?.skillAssociations.contains("pp.muscle-up") == true {
                issues.append("\(id) should not credit muscle-up skill progression.")
            }
        }

        for id in ["exercise.dip", "exercise.straight-bar-dip"] {
            if byId[id]?.skillAssociations.contains("pp.muscle-up") != true {
                issues.append("\(id) should credit muscle-up skill context.")
            }
        }

        let expectedEquipment: [(String, MovementEquipment, MovementEquipment)] = [
            ("exercise.safety-bar-squat", .barbell, .bodyweight),
            ("exercise.arnold-press", .dumbbell, .bodyweight),
            ("exercise.straight-bar-tricep-pushdown", .cable, .barbell)
        ]
        for (id, required, forbidden) in expectedEquipment {
            guard let definition = byId[id] else { continue }
            if !definition.equipment.contains(required) {
                issues.append("\(id) missing required equipment \(required.rawValue).")
            }
            if definition.equipment.contains(forbidden) {
                issues.append("\(id) should not include equipment \(forbidden.rawValue).")
            }
        }

        if byId["exercise.hip-adductor-machine"]?.movementSlot != .squat {
            issues.append("exercise.hip-adductor-machine should live in Squat / Quad, not Hinge / Posterior.")
        }

        if byId["exercise.hanging-knee-raise"]?.skillAssociations.contains("cl.hollow-body-30") != true {
            issues.append("exercise.hanging-knee-raise should link to cl.hollow-body-30 if hanging leg raise does.")
        }

        return issues
    }

    private static func duplicateValues(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var duplicates: Set<String> = []
        for value in values {
            if seen.contains(value) {
                duplicates.insert(value)
            } else {
                seen.insert(value)
            }
        }
        return duplicates.sorted()
    }
}
