import Foundation

enum ExerciseCategory: String, CaseIterable, Codable {
    case compound
    case isolation
    case bodyweight
    case machine
    case cable

    var displayName: String {
        rawValue.capitalized
    }
}

struct ExerciseLibraryItem: Identifiable {
    let id: String
    let name: String
    let canonicalName: String
    let category: ExerciseCategory
    let muscleGroups: [MuscleGroup]
    let equipment: [String]
    let isCompound: Bool
    let rankTemplate: MovementRankTemplate
    let loggerMode: MovementLoggerMode
    let movementSlot: MovementSlot
    let rankStandardMovementId: String
    let isRankable: Bool

    init(
        id: String,
        name: String,
        canonicalName: String? = nil,
        category: ExerciseCategory,
        muscleGroups: [MuscleGroup],
        equipment: [String],
        isCompound: Bool,
        rankTemplate: MovementRankTemplate = .unranked,
        loggerMode: MovementLoggerMode = .strengthSets,
        movementSlot: MovementSlot = .routine,
        rankStandardMovementId: String? = nil,
        isRankable: Bool = false
    ) {
        self.id = id
        self.name = name
        self.canonicalName = canonicalName ?? name.lowercased()
        self.category = category
        self.muscleGroups = muscleGroups
        self.equipment = equipment
        self.isCompound = isCompound
        self.rankTemplate = rankTemplate
        self.loggerMode = loggerMode
        self.movementSlot = movementSlot
        self.rankStandardMovementId = rankStandardMovementId ?? id
        self.isRankable = isRankable
    }

    init(definition: MovementDefinition) {
        let canonical = definition.canonicalExerciseName ?? MovementCatalog.normalized(definition.displayName)
        self.init(
            id: definition.id,
            name: definition.displayName,
            canonicalName: canonical,
            category: ExerciseLibrary.category(for: definition),
            muscleGroups: definition.muscleGroups,
            equipment: ExerciseLibrary.equipmentLabels(for: definition),
            isCompound: ExerciseLibrary.isCompound(definition),
            rankTemplate: definition.rankTemplate,
            loggerMode: definition.loggerMode,
            movementSlot: definition.movementSlot,
            rankStandardMovementId: definition.rankStandardMovementId,
            isRankable: definition.rankable && definition.rankTemplate != .unranked
        )
    }

    var normalizedName: String {
        MovementCatalog.normalized(canonicalName)
    }

    var preferenceKey: String {
        canonicalName.lowercased()
    }

    var preferenceLookupKeys: [String] {
        ExercisePreferenceLookup.keys(for: self)
    }

    var metadataSummary: String {
        [
            movementSlot.displayName,
            rankTemplate.displayName,
            loggerMode.displayName
        ].joined(separator: " · ")
    }

    var equipmentSummary: String {
        equipment.prefix(3).joined(separator: " · ")
    }
}

enum ExerciseLibrary {
    static var all: [ExerciseLibraryItem] {
        MovementCatalog.legacyExercises
            .sorted { lhs, rhs in
                if lhs.movementSlot != rhs.movementSlot {
                    return slotOrder(lhs.movementSlot) < slotOrder(rhs.movementSlot)
                }
                return lhs.displayName < rhs.displayName
            }
            .map(ExerciseLibraryItem.init(definition:))
    }

    static func grouped() -> [(String, [ExerciseLibraryItem])] {
        let slots: [MovementSlot] = [
            .squat,
            .hinge,
            .horizontalPush,
            .verticalPush,
            .horizontalPull,
            .verticalPull,
            .arms,
            .core,
            .calves
        ]

        return slots.compactMap { slot in
            let items = all.filter { $0.movementSlot == slot }
            return items.isEmpty ? nil : (slot.displayName, items)
        }
    }

