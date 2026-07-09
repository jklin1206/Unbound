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
    @State var selectedMode: ProgramFocusSwitchModeChoice
    @State var selectedScope: ProgramFocusSwitchScopeChoice
    @State var selectedGear: Set<ProgramFocusSwitchGear>
    @State var selectedAbility: ProgramFocusSwitchAbilityLevel
    @State var abilityWasTouched = false

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
            return "QUEUE NEXT ARC"
        case .ongoing:
            return "REBUILD ACTIVE ARC"
        }
    }
}
