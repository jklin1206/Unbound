import SwiftUI

struct ProgramFocusSwitchSheet: View {
    let currentStyle: TrainingStyle
    let currentEquipment: [Equipment]
    let currentExperience: Experience?
    let activeContext: ProgramTrainingContextOverride?
    let pendingContext: ProgramTrainingContextOverride?
    let isApplying: Bool
    let errorMessage: String?
    let onClear: (ProgramFocusSwitchClearTarget) -> Void
    let onApply: (ProgramFocusSwitchSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: ProgramFocusSwitchModeChoice
    @State private var selectedScope: ProgramFocusSwitchScopeChoice
    @State private var selectedGear: Set<ProgramFocusSwitchGear>
    @State private var selectedAbility: ProgramFocusSwitchAbilityLevel
    @State private var abilityWasTouched = false

    init(
        currentStyle: TrainingStyle,
        currentEquipment: [Equipment],
        currentExperience: Experience?,
        activeContext: ProgramTrainingContextOverride? = nil,
        pendingContext: ProgramTrainingContextOverride? = nil,
        isApplying: Bool,
        errorMessage: String?,
        onClear: @escaping (ProgramFocusSwitchClearTarget) -> Void = { _ in },
        onApply: @escaping (ProgramFocusSwitchSelection) -> Void
    ) {
        self.currentStyle = currentStyle
        self.currentEquipment = currentEquipment
        self.currentExperience = currentExperience
        self.activeContext = activeContext
        self.pendingContext = pendingContext
        self.isApplying = isApplying
        self.errorMessage = errorMessage
        self.onClear = onClear
        self.onApply = onApply
        _selectedMode = State(initialValue: ProgramFocusSwitchModeChoice.defaultChoice(for: currentStyle))
        _selectedScope = State(initialValue: .ongoing)
        let initialGear = Set(ProgramFocusSwitchGear.allCases.filter { currentEquipment.contains($0.equipment) })
        _selectedGear = State(initialValue: initialGear)
        _selectedAbility = State(initialValue: ProgramFocusSwitchAbilityLevel.defaultLevel(for: currentExperience))
    }

    private var selection: ProgramFocusSwitchSelection {
        var equipment = Set(selectedGear.map(\.equipment))
        if selectedMode == .calisthenics || selectedMode == .hybrid {
            equipment.insert(.bodyweight)
        }
        let selectedExperience = selectedMode.needsAbility && (currentExperience != nil || abilityWasTouched)
            ? selectedAbility.experience
            : nil
        return ProgramFocusSwitchSelection(
            mode: selectedMode.contextMode,
            scope: selectedScope.scope,
            equipment: equipment,
            abilityLevel: selectedAbility,
            selectedExperience: selectedExperience
        )
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    contextControls
                    modePicker
                    setupPicker
                    if selectedMode.needsAbility {
                        abilityPicker
                    }
                    if let errorMessage {
                        errorRow(errorMessage)
                    }
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
        }
    }

    private var header: some View {
        Text("Training setup")
            .font(Font.unbound.titleM)
            .foregroundStyle(Color.unbound.textPrimary)
    }

