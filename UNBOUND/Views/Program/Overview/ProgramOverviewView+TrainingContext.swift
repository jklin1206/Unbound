import SwiftUI

extension ProgramOverviewView {
    func activeTrainingContextOverride(
        program: TrainingProgram,
        date: Date
    ) -> ProgramTrainingContextOverride? {
        _ = temporaryContextRevision
        guard let userId = services.auth.currentUserId else { return nil }
        return ProgramTrainingContextStore.shared.activeDailyContext(
            userId: userId,
            programId: program.id,
            date: date
        )
    }

    func pendingNextBlockContext(
        program: TrainingProgram
    ) -> ProgramTrainingContextOverride? {
        _ = temporaryContextRevision
        guard let userId = services.auth.currentUserId else { return nil }
        return ProgramTrainingContextStore.shared.pendingNextBlockContext(
            userId: userId,
            programId: program.id
        )
    }

    func resolvedTrainingContext(
        _ override: ProgramTrainingContextOverride
    ) -> ProgramTrainingContextResolution {
        ProgramFocusSwitchCoordinator.resolvedContext(
            override: override,
            profile: currentProfile
        )
    }
}