    static func category(for definition: MovementDefinition) -> ExerciseCategory {
        let equipment = Set(definition.equipment)
        if equipment.contains(.cable) {
            return .cable
        }
        if equipment.contains(.machine) || equipment.contains(.smithMachine) {
            return .machine
        }
        if definition.blockKind == .bodyweight
            || equipment.contains(.bodyweight)
            || equipment.contains(.pullupBar)
            || equipment.contains(.dipStation)
            || equipment.contains(.rings) {
            return .bodyweight
        }
        return isCompound(definition) ? .compound : .isolation
    }

    static func isCompound(_ definition: MovementDefinition) -> Bool {
        let name = MovementCatalog.normalized(definition.displayName)
        let isolationTerms = [
            "curl", "extension", "pushdown", "fly", "raise", "crunch",
            "calf", "adductor", "abductor", "kickback", "pullover"
        ]
        if isolationTerms.contains(where: { name.contains($0) }) {
            return false
        }
        switch definition.movementSlot {
        case .squat, .hinge, .horizontalPush, .verticalPush, .horizontalPull, .verticalPull, .carry:
            return true
        case .arms, .core, .calves, .cardio, .mobility, .routine, .skill:
            return definition.muscleGroups.count > 1 && definition.rankTemplate != .machineStrength
        }
    }

    static func equipmentLabels(for definition: MovementDefinition) -> [String] {
        let labels = definition.equipment
            .filter { $0 != .bodyweight || definition.equipment.count == 1 }
            .map(\.displayName)
        return labels.isEmpty ? ["Bodyweight"] : labels
    }

    static func slotOrder(_ slot: MovementSlot) -> Int {
        switch slot {
        case .squat: return 0
        case .hinge: return 1
        case .horizontalPush: return 2
        case .verticalPush: return 3
        case .horizontalPull: return 4
        case .verticalPull: return 5
        case .arms: return 6
        case .core: return 7
        case .calves: return 8
        case .carry: return 9
        case .cardio: return 10
        case .mobility: return 11
        case .routine: return 12
        case .skill: return 13
        }
    }
}

enum ExercisePreferenceLookup {
    static func keys(for item: ExerciseLibraryItem) -> [String] {
        keys(for: item.canonicalName, displayName: item.name, movementId: item.id)
    }

    static func keys(for exercise: CatalogExercise) -> [String] {
        keys(for: exercise.name, displayName: exercise.displayName, movementId: nil)
    }

    static func keys(for definition: MovementDefinition) -> [String] {
        keys(
            for: definition.canonicalExerciseName ?? definition.displayName,
            displayName: definition.displayName,
            movementId: definition.id
        )
    }

    static func keys(for preference: ExercisePreference) -> [String] {
        keys(for: preference.exerciseName, displayName: preference.displayName, movementId: nil)
    }

    static func index(_ preferences: [ExercisePreference]) -> [String: ExercisePreference] {
        var map: [String: ExercisePreference] = [:]
        for preference in preferences {
            for key in keys(for: preference) {
                map[key] = preference
            }
        }
        return map
    }

    static func normalizedKey(_ value: String) -> String {
        MovementCatalog.normalized(value)
    }

    static func keys(
        for rawName: String,
        displayName: String?,
        movementId: String?
    ) -> [String] {
        var values = [rawName]
        if let displayName {
            values.append(displayName)
        }
        if let movementId {
            values.append(movementId)
        }

        let displayDefinition = displayName.flatMap { MovementCatalog.canonicalExercise(named: $0) }
        if let definition = MovementCatalog.canonicalExercise(named: rawName) ?? displayDefinition {
            values.append(definition.displayName)
            if let canonical = definition.canonicalExerciseName {
                values.append(canonical)
            }
            values.append(definition.id)
        }

        var seen: Set<String> = []
        return values
            .map(normalizedKey)
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }
}

extension MovementLoggerMode {
    var displayName: String {
        switch self {
        case .strengthSets: return "Strength Logger"
        case .bodyweightSets: return "Bodyweight Logger"
        case .skillAttempts: return "Skill Attempts"
        case .hold: return "Hold Timer"
        case .cardio: return "Cardio Logger"
        case .carry: return "Carry Logger"
        case .mobility: return "Mobility Timer"
        case .routinePlayer: return "Routine Player"
        }
    }
}
