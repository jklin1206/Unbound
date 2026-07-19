// UNBOUND/Models/TrainingStyle.swift
import Foundation

enum TrainingStyle: String, Codable, CaseIterable, Identifiable {
    case bodyweight        // calisthenics, minimal equipment
    case freeWeights       // dumbbells + barbell + bench
    case hybrid            // mix of bodyweight + weights
    case machines          // cable / machine / gym

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bodyweight: return "Bodyweight / Calisthenics"
        case .freeWeights: return "Free weights"
        case .hybrid: return "Hybrid"
        case .machines: return "Gym machines"
        }
    }

    /// Default training style for users without equipment preference.
    static var `default`: TrainingStyle { .hybrid }
}

enum ProgramTrainingContextScope: String, Codable, CaseIterable, Identifiable {
    case todayOnly
    case thisWeek
    case nextBlock
    case ongoing
    case freeformManual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .todayOnly: return "Today only"
        case .thisWeek: return "This week"
        case .nextBlock: return "Next arc"
        case .ongoing: return "Active arc"
        case .freeformManual: return "Freeform"
        }
    }

    var usesDailyModifier: Bool {
        switch self {
        case .todayOnly, .thisWeek:
            return true
        case .nextBlock, .ongoing, .freeformManual:
            return false
        }
    }

    var shouldRegenerateProgram: Bool {
        switch self {
        case .nextBlock, .ongoing:
            return true
        case .todayOnly, .thisWeek, .freeformManual:
            return false
        }
    }

    var mutatesProfileImmediately: Bool {
        self == .ongoing
    }
}

enum ProgramTrainingContextMode: String, Codable, CaseIterable, Identifiable {
    case automatic
    case calisthenics
    case lifting
    case hybrid
    case machines
    case freeform

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .calisthenics: return "Calisthenics"
        case .lifting: return "Lifting"
        case .hybrid: return "Hybrid"
        case .machines: return "Machines"
        case .freeform: return "Freeform"
        }
    }
}

struct ProgramTrainingContextSelection: Codable, Hashable {
    var scope: ProgramTrainingContextScope
    var mode: ProgramTrainingContextMode
    var equipment: Set<Equipment>
    var experience: Experience?

    init(
        scope: ProgramTrainingContextScope,
        mode: ProgramTrainingContextMode,
        equipment: Set<Equipment> = [],
        experience: Experience? = nil
    ) {
        self.scope = scope
        self.mode = mode
        self.equipment = equipment
        self.experience = experience
    }
}

struct ProgramTrainingContextResolution: Equatable {
    let scope: ProgramTrainingContextScope
    let mode: ProgramTrainingContextMode
    let trainingStyle: TrainingStyle
    let equipment: Set<Equipment>
    let exerciseStyles: Set<ExerciseStyle>
    let experience: Experience?
    let shouldRegenerateProgram: Bool
    let shouldMutateProfile: Bool
    let usesDailyModifier: Bool
    let preservesSavedWorkouts: Bool
    let requiresManualWorkoutControl: Bool

    var sortedEquipment: [Equipment] {
        ProgramTrainingContextResolver.sortedEquipment(equipment)
    }

    var sortedExerciseStyles: [ExerciseStyle] {
        ProgramTrainingContextResolver.sortedExerciseStyles(exerciseStyles)
    }

    var dailyModifierEquipment: [Equipment]? {
        usesDailyModifier ? sortedEquipment : nil
    }
}

enum ProgramTrainingContextResolver {
    static let bodyweightEquipment: Set<Equipment> = [
        .bodyweight,
        .pullupBar,
        .bands,
        .dipStation,
        .rings
    ]

    static let profilePreservedStyles: Set<ExerciseStyle> = [
        .cardioIntervals,
        .steadyCardio,
        .mobility,
        .sports,
        .plyometrics
    ]

    static func resolve(
        selection: ProgramTrainingContextSelection,
        currentStyle: TrainingStyle? = nil,
        currentEquipment: Set<Equipment> = [],
        currentExerciseStyles: Set<ExerciseStyle> = [],
        currentExperience: Experience? = nil
    ) -> ProgramTrainingContextResolution {
        let equipment = resolvedEquipment(
            mode: selection.mode,
            selectedEquipment: selection.equipment,
            currentEquipment: currentEquipment
        )
        let style = resolvedStyle(
            mode: selection.mode,
            equipment: equipment,
            currentStyle: currentStyle
        )
        let styles = resolvedExerciseStyles(
            mode: selection.mode,
            equipment: equipment,
            currentExerciseStyles: currentExerciseStyles
        )
        // The ability-level pick is authoritative in every mode. It used to be
        // honored only for calisthenics/hybrid, which left lifting/machines
        // users pinned to their onboarding experience with no way out.
        let experience = selection.experience ?? currentExperience
        let isManual = selection.mode == .freeform || selection.scope == .freeformManual
        let canRegenerate = selection.scope.shouldRegenerateProgram && !isManual

        return ProgramTrainingContextResolution(
            scope: selection.scope,
            mode: selection.mode,
            trainingStyle: style,
            equipment: equipment,
            exerciseStyles: styles,
            experience: experience,
            shouldRegenerateProgram: canRegenerate,
            shouldMutateProfile: selection.scope.mutatesProfileImmediately && !isManual,
            usesDailyModifier: selection.scope.usesDailyModifier && !isManual,
            preservesSavedWorkouts: true,
            requiresManualWorkoutControl: isManual
        )
    }

