import SwiftUI

extension WorkoutReadyView {
    var addControls: some View {
        let nextSkill = nextScheduledSkillId
        return VStack(spacing: 10) {
            Button {
                addNextScheduledSkill()
            } label: {
                Label(nextSkill == nil ? "All Scheduled Skills Added" : "Add Scheduled Skill", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(nextSkill == nil)
            .accessibilityIdentifier("workoutReady.addScheduledSkill")

            Button {
                showingBlockBuilder = true
            } label: {
                Label("Add Mixed Block", systemImage: "plus.square.on.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("workoutReady.addMixedBlock")
        }
    }

    var startControls: some View {
        VStack(spacing: 10) {
            if !isFixedProtocolDraft {
                Button {
                    saveRecentDraft()
                } label: {
                    Label("Save Custom Draft", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(draft.blocks.isEmpty)
                .accessibilityIdentifier("workoutReady.saveDraft")
            }

            Button {
                guard hasWorkoutCompatibleBlocks, !isLaunchingWorkout else { return }
                isLaunchingWorkout = true
                saveRecentDraftIfCustom()
                let launchDraft = draft
                DispatchQueue.main.async {
                    activeWorkoutDraft = launchDraft
                }
            } label: {
                Label(startButtonTitle, systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasWorkoutCompatibleBlocks)
            .opacity(hasWorkoutCompatibleBlocks ? 1 : 0.45)
            .accessibilityIdentifier("workoutReady.startWorkout")

            if !isFixedProtocolDraft,
               !hasWorkoutCompatibleBlocks,
               let skillBlock = draft.blocks.first(where: { $0.kind == .skill }),
               let skillId = skillBlock.skillId {
                Button {
                    activeSkillSession = SkillLaunch(skillId: skillId, title: skillBlock.title)
                } label: {
                    Label("Start Skill Session", systemImage: "figure.gymnastics")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

}
