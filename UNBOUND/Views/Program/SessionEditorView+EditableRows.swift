import SwiftUI

extension SessionEditorView {
    /// Flat, always-visible exercise row: thumbnail + name + overflow menu, then a
    /// compact Set · Weight · Reps grid (one editable row per set) + "add set".
    /// Mirrors the in-workout logging grid but simplified — no RPE / rest / target /
    /// warmup controls (those model values keep their defaults, just unexposed).
    struct EditablePrescriptionRow<Visual: View>: View {
        @Binding var prescription: TrainingBlockPrescription
        let index: Int
        let canMoveUp: Bool
        let canMoveDown: Bool
        let onSwap: () -> Void
        let onMoveUp: () -> Void
        let onMoveDown: () -> Void
        let onRemove: () -> Void
        let onProgrammingChange: () -> Void
        let visual: () -> Visual

        @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

        init(
            prescription: Binding<TrainingBlockPrescription>,
            index: Int,
            canMoveUp: Bool,
            canMoveDown: Bool,
            onSwap: @escaping () -> Void,
            onMoveUp: @escaping () -> Void,
            onMoveDown: @escaping () -> Void,
            onRemove: @escaping () -> Void,
            onProgrammingChange: @escaping () -> Void,
            @ViewBuilder visual: @escaping () -> Visual
        ) {
            _prescription = prescription
            self.index = index
            self.canMoveUp = canMoveUp
            self.canMoveDown = canMoveDown
            self.onSwap = onSwap
            self.onMoveUp = onMoveUp
            self.onMoveDown = onMoveDown
            self.onRemove = onRemove
            self.onProgrammingChange = onProgrammingChange
            self.visual = visual
        }

        private var weightUnit: TrainingWeightUnit {
            TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
        }

        /// Reps / hold-seconds / time / distance / calories — driven by the target,
        /// falling back to the movement's default metric for AMRAP.
        private var metricKind: TrainingMetricKind {
            prescription.target.metricKind(defaultingTo: movementDefinition?.defaultMetric)
        }

        private var movementDefinition: MovementDefinition? {
            MovementCatalog.resolvedTrainingMovement(
                name: prescription.exerciseName,
                movementId: prescription.movementId,
                rankStandardMovementId: prescription.rankStandardMovementId
            )?.exact
        }

        /// Weighted exercises get an editable Weight column; pure bodyweight/skill
        /// movements don't — unless the prescription already carries a load
        /// (e.g. weighted pull-ups), in which case it stays editable.
        private var showsWeight: Bool {
            if hasAnyWeightValue { return true }
            switch movementDefinition?.loggerMode {
            case .bodyweightSets, .skillAttempts, .mobility, .routinePlayer:
                return false
            case .strengthSets, .hold, .cardio, .carry, .none:
                return true
            }
        }

        private var hasAnyWeightValue: Bool {
            if prescription.suggestedWeightKg != nil { return true }
            return prescription.effectiveSetPlans.contains { $0.suggestedWeightKg != nil }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    ZStack(alignment: .topLeading) {
                        visual()
                        Text("\(index)")
                            .font(Font.unbound.monoS.weight(.bold))
                            .foregroundStyle(Color.unbound.bg)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Color.unbound.coachCyan))
                            .offset(x: -3, y: -3)
                    }