    @ViewBuilder
    private var contextControls: some View {
        if activeContext != nil || pendingContext != nil {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("ACTIVE")
                horizontalRail {
                    if let activeContext {
                        contextControlCard(
                            title: activeContext.selection.scope == .thisWeek ? "Week" : "Today",
                            detail: contextModeLabel(activeContext),
                            icon: activeContext.selection.scope == .thisWeek ? "calendar" : "sun.max.fill",
                            actionTitle: "Clear",
                            identifier: "program.focusSwitch.clearActiveDaily"
                        ) {
                            onClear(.daily(activeContext))
                        }
                    }
                    if let pendingContext {
                        contextControlCard(
                            title: "Next",
                            detail: contextModeLabel(pendingContext),
                            icon: "calendar.badge.plus",
                            actionTitle: "Cancel",
                            identifier: "program.focusSwitch.clearPendingNextBlock"
                        ) {
                            onClear(.pendingNextBlock(pendingContext))
                        }
                    }
                }
            }
        }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("MODE")
            horizontalRail {
                ForEach(ProgramFocusSwitchModeChoice.allCases) { mode in
                    modeCard(mode)
                }
            }
        }
    }

    private func modeCard(_ mode: ProgramFocusSwitchModeChoice) -> some View {
        let selected = selectedMode == mode
        return Button {
            guard !isApplying else { return }
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedMode = mode
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                artworkHeader(assetName: mode.assetName, fallbackIcon: mode.icon, selected: selected) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(selected ? Color.unbound.coachCyan : Color.unbound.textTertiary)
                }
                Text(mode.title)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(12)
            .frame(width: 132, height: 112, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.unbound.coachCyan.opacity(0.12) : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.unbound.coachCyan.opacity(0.5) : Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isApplying)
    }

    private var scopePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("APPLIES")
            horizontalRail {
                ForEach(ProgramFocusSwitchScopeChoice.allCases) { scope in
                    scopeCard(scope)
                }
            }
        }
    }

    private func scopeCard(_ scope: ProgramFocusSwitchScopeChoice) -> some View {
        let selected = selectedScope == scope
        return Button {
            guard !isApplying else { return }
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedScope = scope
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: scope.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(selected ? Color.unbound.textPrimary : Color.unbound.coachCyan)
                    .frame(width: 18)
                Text(scope.title)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(0.7)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, 12)
            .frame(width: 132, height: 48, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.unbound.coachCyan.opacity(0.14) : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.unbound.coachCyan.opacity(0.52) : Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isApplying)
    }

    private var setupPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("GEAR")
            horizontalRail {
                if selectedMode == .calisthenics || selectedMode == .hybrid {
                    bodyweightLockedCard
                }
                ForEach(selectedMode.gearOptions) { gear in
                    gearCard(gear)
                }
            }
        }
    }

    private var bodyweightLockedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            artworkHeader(assetName: "exercise_visual_exercise_pushup", fallbackIcon: "figure.arms.open", selected: false) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            Text("Bodyweight")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(0.7)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .frame(width: 138, height: 112, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func gearCard(_ gear: ProgramFocusSwitchGear) -> some View {
        let selected = selectedGear.contains(gear)
        return Button {
            guard !isApplying else { return }
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 0.16)) {
                if selected {
                    selectedGear.remove(gear)
                } else {
                    selectedGear.insert(gear)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                artworkHeader(assetName: gear.assetName, fallbackIcon: gear.icon, selected: selected) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(selected ? Color.unbound.coachCyan : Color.unbound.textTertiary)
                }

                Text(gear.title)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(0.7)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
            .padding(12)
            .frame(width: 138, height: 118, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.unbound.coachCyan.opacity(0.12) : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.unbound.coachCyan.opacity(0.5) : Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isApplying)
    }

    private var abilityPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("LEVEL")
            horizontalRail {
                ForEach(ProgramFocusSwitchAbilityLevel.allCases) { level in
                    abilityCard(level)
                }
            }
        }
    }

    private func abilityCard(_ level: ProgramFocusSwitchAbilityLevel) -> some View {
        let selected = selectedAbility == level
        return Button {
            guard !isApplying else { return }
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 0.16)) {
                abilityWasTouched = true
                selectedAbility = level
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                artworkHeader(assetName: level.assetName, fallbackIcon: level.icon, selected: selected) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(selected ? Color.unbound.coachCyan : Color.unbound.textTertiary)
                }

                Text(level.title)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(0.7)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
            .padding(12)
            .frame(width: 148, height: 118, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.unbound.coachCyan.opacity(0.12) : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.unbound.coachCyan.opacity(0.5) : Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isApplying)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            scopePicker

            Button {
                onApply(selection)
            } label: {
                HStack(spacing: 8) {
                    if isApplying {
                        ProgressView()
                            .tint(Color.unbound.textPrimary)
                            .scaleEffect(0.82)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Text(actionTitle)
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.3)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.coachCyan)
                )
            }
            .buttonStyle(.plain)
            .disabled(isApplying)
            .accessibilityIdentifier("program.focusSwitch.apply")

            Button {
                dismiss()
            } label: {
                Text("CANCEL")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
            }
            .buttonStyle(.plain)
            .disabled(isApplying)
        }
    }

    private var actionTitle: String {
        if isApplying {
            switch selectedScope {
            case .todayOnly, .thisWeek:
                return "APPLYING"
            case .nextBlock:
                return "QUEUING"
            case .ongoing:
                return "REBUILDING ACTIVE BLOCK"
            }
        }
        switch selectedScope {
        case .todayOnly:
            return "APPLY TODAY"
        case .thisWeek:
            return "APPLY WEEK"
        case .nextBlock:
            return "QUEUE NEXT BLOCK"
        case .ongoing:
            return "REBUILD ACTIVE BLOCK"
        }
    }
}
