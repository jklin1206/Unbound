import SwiftUI

extension SkillDetailView {
    var shouldShowRequirements: Bool {
        let state = nodeStates[node.id] ?? .locked
        guard state == .locked else { return false }
        return !unlockRequirementGroups.isEmpty
    }

    var unlockRequirementGroups: [SkillUnlockRequirementGroup] {
        SkillUnlockStandards.groups(for: node, in: graph)
    }

    var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Unlock Standard")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(unlockRequirementGroups.enumerated()), id: \.element.id) { gIdx, group in
                    ForEach(group.requirements) { requirement in
                        prereqRow(requirement)
                    }
                    if gIdx < unlockRequirementGroups.count - 1 {
                        Text("or")
                            .font(Font.unbound.captionS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                            .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func prereqRow(_ requirement: SkillUnlockRequirement) -> some View {
        let resolved = graph.node(id: requirement.sourceSkillId)
        let currentTier = userSkillTierState.tier(for: requirement.sourceSkillId)
        // A not-yet feat prereq (one-arm pull-up before its floor) has no real
        // earned rank — show "—" instead of a phantom "Initiate".
        let currentRankLabel = (resolved?.earnedRankIsBelowFloor(currentTier) ?? false)
            ? "—"
            : currentTier.displayName
        let met = SkillUnlockStandards.isSatisfied(
            requirement,
            nodeStates: nodeStates,
            tierState: userSkillTierState
        )
        HStack(spacing: 12) {
            Image(systemName: met ? "checkmark.circle.fill" : "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(met ? Color.unbound.accent : Color.unbound.textTertiary)
                .frame(width: 18, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(resolved?.title ?? requirement.sourceSkillId)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(met ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Reach \(requirement.requiredTier.displayName) · current \(currentRankLabel)")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(met ? Color.unbound.accent : Color.unbound.textTertiary)
                    .lineLimit(2)
                Text(requirement.note)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 8. Sticky bottom action
    //
    // Single-CTA pattern: one big Train button that opens a chooser sheet
    // with the three options (Add Program Focus / Log a Set / Start Session).
    // Replaces the previous 3-stacked-button layout that overlapped scroll
    // content and felt heavy.

    var stickyAction: some View {
        let isUnlocked = skillProgress.isNodeTrainable(nodeId: node.id)
        let canTrain = skillProgress.canTrain(nodeId: node.id)
        let trainTitle = isUnlocked ? (canTrain ? "Train" : "Trained Today") : "Unlock First"
        let trainIcon = isUnlocked ? (canTrain ? "dumbbell.fill" : "checkmark.seal.fill") : "lock.fill"

        return Button {
            UnboundHaptics.medium()
            presentedSheet = .trainChooser
        } label: {
            HStack(spacing: 10) {
                Image(systemName: trainIcon)
                    .font(.system(size: 16, weight: .semibold))
                Text(trainTitle)
                    .font(Font.unbound.bodyLStrong)
                    .tracking(0.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    Color.unbound.surfaceElevated
                    Rectangle().fill(.thinMaterial).opacity(0.18)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.45), radius: 14, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("skillDetail.train")
    }

    // MARK: - Train chooser sheet

    var trainChooserSheet: some View {
        let isUnlocked = skillProgress.isNodeTrainable(nodeId: node.id)
        let canTrain = skillProgress.canTrain(nodeId: node.id)
        let isFocus = skillProgress.isProgramFocus(nodeId: node.id)
        let focusCount = skillProgress.programFocusIds.count
        let atCap = focusCount >= SkillProgressService.programFocusCap
        let focusDisabled = !isUnlocked || (atCap && !isFocus)
        let focusTitle: String = {
            if isFocus { return "Program Focus" }
            if !isUnlocked { return "Unlock Required" }
            if focusDisabled { return "Focus Limit (\(focusCount) / \(SkillProgressService.programFocusCap))" }
            return "Add Program Focus"
        }()
        let focusIcon = !isUnlocked ? "lock.fill" : (isFocus ? "checkmark.circle.fill" : "plus.circle")
        let nextProgramDay = nextProgramDayLabel()

        return VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(isUnlocked ? "TRAIN" : "LOCKED")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(isUnlocked ? Color.unbound.accent : Color.unbound.textTertiary)
                Text(node.title)
                    .font(.system(.title3).weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.center)
                if !isUnlocked {
                    Text(primaryUnlockSummary)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .padding(.horizontal, 18)
                }
            }
            .padding(.top, 24)

            VStack(spacing: 12) {
                trainOptionRow(
                    title: focusTitle,
                    subtitle: isFocus
                        ? "Active as one of your Program Focuses"
                        : (isUnlocked ? "Next focus day: \(nextProgramDay)" : "Meet the unlock standard before scheduling"),
                    icon: focusIcon,
                    isEnabled: !focusDisabled
                ) {
                    Task {
                        await SkillProgressService.shared.toggleProgramFocus(nodeId: node.id)
                        presentedSheet = nil
                    }
                }
                .accessibilityIdentifier("skillDetail.addToProgram")

                trainOptionRow(
                    title: "Log a Set",
                    subtitle: isUnlocked ? "Quick capture — reps, weight, RPE" : "Unlock this skill before logging direct work",
                    icon: isUnlocked ? "plus.circle" : "lock.fill",
                    isEnabled: isUnlocked && canTrain
                ) {
                    presentedSheet = .quickLog
                }
                .accessibilityIdentifier("skillDetail.logSet")

                trainOptionRow(
                    title: "Start Session",
                    subtitle: isUnlocked ? "Full guided workout for this skill" : "Build the prerequisites first",
                    icon: isUnlocked ? "dumbbell.fill" : "lock.fill",
                    isEnabled: isUnlocked && canTrain
                ) {
                    presentedSheet = .session
                }
                .accessibilityIdentifier("skillDetail.startSession")
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    func nextProgramDayLabel() -> String {
        guard let date = ProgramScheduler.shared.nextEligibleDate(forSkillId: node.id) else {
            return "Next matching day"
        }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    var primaryUnlockSummary: String {
        guard let group = unlockRequirementGroups.first,
              let requirement = group.requirements.first,
              let source = graph.node(id: requirement.sourceSkillId)
        else {
            return "Build the prerequisites before direct training."
        }
        return "Reach \(requirement.requiredTier.displayName) in \(source.title) before training this."
    }

    @ViewBuilder
    func trainOptionRow(
        title: String,
        subtitle: String,
        icon: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            guard isEnabled else { return }
            UnboundHaptics.medium()
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.unbound.accent.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(subtitle)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
            .opacity(isEnabled ? 1.0 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}
