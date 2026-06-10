import SwiftUI

extension WorkoutReadyView {
    var addControls: some View {
        let nextSkill = nextScheduledSkillId
        return VStack(spacing: 8) {
            Button {
                addNextScheduledSkill()
            } label: {
                quietControlLabel(
                    nextSkill == nil ? "All Scheduled Skills Added" : "Add Scheduled Skill",
                    icon: "plus.circle"
                )
            }
            .buttonStyle(.plain)
            .disabled(nextSkill == nil)
            .opacity(nextSkill == nil ? 0.5 : 1)
            .accessibilityIdentifier("workoutReady.addScheduledSkill")

            Button {
                showingBlockBuilder = true
            } label: {
                quietControlLabel("Add Mixed Block", icon: "plus.square.on.square")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workoutReady.addMixedBlock")
        }
    }

    var startControls: some View {
        VStack(spacing: 8) {
            if !isFixedProtocolDraft {
                Button {
                    saveRecentDraft()
                } label: {
                    quietControlLabel("Save Custom Draft", icon: "tray.and.arrow.down")
                }
                .buttonStyle(.plain)
                .disabled(draft.blocks.isEmpty)
                .opacity(draft.blocks.isEmpty ? 0.5 : 1)
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
                primaryControlLabel(startButtonTitle, icon: "play.fill")
            }
            .buttonStyle(.plain)
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
                    primaryControlLabel("Start Skill Session", icon: "figure.gymnastics")
                }
                .buttonStyle(.plain)
            }
        }
    }

    func primaryControlLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
            Text(title.uppercased())
                .font(Font.unbound.bodyMStrong)
                .tracking(1.6)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(Color.unbound.textPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.accent)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    func quietControlLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
            Text(title)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