                    Text(prescription.exerciseName)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)

                    Spacer(minLength: 0)

                    rowActionsMenu
                }

                EditableSetGrid(
                    prescription: $prescription,
                    metricKind: metricKind,
                    showsWeight: showsWeight,
                    weightUnit: weightUnit,
                    onProgrammingChange: onProgrammingChange
                )
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
        }

        private var rowActionsMenu: some View {
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
    }

    /// The Set · Weight · Reps grid for one exercise. Its own `View` struct so the
    /// editor stays under the SwiftUI metadata cliff. Edits the underlying
    /// `setPlans` through the prescription binding; weight is hidden for bodyweight.
    struct EditableSetGrid: View {
        @Binding var prescription: TrainingBlockPrescription
        let metricKind: TrainingMetricKind
        let showsWeight: Bool
        let weightUnit: TrainingWeightUnit
        let onProgrammingChange: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                columnHeader

                ForEach(Array(planIndices), id: \.self) { setIndex in
                    EditableSetGridRow(
                        plan: setPlanBinding(setIndex),
                        setNumber: setIndex + 1,
                        metricKind: metricKind,
                        showsWeight: showsWeight,
                        weightUnit: weightUnit,
                        canRemove: prescription.plannedSetCount > 1,
                        onRemove: {
                            UnboundHaptics.soft()
                            mutate { $0.removeSetPlan(at: setIndex) }
                            onProgrammingChange()
                        },
                        onChange: onProgrammingChange
                    )
                }

                Button {
                    UnboundHaptics.soft()
                    mutate { $0.addSetPlan() }
                    onProgrammingChange()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .heavy))
                        Text("set")
                            .font(Font.unbound.bodyS.weight(.semibold))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Color.unbound.accent)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sessionEditor.exercise.\(prescription.id).addSet")
            }
            .onAppear(perform: materializeSetPlansIfNeeded)
        }

        private var columnHeader: some View {
            HStack(spacing: 8) {
                Text("SET").frame(width: 26, alignment: .leading)
                if showsWeight {
                    Text(weightHeader).frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(metricHeader).frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 28)
            }
            .font(Font.unbound.captionS.weight(.heavy))
            .tracking(1.2)
            .foregroundStyle(Color.unbound.textTertiary)
            .padding(.bottom, 4)
        }

        private var planIndices: Range<Int> {
            (prescription.setPlans ?? prescription.effectiveSetPlans).indices
        }

        private var weightHeader: String {
            "WEIGHT " + weightUnit.shortLabel.uppercased()
        }

        private var metricHeader: String {
            switch metricKind {
            case .reps: return "REPS"
            case .holdSeconds: return "HOLD"
            case .durationSeconds: return "TIME"
            case .distanceMeters: return "DIST"
            case .calories: return "CAL"
            }
        }

        private func materializeSetPlansIfNeeded() {
            guard prescription.setPlans?.isEmpty != false else { return }
            mutate { $0.materializeSetPlans() }
        }

        private func mutate(_ mutation: (inout TrainingBlockPrescription) -> Void) {
            var updated = prescription
            mutation(&updated)
            prescription = updated
        }

        private func setPlanBinding(_ index: Int) -> Binding<TrainingSetPlan> {
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
    }

    /// One editable set line: number + (weight) + reps/hold + remove. The metric
    /// column edits the set's target; for holds it reads/writes hold-seconds.
    struct EditableSetGridRow: View {
        @Binding var plan: TrainingSetPlan
        let setNumber: Int
        let metricKind: TrainingMetricKind
        let showsWeight: Bool
        let weightUnit: TrainingWeightUnit
        let canRemove: Bool
        let onRemove: () -> Void
        let onChange: () -> Void

        @State private var weightText: String
        @State private var metricText: String

        init(
            plan: Binding<TrainingSetPlan>,
            setNumber: Int,
            metricKind: TrainingMetricKind,
            showsWeight: Bool,
            weightUnit: TrainingWeightUnit,
            canRemove: Bool,
            onRemove: @escaping () -> Void,
            onChange: @escaping () -> Void
        ) {
            _plan = plan
            self.setNumber = setNumber
            self.metricKind = metricKind
            self.showsWeight = showsWeight
            self.weightUnit = weightUnit
            self.canRemove = canRemove
            self.onRemove = onRemove
            self.onChange = onChange
            let value = plan.wrappedValue
            _weightText = State(initialValue: Self.formatWeight(value.suggestedWeightKg, unit: weightUnit))
            _metricText = State(initialValue: Self.metricEditText(value.target, metricKind: metricKind))
        }

        var body: some View {
            HStack(spacing: 8) {
                Text("\(setNumber)")
                    .font(Font.unbound.monoM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(width: 26, alignment: .leading)

                if showsWeight {
                    gridField(text: $weightText, placeholder: "—", keyboard: .decimalPad)
                        .onChange(of: weightText) { _, text in applyWeight(text) }
                } else {
                    Text("—")
                        .font(Font.unbound.monoM)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                gridField(text: $metricText, placeholder: "—", keyboard: .numbersAndPunctuation)
                    .onChange(of: metricText) { _, text in applyMetric(text) }

                if canRemove {
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                            .frame(width: 28, height: 38)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove set \(setNumber)")
                } else {
                    Spacer().frame(width: 28)
                }
            }
            .padding(.vertical, 4)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.unbound.borderSubtle).frame(height: 1)
            }
            .onChange(of: plan) { _, _ in syncTextFromPlan() }
        }

        private func gridField(text: Binding<String>, placeholder: String, keyboard: UIKeyboardType) -> some View {
            TextField(placeholder, text: text)
                .font(Font.unbound.monoM)
                .foregroundStyle(Color.unbound.textPrimary)
                .keyboardType(keyboard)
                .lineLimit(1)
                .submitLabel(.done)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        }

        private func applyWeight(_ text: String) {
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

        private func applyMetric(_ text: String) {
            let target = Self.target(from: text, metricKind: metricKind)
            guard plan.target != target else { return }
            plan.target = target
            onChange()
        }

        private func syncTextFromPlan() {
            let newWeight = Self.formatWeight(plan.suggestedWeightKg, unit: weightUnit)
            if newWeight != weightText { weightText = newWeight }
            let newMetric = Self.metricEditText(plan.target, metricKind: metricKind)
            if newMetric != metricText { metricText = newMetric }
        }

        /// Editable text for the metric column. Reps show the range/count; holds and
        /// timed sets show seconds as a plain number; distance/calories likewise.
        private static func metricEditText(_ target: TrainingTarget, metricKind: TrainingMetricKind) -> String {
            switch metricKind {
            case .reps:
                switch target {
                case .reps(let count): return "\(count)"
                case .repsRange(let low, let high): return "\(low)-\(high)"
                case .amrap: return "AMRAP"
                default: return SessionEditorView.targetEditText(target)
                }
            case .holdSeconds, .durationSeconds:
                return "\(target.metricLowerBound ?? 0)"
            case .distanceMeters, .calories:
                return "\(target.metricLowerBound ?? 0)"
            }
        }

        /// Parse the metric column back into a target, anchored to the column's
        /// metric kind so a hold field can't accidentally become reps.
        private static func target(from text: String, metricKind: TrainingMetricKind) -> TrainingTarget {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch metricKind {
            case .reps:
                return SessionEditorView.target(from: trimmed)
            case .holdSeconds:
                return .holdSeconds(RepRange.lowerBound(trimmed) ?? 0)
            case .durationSeconds:
                return .timedSeconds(RepRange.lowerBound(trimmed) ?? 0)
            case .distanceMeters:
                return .distanceMeters(RepRange.lowerBound(trimmed) ?? 0)
            case .calories:
                return .calories(RepRange.lowerBound(trimmed) ?? 0)
            }
        }

        private static func formatWeight(_ value: Double?, unit: TrainingWeightUnit) -> String {
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
