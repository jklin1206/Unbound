import SwiftUI

// MARK: - Program focus switch

struct ProgramFocusSwitchPresentation: Identifiable {
    let id = UUID()
    let currentStyle: TrainingStyle
    let currentEquipment: [Equipment]
    let currentExperience: Experience?
    let activeContext: ProgramTrainingContextOverride?
    let pendingContext: ProgramTrainingContextOverride?
}

enum ProgramFocusSwitchClearTarget {
    case daily(ProgramTrainingContextOverride)
    case pendingNextBlock(ProgramTrainingContextOverride)
}

private enum ProgramFocusSwitchGear: String, CaseIterable, Identifiable {
    case fullGym
    case barbell
    case dumbbells
    case bench
    case machines
    case pullupBar
    case bands
    case dipStation
    case rings

    var id: String { rawValue }

    var equipment: Equipment {
        switch self {
        case .fullGym: return .fullGym
        case .barbell: return .barbell
        case .dumbbells: return .dumbbells
        case .bench: return .bench
        case .machines: return .machines
        case .pullupBar: return .pullupBar
        case .bands: return .bands
        case .dipStation: return .dipStation
        case .rings: return .rings
        }
    }

    var title: String {
        switch self {
        case .fullGym: return "Full gym"
        case .barbell: return "Barbell + rack"
        case .dumbbells: return "Dumbbells"
        case .bench: return "Bench"
        case .machines: return "Cables / machines"
        case .pullupBar: return "Pull-up bar"
        case .bands: return "Bands"
        case .dipStation: return "Dip station"
        case .rings: return "Rings"
        }
    }

    var subtitle: String {
        switch self {
        case .fullGym: return "Unlocks the full loaded and machine catalog."
        case .barbell: return "Squat, bench, deadlift, overhead press, rows."
        case .dumbbells: return "Presses, rows, split squats, hinges, isolation."
        case .bench: return "Pressing, supported rows, step-ups, incline work."
        case .machines: return "Cable, machine, and selectorized substitutions."
        case .pullupBar: return "Pullups, hangs, leg raises, bar skills."
        case .bands: return "Assistance, rows, warmups, joint-friendly scaling."
        case .dipStation: return "Dips, supports, knee raises. Not implied by a pull-up bar."
        case .rings: return "Ring rows, supports, ring dips, ring skill work."
        }
    }

    var icon: String {
        switch self {
        case .fullGym: return "dumbbell.fill"
        case .barbell: return "figure.strengthtraining.traditional"
        case .dumbbells: return "dumbbell"
        case .bench: return "rectangle.compress.vertical"
        case .machines: return "gearshape.fill"
        case .pullupBar: return "figure.play"
        case .bands: return "line.diagonal"
        case .dipStation: return "figure.strengthtraining.functional"
        case .rings: return "link.circle"
        }
    }

    var assetName: String {
        switch self {
        case .fullGym: return "exercise_visual_exercise_back-squat"
        case .barbell: return "exercise_visual_exercise_back-squat"
        case .dumbbells: return "exercise_visual_exercise_dumbbell-overhead-press"
        case .bench: return "exercise_visual_exercise_bench-press"
        case .machines: return "exercise_visual_exercise_lat-pulldown"
        case .pullupBar: return "exercise_visual_exercise_pullup"
        case .bands: return "exercise_visual_exercise_assisted-pullup-band"
        case .dipStation: return "exercise_visual_exercise_dip"
        case .rings: return "exercise_visual_exercise_ring-dip"
        }
    }
}

private enum ProgramFocusSwitchModeChoice: String, CaseIterable, Identifiable {
    case calisthenics
    case lifting
    case hybrid

    var id: String { rawValue }

    var contextMode: ProgramTrainingContextMode {
        switch self {
        case .calisthenics: return .calisthenics
        case .lifting: return .lifting
        case .hybrid: return .hybrid
        }
    }

