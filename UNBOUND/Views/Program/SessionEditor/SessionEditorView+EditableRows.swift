import SwiftUI

extension SessionEditorView {
    /// Boxed exercise card: thumbnail + name + movement-type chip + overflow menu,
    /// then a compact Set · Weight · Reps grid of boxed editable cells + "add set".
    /// The card border / index badge / chip carry the exercise's movement-slot
    /// accent (push = amber, pull = blue, legs = orange …). Mirrors the in-workout
    /// logging grid but simplified — no RPE / rest / target / warmup controls
    /// (those model values keep their defaults, just unexposed).
    struct EditablePrescriptionRow<Visual: View>: View {
        @Binding var prescription: TrainingBlockPrescription
        let index: Int
        let blockIndex: Int
        let prescriptionIndex: Int
        let activeEdit: CellEditTarget?
        let liveBuffer: String
        let onBeginEdit: (CellEditTarget) -> Void
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
            blockIndex: Int,
            prescriptionIndex: Int,
            activeEdit: CellEditTarget?,
            liveBuffer: String,
            onBeginEdit: @escaping (CellEditTarget) -> Void,
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
            self.blockIndex = blockIndex
            self.prescriptionIndex = prescriptionIndex
            self.activeEdit = activeEdit
            self.liveBuffer = liveBuffer
            self.onBeginEdit = onBeginEdit
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

        /// Push / pull / legs … accent for this exercise — colors the card
        /// border, index badge, and type chip.
        private var movementSlot: MovementSlot {
            movementDefinition?.movementSlot
                ?? MovementResolver.resolve(prescription.exerciseName).movementSlot
        }

        /// Chip text; a name the catalog can't match falls back to the
        /// routine slot internally, but labeling it "Routine" would be a lie —
        /// call it what it is.
        private var chipLabel: String {
            if movementDefinition == nil,
               MovementResolver.resolve(prescription.exerciseName).isUnmatched {
                return "Custom"
            }
            return movementSlot.accentLabel
        }

        /// Rep-based movements always get the Weight column — including
        /// bodyweight rows, where "—" means bodyweight and a typed value is
        /// added load (weighted pull-up / dip / vest work). Only skill
        /// attempts, mobility, routines, and time-based rows hide it, and even
        /// those show it once a weight is actually stored. This matches the
        /// in-workout logging grid, which always exposes weight.
        private var showsWeight: Bool {
            if hasAnyWeightValue { return true }
            switch movementDefinition?.loggerMode {
            case .skillAttempts, .mobility, .routinePlayer:
                return false
            case .strengthSets, .cardio, .carry:
                return true
            case .bodyweightSets, .hold, .none:
                return metricKind == .reps
            }
        }

        private var hasAnyWeightValue: Bool {
            if prescription.suggestedWeightKg != nil { return true }
            return prescription.effectiveSetPlans.contains { $0.suggestedWeightKg != nil }
        }

        var body: some View {
            let accent = movementSlot.accentColor

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    ZStack(alignment: .topLeading) {
                        visual()
                        Text("\(index)")
                            .font(Font.unbound.monoS.weight(.bold))
                            .foregroundStyle(Color.unbound.bg)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(accent))
                            .offset(x: -3, y: -3)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(prescription.exerciseName)
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)
                        SessionRoleChip(text: chipLabel, accent: accent)
                    }

                    Spacer(minLength: 0)

