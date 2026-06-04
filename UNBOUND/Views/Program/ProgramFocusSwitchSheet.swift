import SwiftUI

// MARK: - Program focus switch

struct ProgramFocusSwitchPresentation: Identifiable {
    let id = UUID()
    let currentStyle: TrainingStyle
    let currentEquipment: [Equipment]
    let currentExperience: Experience?
}

private enum ProgramFocusSwitchGear: String, CaseIterable, Identifiable {
    case pullupBar
    case bands
    case dipStation
    case rings

    var id: String { rawValue }

    var equipment: Equipment {
        switch self {
        case .pullupBar: return .pullupBar
        case .bands: return .bands
        case .dipStation: return .dipStation
        case .rings: return .rings
        }
    }

    var title: String {
        switch self {
        case .pullupBar: return "Pull-up bar"
        case .bands: return "Bands"
        case .dipStation: return "Dip station"
        case .rings: return "Rings"
        }
    }

    var subtitle: String {
        switch self {
        case .pullupBar: return "Pullups, hangs, leg raises, bar skills."
        case .bands: return "Assistance, rows, warmups, joint-friendly scaling."
        case .dipStation: return "Dips, supports, knee raises. Not implied by a pull-up bar."
        case .rings: return "Ring rows, supports, ring dips, ring skill work."
        }
    }