    var title: String {
        switch self {
        case .calisthenics: return "Calisthenics"
        case .lifting: return "Lifting"
        case .hybrid: return "Hybrid"
        }
    }

    var subtitle: String {
        switch self {
        case .calisthenics: return "Bodyweight-first progressions and skill work."
        case .lifting: return "Weights, cables, and machines based on available gear."
        case .hybrid: return "Skills plus weights in the same block."
        }
    }

    var icon: String {
        switch self {
        case .calisthenics: return "figure.gymnastics"
        case .lifting: return "figure.strengthtraining.traditional"
        case .hybrid: return "arrow.triangle.2.circlepath"
        }
    }

    var assetName: String? {
        switch self {
        case .calisthenics: return "exercise_visual_exercise_pullup"
        case .lifting: return "exercise_visual_exercise_back-squat"
        case .hybrid: return "exercise_visual_exercise_weighted-pullup"
        }
    }

    var needsAbility: Bool {
        self == .calisthenics || self == .hybrid
    }

    var gearOptions: [ProgramFocusSwitchGear] {
        switch self {
        case .calisthenics:
            return [.pullupBar, .bands, .dipStation, .rings]
        case .lifting:
            return [.fullGym, .barbell, .dumbbells, .bench, .machines]
        case .hybrid:
            return [.fullGym, .barbell, .dumbbells, .bench, .machines, .pullupBar, .bands, .dipStation, .rings]
        }
    }

    static func defaultChoice(for style: TrainingStyle) -> ProgramFocusSwitchModeChoice {
        switch style {
        case .bodyweight: return .calisthenics
        case .freeWeights: return .lifting
        case .hybrid: return .hybrid
        case .machines: return .lifting
        }
    }
}

private enum ProgramFocusSwitchScopeChoice: String, CaseIterable, Identifiable {
    case todayOnly
    case thisWeek
    case nextBlock
    case ongoing

    var id: String { rawValue }

    var scope: ProgramTrainingContextScope {
        switch self {
        case .todayOnly: return .todayOnly
        case .thisWeek: return .thisWeek
        case .nextBlock: return .nextBlock
        case .ongoing: return .ongoing
        }
    }

    var title: String {
        switch self {
        case .todayOnly: return "Today"
        case .thisWeek: return "Week"
        case .nextBlock: return "Next block"
        case .ongoing: return "Active block"
        }
    }

    var icon: String {
        switch self {
        case .todayOnly: return "sun.max.fill"
        case .thisWeek: return "calendar"
        case .nextBlock: return "calendar.badge.plus"
        case .ongoing: return "arrow.triangle.2.circlepath"
        }
    }
}

enum ProgramFocusSwitchAbilityLevel: String, CaseIterable, Identifiable {
    case foundation
    case baseStrength
    case skillReady

    var id: String { rawValue }

    var title: String {
        switch self {
        case .foundation: return "Foundation"
        case .baseStrength: return "Base strength"
        case .skillReady: return "Skill-ready"
        }
    }

    var subtitle: String {
        switch self {
        case .foundation:
            return "No strict pullups yet, pushups still building, joints need easy volume."
        case .baseStrength:
            return "Some strict pushups, assisted or negative pullups, basic holds."
        case .skillReady:
            return "Strict reps are owned; skills can enter as serious practice."
        }
    }

    var icon: String {
        switch self {
        case .foundation: return "figure.core.training"
        case .baseStrength: return "figure.strengthtraining.functional"
        case .skillReady: return "figure.gymnastics"
        }
    }

    var assetName: String {
        switch self {
        case .foundation: return "exercise_visual_exercise_bodyweight-squat"
        case .baseStrength: return "exercise_visual_exercise_assisted-pullup-band"
        case .skillReady: return "exercise_visual_exercise_straddle-planche"
        }
    }

    var experience: Experience {
        switch self {
        case .foundation: return .never
        case .baseStrength: return .tried
        case .skillReady: return .current
        }
    }

