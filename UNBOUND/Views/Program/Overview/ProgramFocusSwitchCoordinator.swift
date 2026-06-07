import Foundation

enum ProgramFocusSwitchCoordinator {
    static func effectiveTrainingStyle(profile: UserProfile?) -> TrainingStyle {
        if let override = profile?.trainingStyleOverride {
            return override
        }
        let equipment = profile?.equipment ?? []
        let styles = Set(profile?.exerciseStyles ?? [])
        let bodyweightGear: Set<Equipment> = [.bodyweight, .pullupBar, .bands, .dipStation, .rings]
        let selectedEquipment = Set(equipment)
        let wantsCalisthenics = styles.contains(.calisthenics)
        let wantsMachines = styles.contains(.machines) || equipment.contains(.machines)
        let wantsFreeWeights = styles.contains(.compoundLifts)
            || equipment.contains(.barbell)
            || equipment.contains(.dumbbells)
            || equipment.contains(.bench)

        if wantsCalisthenics && (wantsFreeWeights || wantsMachines) {
            return .hybrid
        }
        if wantsCalisthenics || (!selectedEquipment.isEmpty && selectedEquipment.isSubset(of: bodyweightGear)) {
            return .bodyweight
        }
        if wantsMachines && wantsFreeWeights {
            return .hybrid
        }
        if wantsMachines {
            return .machines
        }
        if wantsFreeWeights {
            return .freeWeights
        }
        return .hybrid
    }

    static func currentEquipmentFallback(
        profile: UserProfile?,
        program: TrainingProgram
    ) -> [Equipment] {
        if let equipment = profile?.equipment, !equipment.isEmpty {
            return equipment
        }
        let resolved = program.requiredEquipment.compactMap { Equipment(rawValue: $0) }
        return resolved.isEmpty ? [.bodyweight] : resolved
    }

    static func resolvedContext(
        override: ProgramTrainingContextOverride,
        profile: UserProfile?
    ) -> ProgramTrainingContextResolution {
        ProgramTrainingContextResolver.resolve(
            selection: override.selection,
            currentStyle: profile?.trainingStyleOverride,
            currentEquipment: Set(profile?.equipment ?? []),
            currentExerciseStyles: Set(profile?.exerciseStyles ?? []),
            currentExperience: profile?.experience
        )
    }

    static func updatedProfile(
        from profile: UserProfile,
        generatedProgram: TrainingProgram,
        resolution: ProgramTrainingContextResolution
    ) -> UserProfile {
        var updatedProfile = profile
        updatedProfile.currentProgramId = generatedProgram.id
        updatedProfile.trainingStyleOverride = resolution.trainingStyle
        updatedProfile.equipment = resolution.sortedEquipment
        updatedProfile.exerciseStyles = resolution.sortedExerciseStyles
        if let experience = resolution.experience {
            updatedProfile.experience = experience
        }
        return updatedProfile
    }
}