    var icon: String {
        switch self {
        case .pullupBar: return "figure.play"
        case .bands: return "line.diagonal"
        case .dipStation: return "figure.strengthtraining.functional"
        case .rings: return "link.circle"
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
    let equipment: Set<Equipment>
    let abilityLevel: ProgramFocusSwitchAbilityLevel
    var trainingStyle: TrainingStyle { .bodyweight }

    var sortedEquipment: [Equipment] {
        let order: [Equipment] = [.bodyweight, .pullupBar, .bands, .dipStation, .rings]
        return order.filter { equipment.contains($0) }
    }

    func updatedExerciseStyles(from current: Set<ExerciseStyle>) -> Set<ExerciseStyle> {
        let preservedStyles: Set<ExerciseStyle> = [
            .cardioIntervals,
            .steadyCardio,
            .mobility,
            .sports,
            .plyometrics
        ]
        let preserved = current.intersection(preservedStyles)
        return preserved.union([.calisthenics])
    }
}

struct ProgramFocusSwitchSheet: View {
    let currentStyle: TrainingStyle
    let currentEquipment: [Equipment]
    let currentExperience: Experience?
    let isApplying: Bool
    let errorMessage: String?
    let onApply: (ProgramFocusSwitchSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedGear: Set<ProgramFocusSwitchGear>
    @State private var selectedAbility: ProgramFocusSwitchAbilityLevel

    init(
        currentStyle: TrainingStyle,
        currentEquipment: [Equipment],
        currentExperience: Experience?,
        isApplying: Bool,
        errorMessage: String?,
        onApply: @escaping (ProgramFocusSwitchSelection) -> Void
    ) {
        self.currentStyle = currentStyle
        self.currentEquipment = currentEquipment
        self.currentExperience = currentExperience
        self.isApplying = isApplying
        self.errorMessage = errorMessage
        self.onApply = onApply
        let initialGear = Set(ProgramFocusSwitchGear.allCases.filter { currentEquipment.contains($0.equipment) })
        _selectedGear = State(initialValue: initialGear)
        _selectedAbility = State(initialValue: ProgramFocusSwitchAbilityLevel.defaultLevel(for: currentExperience))
    }

    private var selection: ProgramFocusSwitchSelection {
        var equipment = Set(selectedGear.map(\.equipment))
        equipment.insert(.bodyweight)
        return ProgramFocusSwitchSelection(equipment: equipment, abilityLevel: selectedAbility)
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    currentSummary
                    setupPicker
                    abilityPicker
                    consequenceCard
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
        VStack(alignment: .leading, spacing: 8) {
            Text("CHANGE PROGRAM FOCUS")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.coachCyan)
            Text("Switch mid-block without guessing.")
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("UNBOUND starts a fresh bodyweight block from today using the gear and ability you confirm here. Completed sessions, PRs, and skill progress stay in history.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentSummary: some View {
        let columns = [GridItem(.adaptive(minimum: 122), spacing: 8, alignment: .leading)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            summaryPill(title: currentStyle.displayName, icon: "slider.horizontal.3")
            summaryPill(title: equipmentLabel(currentEquipment), icon: "wrench.and.screwdriver")
            summaryPill(title: currentExperience?.displayName ?? "Level unset", icon: "gauge.with.dots.needle.bottom.50percent")
        }
    }

    private func summaryPill(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(title.uppercased())
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(Color.unbound.textSecondary)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Capsule().fill(Color.unbound.surface))
        .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
    }

    private var setupPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AVAILABLE SETUP")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            bodyweightLockedRow
            ForEach(ProgramFocusSwitchGear.allCases) { gear in
                gearRow(gear)
            }
        }
    }

    private var bodyweightLockedRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "figure.arms.open")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.unbound.coachCyan.opacity(0.24)))

            VStack(alignment: .leading, spacing: 3) {
                Text("Floor bodyweight")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Always included: pushups, squats, lunges, holds, mobility, and regressions.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
                .padding(.top, 3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func gearRow(_ gear: ProgramFocusSwitchGear) -> some View {
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
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: gear.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(selected ? Color.unbound.textPrimary : Color.unbound.coachCyan)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(selected ? Color.unbound.coachCyan : Color.unbound.coachCyan.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(gear.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(gear.subtitle)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(gear.equipment.displayName.uppercased())
                        .font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(selected ? Color.unbound.coachCyan : Color.unbound.textTertiary)
                    .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Color.unbound.coachCyan.opacity(0.12) : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Color.unbound.coachCyan.opacity(0.5) : Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isApplying)
    }

    private var abilityPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CALISTHENICS LEVEL")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            ForEach(ProgramFocusSwitchAbilityLevel.allCases) { level in
                abilityRow(level)
            }
        }
    }

    private func abilityRow(_ level: ProgramFocusSwitchAbilityLevel) -> some View {
        let selected = selectedAbility == level
        return Button {
            guard !isApplying else { return }
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedAbility = level
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: level.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(selected ? Color.unbound.textPrimary : Color.unbound.coachCyan)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(selected ? Color.unbound.coachCyan : Color.unbound.coachCyan.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(level.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(level.subtitle)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(level.experience.displayName.uppercased())
                        .font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(selected ? Color.unbound.coachCyan : Color.unbound.textTertiary)
                    .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Color.unbound.coachCyan.opacity(0.12) : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Color.unbound.coachCyan.opacity(0.5) : Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isApplying)
    }

    private var consequenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT HAPPENS")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            consequenceRow(icon: "calendar.badge.plus", title: "New block starts today", detail: "The current template is replaced going forward.")
            consequenceRow(icon: "clock.arrow.circlepath", title: "History stays intact", detail: "Completed workouts and PR signals are not deleted.")
            consequenceRow(icon: "wrench.and.screwdriver", title: "Gear is literal", detail: "A pull-up bar will not unlock dips or rings unless those are selected.")
            consequenceRow(icon: "target", title: "Ability gates the rebuild", detail: selectedAbility.programmingCopy)
            consequenceRow(icon: "gauge.with.dots.needle.bottom.50percent", title: "Profile level updates", detail: "Future bodyweight blocks use \(selectedAbility.title.lowercased()) scaling instead of assuming your lifting history carries over.")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func consequenceRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.unbound.coachCyan)
                .frame(width: 16)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(detail)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
        VStack(spacing: 10) {
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
                    Text(isApplying ? "REBUILDING BLOCK" : "START BODYWEIGHT BLOCK")
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
}