    var programmingCopy: String {
        switch self {
        case .foundation:
            return "Programs beginner progressions only. No dips, muscle-ups, lever work, or handstand pressure unless the catalog has a true entry path."
        case .baseStrength:
            return "Allows beginner and intermediate progressions. Advanced skills stay out until logs prove the base."
        case .skillReady:
            return "Allows advanced calisthenics progressions when your equipment supports them. Elite work still stays gated."
        }
    }

    static func defaultLevel(for experience: Experience?) -> ProgramFocusSwitchAbilityLevel {
        switch experience {
        case .never, .none:
            return .foundation
        case .tried, .used:
            return .baseStrength
        case .current:
            return .skillReady
        }
    }
}

struct ProgramFocusSwitchSelection {
    let mode: ProgramTrainingContextMode
    let scope: ProgramTrainingContextScope
    let equipment: Set<Equipment>
    let abilityLevel: ProgramFocusSwitchAbilityLevel
    let selectedExperience: Experience?

    var sortedEquipment: [Equipment] {
        ProgramTrainingContextResolver.sortedEquipment(equipment)
    }

    var contextSelection: ProgramTrainingContextSelection {
        ProgramTrainingContextSelection(
            scope: scope,
            mode: mode,
            equipment: equipment,
            experience: selectedExperience
        )
    }
}

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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Font.unbound.captionS.weight(.heavy))
            .tracking(1.4)
            .foregroundStyle(Color.unbound.textTertiary)
    }

    private func horizontalRail<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                content()
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
    }

    private func artworkHeader<Accessory: View>(
        assetName: String?,
        fallbackIcon: String,
        selected: Bool,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.unbound.coachCyan.opacity(selected ? 0.2 : 0.08),
                                    Color.unbound.surface.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay {
                    if let assetName {
                        Image(assetName)
                            .resizable()
                            .scaledToFit()
                            .padding(3)
                            .scaleEffect(1.12)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: fallbackIcon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(selected ? Color.unbound.textPrimary : Color.unbound.coachCyan)
                            .accessibilityHidden(true)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            accessory()
                .padding(6)
        }
        .frame(height: 58)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(selected ? Color.unbound.coachCyan.opacity(0.42) : Color.unbound.borderSubtle.opacity(0.7), lineWidth: 1)
        )
    }

    private func contextControlCard(
        title: String,
        detail: String,
        icon: String,
        actionTitle: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard !isApplying else { return }
            UnboundHaptics.soft()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.coachCyan)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.unbound.coachCyan.opacity(0.14)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                    Text(detail.uppercased())
                        .font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }

                Spacer(minLength: 4)

                Text(actionTitle.uppercased())
                    .font(Font.unbound.captionS.weight(.black))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.alert)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, 12)
            .frame(width: 168, height: 58, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.alert.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isApplying)
        .accessibilityIdentifier(identifier)
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

    private func errorRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold))
            Text(message)
                .font(Font.unbound.captionS)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.unbound.alert)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.alert.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.alert.opacity(0.25), lineWidth: 1)
        )
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

    private func equipmentLabel(_ equipment: [Equipment]) -> String {
        if equipment.contains(.fullGym) { return "Full gym" }
        if equipment == [.bodyweight] { return "Bodyweight only" }
        let ordered: [Equipment] = [.bodyweight, .pullupBar, .bands, .dipStation, .rings, .bench, .dumbbells, .barbell, .machines, .homeWeights]
        let labels = ordered
            .filter { equipment.contains($0) }
            .prefix(3)
            .map(\.displayName)
        return labels.isEmpty ? "Equipment open" : labels.joined(separator: " / ")
    }

    private func contextModeLabel(_ override: ProgramTrainingContextOverride) -> String {
        let mode = override.selection.mode.displayName
        let equipment = equipmentLabel(ProgramTrainingContextResolver.sortedEquipment(override.selection.equipment))
        if override.selection.equipment.isEmpty {
            return mode
        }
        return "\(mode) / \(equipment)"
    }
}