    static func sortedEquipment(_ equipment: Set<Equipment>) -> [Equipment] {
        let order: [Equipment] = [
            .fullGym,
            .machines,
            .barbell,
            .dumbbells,
            .bench,
            .pullupBar,
            .dipStation,
            .rings,
            .bands,
            .bodyweight,
            .homeWeights
        ]
        return order.filter { equipment.contains($0) }
    }

    static func sortedExerciseStyles(_ styles: Set<ExerciseStyle>) -> [ExerciseStyle] {
        ExerciseStyle.allCases.filter { styles.contains($0) }
    }

    private static func resolvedEquipment(
        mode: ProgramTrainingContextMode,
        selectedEquipment: Set<Equipment>,
        currentEquipment: Set<Equipment>
    ) -> Set<Equipment> {
        let fallback = currentEquipment.isEmpty ? Set([Equipment.bodyweight]) : currentEquipment
        let base = selectedEquipment.isEmpty ? fallback : selectedEquipment

        switch mode {
        case .automatic, .freeform:
            return base.isEmpty ? [.bodyweight] : base

        case .calisthenics:
            var gear = base.intersection(bodyweightEquipment)
            gear.insert(.bodyweight)
            return gear

        case .lifting:
            var gear = base.subtracting(bodyweightEquipment)
            if gear.isEmpty {
                gear = [.dumbbells, .bench]
            }
            return gear

        case .hybrid:
            var gear = base
            gear.insert(.bodyweight)
            if !hasExternalLoadAccess(gear) && !hasMachineAccess(gear) {
                gear.insert(.dumbbells)
            }
            return gear

        case .machines:
            let gear = base.intersection([.fullGym, .machines])
            return gear.isEmpty ? [.machines] : gear
        }
    }

    private static func resolvedStyle(
        mode: ProgramTrainingContextMode,
        equipment: Set<Equipment>,
        currentStyle: TrainingStyle?
    ) -> TrainingStyle {
        switch mode {
        case .automatic, .freeform:
            return currentStyle ?? inferredStyle(for: equipment)
        case .calisthenics:
            return .bodyweight
        case .lifting:
            if hasMachineAccess(equipment) && !hasExternalLoadAccess(equipment) {
                return .machines
            }
            return .freeWeights
        case .hybrid:
            return .hybrid
        case .machines:
            return .machines
        }
    }

    private static func resolvedExerciseStyles(
        mode: ProgramTrainingContextMode,
        equipment: Set<Equipment>,
        currentExerciseStyles: Set<ExerciseStyle>
    ) -> Set<ExerciseStyle> {
        if mode == .automatic || mode == .freeform {
            return currentExerciseStyles
        }

        let preserved = currentExerciseStyles.intersection(profilePreservedStyles)
        switch mode {
        case .automatic, .freeform:
            return currentExerciseStyles
        case .calisthenics:
            return preserved.union([.calisthenics])
        case .lifting:
            if hasMachineAccess(equipment) && !hasExternalLoadAccess(equipment) {
                return preserved.union([.machines])
            }
            return preserved.union([.compoundLifts])
        case .hybrid:
            var styles = preserved.union([.compoundLifts, .calisthenics])
            if hasMachineAccess(equipment) {
                styles.insert(.machines)
            }
            return styles
        case .machines:
            return preserved.union([.machines])
        }
    }

    private static func inferredStyle(for equipment: Set<Equipment>) -> TrainingStyle {
        if !equipment.isEmpty && equipment.isSubset(of: bodyweightEquipment) {
            return .bodyweight
        }
        if hasMachineAccess(equipment) && !hasExternalLoadAccess(equipment) {
            return .machines
        }
        if hasMachineAccess(equipment) && hasExternalLoadAccess(equipment) {
            return .hybrid
        }
        if hasExternalLoadAccess(equipment) {
            return .freeWeights
        }
        return .hybrid
    }

    private static func hasExternalLoadAccess(_ equipment: Set<Equipment>) -> Bool {
        !equipment.intersection([.fullGym, .barbell, .dumbbells, .bench, .homeWeights]).isEmpty
    }

    private static func hasMachineAccess(_ equipment: Set<Equipment>) -> Bool {
        equipment.contains(.fullGym) || equipment.contains(.machines)
    }
}
