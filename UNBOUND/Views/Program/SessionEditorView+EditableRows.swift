import SwiftUI

extension SessionEditorView {
    struct EditablePrescriptionRow<Visual: View>: View {
        @Binding var prescription: TrainingBlockPrescription
        let index: Int
        let isExpanded: Bool
        let canMoveUp: Bool
        let canMoveDown: Bool
        let onToggleExpand: () -> Void
        let onSwap: () -> Void
        let onMoveUp: () -> Void
        let onMoveDown: () -> Void
        let onRemove: () -> Void
        let onProgrammingChange: () -> Void
        let visual: () -> Visual

        @State var setsText: String
        @State var targetText: String
        @State var weightText: String
        @State var restText: String
        @State var rpeText: String
        @State var notesText: String
        @State var showsNotes = false
        @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

        var columns: [GridItem] {
            [GridItem(.adaptive(minimum: 86), spacing: 8, alignment: .top)]
        }

        init(
            prescription: Binding<TrainingBlockPrescription>,
            index: Int,
            isExpanded: Bool,
            canMoveUp: Bool,
            canMoveDown: Bool,
            onToggleExpand: @escaping () -> Void,
            onSwap: @escaping () -> Void,
            onMoveUp: @escaping () -> Void,
            onMoveDown: @escaping () -> Void,
            onRemove: @escaping () -> Void,
            onProgrammingChange: @escaping () -> Void,
            @ViewBuilder visual: @escaping () -> Visual
        ) {
            _prescription = prescription
            self.index = index
            self.isExpanded = isExpanded
            self.canMoveUp = canMoveUp
            self.canMoveDown = canMoveDown
            self.onToggleExpand = onToggleExpand
            self.onSwap = onSwap
            self.onMoveUp = onMoveUp
            self.onMoveDown = onMoveDown
            self.onRemove = onRemove
            self.onProgrammingChange = onProgrammingChange
            self.visual = visual

            let value = prescription.wrappedValue
            _setsText = State(initialValue: "\(value.sets)")
            _targetText = State(initialValue: SessionEditorView.targetEditText(value.target))
            _weightText = State(initialValue: Self.formatWeight(value.suggestedWeightKg, unit: WeightPlatePolicy.currentUnit))
            _restText = State(initialValue: "\(value.restSeconds)")
            _rpeText = State(initialValue: value.rpe.map(String.init) ?? "")
            _notesText = State(initialValue: value.notes ?? "")
        }

        var summaryLine: String {
            let setCount = prescription.plannedSetCount
            if prescription.hasCustomSetPlanValues {
                let setLabel = setCount == 1 ? "1 set" : "\(setCount) sets"
                return "\(setLabel) · custom"
            }
            var line = "\(setCount) × \(prescription.displayTargetText)"
            if let rpe = prescription.rpe {
                line += " · RPE \(rpe)"
            }
            return line
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Button(action: onToggleExpand) {
                        HStack(spacing: 10) {
                            ZStack(alignment: .topLeading) {
                                visual()
                                Text("\(index)")
                                    .font(Font.unbound.monoS.weight(.bold))
                                    .foregroundStyle(Color.unbound.bg)
                                    .frame(width: 18, height: 18)
                                    .background(Circle().fill(Color.unbound.coachCyan))
                                    .offset(x: -3, y: -3)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(prescription.exerciseName)
                                    .font(Font.unbound.bodyMStrong)
                                    .foregroundStyle(Color.unbound.textPrimary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.76)
                                Text(summaryLine)
                                    .font(Font.unbound.captionS)
                                    .foregroundStyle(Color.unbound.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.unbound.textTertiary)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    rowActionsMenu
                }

                if isExpanded {
                    setPlanEditor

                    notesControl
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .onAppear {
                materializeSetPlansIfNeeded()
            }
        }

        var rowActionsMenu: some View {
            Menu {
                Button(action: onSwap) {
                    Label("Swap Exercise", systemImage: "arrow.triangle.2.circlepath")
                }

                Button(action: onMoveUp) {
                    Label("Move Up", systemImage: "arrow.up")
                }
                .disabled(!canMoveUp)

                Button(action: onMoveDown) {
                    Label("Move Down", systemImage: "arrow.down")
                }
                .disabled(!canMoveDown)

                Button(role: .destructive, action: onRemove) {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Exercise actions")
        }

        var weightUnit: TrainingWeightUnit {
            TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
        }

        var setPlanEditor: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("SETS")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.1)
                        .foregroundStyle(Color.unbound.textTertiary)

                    Spacer(minLength: 0)
                }

                VStack(spacing: 8) {
                    ForEach(Array((prescription.setPlans ?? prescription.effectiveSetPlans).indices), id: \.self) { setIndex in
                        EditableSetPlanRow(
                            plan: setPlanBinding(setIndex),
                            index: setIndex,
                            canRemove: prescription.plannedSetCount > 1,
                            onRemove: {
                                UnboundHaptics.soft()
                                mutatePrescription { $0.removeSetPlan(at: setIndex) }
                                syncTextFromPrescription()
                                onProgrammingChange()
                            },
                            onChange: {
                                syncTextFromPrescription()
                                onProgrammingChange()
                            }
                        )
                    }
                }

                Button {
                    UnboundHaptics.soft()
                    mutatePrescription { $0.addSetPlan() }
                    syncTextFromPrescription()
                    onProgrammingChange()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .heavy))
                        Text("ADD SET")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(0.8)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Color.unbound.accent)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sessionEditor.exercise.\(prescription.id).addSet")
            }
            .padding(.top, 2)
        }