                    rowActionsMenu
                }

                EditableSetGrid(
                    prescription: $prescription,
                    blockIndex: blockIndex,
                    prescriptionIndex: prescriptionIndex,
                    metricKind: metricKind,
                    showsWeight: showsWeight,
                    weightUnit: weightUnit,
                    activeEdit: activeEdit,
                    liveBuffer: liveBuffer,
                    onBeginEdit: onBeginEdit,
                    onProgrammingChange: onProgrammingChange
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(accent.opacity(0.24), lineWidth: 1)
            )
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

                WeightUnitMenuButton()

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
        let blockIndex: Int
        let prescriptionIndex: Int
        let metricKind: TrainingMetricKind
        let showsWeight: Bool
        let weightUnit: TrainingWeightUnit
        let activeEdit: CellEditTarget?
        let liveBuffer: String
        let onBeginEdit: (CellEditTarget) -> Void
        let onProgrammingChange: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                columnHeader

                ForEach(Array(planIndices), id: \.self) { setIndex in
                    EditableSetGridRow(
                        plan: setPlanBinding(setIndex),
                        setNumber: setIndex + 1,
                        blockIndex: blockIndex,
                        prescriptionIndex: prescriptionIndex,
                        setIndex: setIndex,
                        metricKind: metricKind,
                        showsWeight: showsWeight,
                        weightUnit: weightUnit,
                        activeEdit: activeEdit,
                        liveBuffer: liveBuffer,
                        onBeginEdit: onBeginEdit,
                        canRemove: prescription.plannedSetCount > 1,
                        onRemove: {
                            UnboundHaptics.soft()
                            mutate { $0.removeSetPlan(at: setIndex) }
                            onProgrammingChange()
                        }
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
                    WeightUnitHeaderLabel().frame(maxWidth: .infinity, alignment: .center)
                }
                Text(metricHeader).frame(maxWidth: .infinity, alignment: .center)
                Spacer().frame(width: 28)
            }
            .font(Font.unbound.captionS.weight(.heavy))
            .tracking(1.2)
            .foregroundStyle(Color.unbound.textTertiary)
            .padding(.top, 2)
        }

        private var planIndices: Range<Int> {
            (prescription.setPlans ?? prescription.effectiveSetPlans).indices
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

    /// One editable set line: number + (weight) + reps/hold + remove. Each value
    /// is a tappable cell that opens the bottom-docked keypad (no system keyboard);
    /// the active cell shows the live typed buffer and is lifted via a fill-only
    /// surface (never a left bar — see no-left-accent-bar).
    struct EditableSetGridRow: View {
        @Binding var plan: TrainingSetPlan
        let setNumber: Int
        let blockIndex: Int
        let prescriptionIndex: Int
        let setIndex: Int
        let metricKind: TrainingMetricKind
        let showsWeight: Bool
        let weightUnit: TrainingWeightUnit
        let activeEdit: CellEditTarget?
        let liveBuffer: String
        let onBeginEdit: (CellEditTarget) -> Void
        let canRemove: Bool
        let onRemove: () -> Void

        private var weightTarget: CellEditTarget {
            CellEditTarget(
                blockIndex: blockIndex, prescriptionIndex: prescriptionIndex,
                setIndex: setIndex, isWeight: true, metricKind: metricKind
            )
        }

        private var metricTarget: CellEditTarget {
            CellEditTarget(
                blockIndex: blockIndex, prescriptionIndex: prescriptionIndex,
                setIndex: setIndex, isWeight: false, metricKind: metricKind
            )
        }

        var body: some View {
            HStack(spacing: 8) {
                Text("\(setNumber)")
                    .font(Font.unbound.monoM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(width: 26, alignment: .leading)

                if showsWeight {
                    valueCell(target: weightTarget, displayText: weightDisplay, accessibilityName: "Weight")
                }

                valueCell(target: metricTarget, displayText: metricDisplay, accessibilityName: metricAccessibilityName)

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
        }

        /// Every value is a boxed, obviously-tappable field; the cell being
        /// edited gets the violet input-focus border (per the palette rule).
        @ViewBuilder
        private func valueCell(target: CellEditTarget, displayText: String, accessibilityName: String) -> some View {
            let isActive = activeEdit == target
            let shown = isActive ? liveBuffer : displayText
            Button {
                UnboundHaptics.tick()
                onBeginEdit(target)
            } label: {
                Text(shown.isEmpty ? "—" : shown)
                    .font(Font.unbound.monoM)
                    .foregroundStyle(shown.isEmpty ? Color.unbound.textTertiary : Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.unbound.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isActive ? Color.unbound.accent : Color.unbound.borderSubtle, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(accessibilityName), set \(setNumber)")
            .accessibilityValue(displayText.isEmpty ? "Not set" : displayText)
            .accessibilityHint("Opens the number pad")
        }

        private var weightDisplay: String {
            guard let kg = plan.suggestedWeightKg else { return "" }
            return WeightPlatePolicy.formatLoggedWeight(kg, unit: weightUnit)
        }

        /// Reps show the count/range as-is (range is informative even though the
        /// keypad edits the lower bound); holds/time show seconds with an "s"
        /// unit, distance in meters, so bare numbers never float unlabeled.
        private var metricDisplay: String {
            switch metricKind {
            case .reps:
                switch plan.target {
                case .reps(let count): return "\(count)"
                case .repsRange(let low, _): return "\(low)"
                case .amrap: return "AMRAP"
                default:
                    guard let lower = plan.target.metricLowerBound else { return "" }
                    return "\(lower)"
                }
            case .holdSeconds, .durationSeconds:
                guard let lower = plan.target.metricLowerBound else { return "" }
                return "\(lower)s"
            case .distanceMeters:
                guard let lower = plan.target.metricLowerBound else { return "" }
                return "\(lower)m"
            case .calories:
                guard let lower = plan.target.metricLowerBound else { return "" }
                return "\(lower)"
            }
        }

        private var metricAccessibilityName: String {
            switch metricKind {
            case .reps: return "Reps"
            case .holdSeconds: return "Hold seconds"
            case .durationSeconds: return "Time"
            case .distanceMeters: return "Distance"
            case .calories: return "Calories"
            }
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