        var notesControl: some View {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showsNotes.toggle()
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "plus.circle" : "quote.bubble")
                            .font(.system(size: 12, weight: .bold))
                        Text(notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ADD CUE" : "CUES")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(0.9)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .rotationEffect(.degrees(showsNotes ? 180 : 0))
                    }
                    .foregroundStyle(Color.unbound.textSecondary)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                if showsNotes {
                    TextField("Notes or cues", text: $notesText, axis: .vertical)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(1...3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.unbound.surface)
                        )
                        .onChange(of: notesText) { _, newValue in applyNotes(newValue) }
                }
            }
        }

        func editorField(
            label: String,
            text: Binding<String>,
            suffix: String? = nil,
            keyboard: UIKeyboardType
        ) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textTertiary)

                HStack(spacing: 4) {
                    TextField("-", text: text)
                        .font(Font.unbound.bodyS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .keyboardType(keyboard)
                        .lineLimit(1)
                        .submitLabel(.done)

                    if let suffix, !text.wrappedValue.isEmpty {
                        Text(suffix)
                            .font(Font.unbound.captionS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                }
                .padding(.horizontal, 2)
                .frame(height: 34)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.unbound.borderSubtle).frame(height: 1)
                }
            }
        }

        func applySets(_ text: String) {
            guard let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
            let clamped = min(max(value, 1), 20)
            guard prescription.sets != clamped else { return }
            prescription.sets = clamped
            onProgrammingChange()
        }

        func applyTarget(_ text: String) {
            let target = SessionEditorView.target(from: text)
            guard prescription.target != target else { return }
            prescription.target = target
            onProgrammingChange()
        }

        func applyWeight(_ text: String) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                if prescription.suggestedWeightKg != nil || prescription.loadPercentOfBodyweight != nil {
                    prescription.suggestedWeightKg = nil
                    prescription.loadPercentOfBodyweight = nil
                    onProgrammingChange()
                }
                return
            }

            guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")) else { return }
            let weight = value > 0 ? WeightPlatePolicy.kilograms(fromDisplayValue: value, unit: weightUnit) : nil
            guard prescription.suggestedWeightKg != weight else { return }
            prescription.suggestedWeightKg = weight
            prescription.loadPercentOfBodyweight = nil
            onProgrammingChange()
        }

        func applyRest(_ text: String) {
            guard let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
            let clamped = min(max(value, 0), 600)
            guard prescription.restSeconds != clamped else { return }
            prescription.restSeconds = clamped
            onProgrammingChange()
        }

        func applyRPE(_ text: String) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                if prescription.rpe != nil {
                    prescription.rpe = nil
                    onProgrammingChange()
                }
                return
            }

            guard let value = Int(trimmed) else { return }
            let clamped = min(max(value, 1), 10)
            guard prescription.rpe != clamped else { return }
            prescription.rpe = clamped
            onProgrammingChange()
        }

        func applyNotes(_ text: String) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let notes = trimmed.isEmpty ? nil : trimmed
            guard prescription.notes != notes else { return }
            prescription.notes = notes
        }

        func materializeSetPlansIfNeeded() {
            guard prescription.setPlans?.isEmpty != false else { return }
            mutatePrescription { $0.materializeSetPlans() }
            syncTextFromPrescription()
        }

        func setPlanBinding(_ index: Int) -> Binding<TrainingSetPlan> {
            Binding(
                get: {
                    let plans = prescription.setPlans ?? prescription.effectiveSetPlans
                    if plans.indices.contains(index) {
                        return plans[index]
                    }
                    return prescription.effectiveSetPlans.last ?? TrainingSetPlan(
                        target: prescription.target,
                        restSeconds: prescription.restSeconds,
                        rpe: prescription.rpe,
                        loadPercentOfBodyweight: prescription.loadPercentOfBodyweight,
                        suggestedWeightKg: prescription.suggestedWeightKg
                    )
                },
                set: { updated in
                    var nextPrescription = prescription
                    nextPrescription.materializeSetPlans()
                    guard var plans = nextPrescription.setPlans, plans.indices.contains(index) else { return }
                    plans[index] = updated
                    nextPrescription.setPlans = plans
                    nextPrescription.syncSummaryFromSetPlans()
                    prescription = nextPrescription
                }
            )
        }

        func mutatePrescription(_ mutation: (inout TrainingBlockPrescription) -> Void) {
            var updated = prescription
            mutation(&updated)
            prescription = updated
        }

        func syncTextFromPrescription() {
            setsText = "\(prescription.sets)"
            targetText = SessionEditorView.targetEditText(prescription.target)
            weightText = Self.formatWeight(prescription.suggestedWeightKg, unit: weightUnit)
            restText = "\(prescription.restSeconds)"
            rpeText = prescription.rpe.map(String.init) ?? ""
        }

        static func formatWeight(_ value: Double?, unit: TrainingWeightUnit) -> String {
            guard let value else { return "" }
            return WeightPlatePolicy.formatLoggedWeight(value, unit: unit)
        }
    }

    struct EditableSetPlanRow: View {
        @Binding var plan: TrainingSetPlan
        let index: Int
        let canRemove: Bool
        let onRemove: () -> Void
        let onChange: () -> Void

        @State private var targetText: String
        @State private var weightText: String
        @State private var restText: String
        @State private var rpeText: String
        @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

        init(
            plan: Binding<TrainingSetPlan>,
            index: Int,
            canRemove: Bool,
            onRemove: @escaping () -> Void,
            onChange: @escaping () -> Void
        ) {
            _plan = plan
            self.index = index
            self.canRemove = canRemove
            self.onRemove = onRemove
            self.onChange = onChange
            let value = plan.wrappedValue
            _targetText = State(initialValue: SessionEditorView.targetEditText(value.target))
            _weightText = State(initialValue: Self.formatWeight(value.suggestedWeightKg, unit: WeightPlatePolicy.currentUnit))
            _restText = State(initialValue: "\(value.restSeconds)")
            _rpeText = State(initialValue: value.rpe.map(String.init) ?? "")
        }

        private var weightUnit: TrainingWeightUnit {
            TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("\(index + 1)")
                        .font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(Color.unbound.bg)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(plan.isWarmup ? Color.unbound.warnOrange : Color.unbound.coachCyan))

                    setField(label: "TARGET", text: $targetText, keyboard: .numbersAndPunctuation)
                        .onChange(of: targetText) { _, text in applyTarget(text) }

                    setField(label: weightUnit.shortLabel.uppercased(), text: $weightText, keyboard: .decimalPad)
                        .onChange(of: weightText) { _, text in applyWeight(text) }

                    if canRemove {
                        Button(action: onRemove) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.unbound.textTertiary)
                                .frame(width: 28, height: 34)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove set \(index + 1)")
                    }
                }

                HStack(spacing: 8) {
                    setField(label: "RPE", text: $rpeText, keyboard: .numberPad)
                        .onChange(of: rpeText) { _, text in applyRPE(text) }

                    setField(label: "REST", text: $restText, suffix: "s", keyboard: .numberPad)
                        .onChange(of: restText) { _, text in applyRest(text) }

                    Button {
                        UnboundHaptics.soft()
                        plan.isWarmup.toggle()
                        onChange()
                    } label: {
                        Text(plan.isWarmup ? "WARMUP" : "WORK")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(0.7)
                            .foregroundStyle(plan.isWarmup ? Color.unbound.warnOrange : Color.unbound.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(plan.isWarmup ? Color.unbound.warnOrange.opacity(0.6) : Color.unbound.borderSubtle)
                                    .frame(height: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }

        func setField(
            label: String,
            text: Binding<String>,
            suffix: String? = nil,
            keyboard: UIKeyboardType
        ) -> some View {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(0.7)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)

                HStack(spacing: 3) {
                    TextField("-", text: text)
                        .font(Font.unbound.bodyS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .keyboardType(keyboard)
                        .lineLimit(1)
                        .submitLabel(.done)

                    if let suffix, !text.wrappedValue.isEmpty {
                        Text(suffix)
                            .font(Font.unbound.captionS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                }
                .padding(.horizontal, 2)
                .frame(height: 32)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.unbound.borderSubtle).frame(height: 1)
                }
            }
        }

        func applyTarget(_ text: String) {
            let target = SessionEditorView.target(from: text)
            guard plan.target != target else { return }
            plan.target = target
            onChange()
        }

        func applyWeight(_ text: String) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                guard plan.suggestedWeightKg != nil || plan.loadPercentOfBodyweight != nil else { return }
                plan.suggestedWeightKg = nil
                plan.loadPercentOfBodyweight = nil
                onChange()
                return
            }

            guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")) else { return }
            let weight = value > 0 ? WeightPlatePolicy.kilograms(fromDisplayValue: value, unit: weightUnit) : nil
            guard plan.suggestedWeightKg != weight || plan.loadPercentOfBodyweight != nil else { return }
            plan.suggestedWeightKg = weight
            plan.loadPercentOfBodyweight = nil
            onChange()
        }

        func applyRest(_ text: String) {
            guard let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
            let clamped = min(max(value, 0), 600)
            guard plan.restSeconds != clamped else { return }
            plan.restSeconds = clamped
            onChange()
        }

        func applyRPE(_ text: String) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                guard plan.rpe != nil else { return }
                plan.rpe = nil
                onChange()
                return
            }

            guard let value = Int(trimmed) else { return }
            let clamped = min(max(value, 1), 10)
            guard plan.rpe != clamped else { return }
            plan.rpe = clamped
            onChange()
        }

        static func formatWeight(_ value: Double?, unit: TrainingWeightUnit) -> String {
            guard let value else { return "" }
            return WeightPlatePolicy.formatLoggedWeight(value, unit: unit)
        }
    }

    struct PrescriptionTarget: Identifiable, Hashable {
        let blockIndex: Int
        let prescriptionIndex: Int
        var id: String { "\(blockIndex)-\(prescriptionIndex)" }
    }

    enum PickerRoute: Identifiable, Hashable {
        case add(blockId: String)
        case swap(PrescriptionTarget)

        var id: String {
            switch self {
            case .add(let blockId):
                return "add-\(blockId)"
            case .swap(let target):
                return "swap-\(target.id)"
            }
        }
    }

    enum CustomRoute: Identifiable, Hashable {
        case add(blockId: String)
        case swap(PrescriptionTarget)

        var id: String {
            switch self {
            case .add(let blockId):
                return "custom-add-\(blockId)"
            case .swap(let target):
                return "custom-swap-\(target.id)"
            }
        }
    }

}
