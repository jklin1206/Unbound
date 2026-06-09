import SwiftUI

// MARK: - Bottom-docked keypad editing for the Plan/Edit Workout grid
//
// Mirrors the in-workout logging grid (ActiveWorkoutContainerView): tapping a
// Weight/Reps cell opens the bottom-docked InlineNumberPad instead of the system
// keyboard. The parent owns the typed buffer and writes it live into the draft's
// set plan as the user types, reusing the existing setPlans / WeightPlatePolicy
// logic. Kept in its own extension so SessionEditorView.body stays under the
// SwiftUI metadata cliff.

extension SessionEditorView {
    /// Identifies a single editable grid cell across the block / prescription /
    /// set hierarchy plus which column (weight vs the metric column).
    struct CellEditTarget: Identifiable, Equatable {
        let blockIndex: Int
        let prescriptionIndex: Int
        let setIndex: Int
        let isWeight: Bool
        let metricKind: TrainingMetricKind

        var id: String { "\(blockIndex)-\(prescriptionIndex)-\(setIndex)-\(isWeight ? "w" : "m")" }

        static func == (lhs: CellEditTarget, rhs: CellEditTarget) -> Bool {
            lhs.id == rhs.id
        }
    }

    @ViewBuilder
    var editorKeypadDock: some View {
        if let target = editing {
            InlineNumberPad(
                title: editLabel(target),
                unit: editUnit(target),
                valueText: editBuffer,
                placeholder: editPlaceholder(target),
                allowsDecimal: target.isWeight,
                onKey: { handleEditKey($0, target) },
                onDone: { commitEdit(target) }
            )
            .zIndex(20)
        }
    }

    var editWeightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    // MARK: - Begin / commit

    func beginEdit(_ target: CellEditTarget) {
        commitPendingEditIfNeeded()
        editBuffer = seedBuffer(for: target)
        editPristine = true
        editing = target
    }

    /// Commit the currently-open cell (if any) before switching cells or closing.
    func commitPendingEditIfNeeded() {
        guard let target = editing, !editPristine else { return }
        writeLive(target)
        refreshDraftEstimate()
    }

    func handleEditKey(_ key: NumberPadKey, _ target: CellEditTarget) {
        switch key {
        case .digit(let digit):
            if editPristine { editBuffer = ""; editPristine = false }
            if editBuffer == "0" { editBuffer = "" }   // no leading zeros
            editBuffer.append("\(digit)")
        case .decimal:
            if editPristine { editBuffer = "0"; editPristine = false }
            if !editBuffer.contains(".") {
                editBuffer.append(editBuffer.isEmpty ? "0." : ".")
            }
        case .delete:
            editPristine = false
            if !editBuffer.isEmpty { editBuffer.removeLast() }
        }
        writeLive(target)
    }

    func commitEdit(_ target: CellEditTarget) {
        if !editPristine {
            writeLive(target)
            refreshDraftEstimate()
        }
        editing = nil
    }

    // MARK: - Live write into the draft set plan

    /// Write the typed buffer into the draft's set plan live (so the cell updates
    /// as you type). Mirrors EditableSetGridRow.applyWeight / applyMetric, going
    /// through the same materializeSetPlans + syncSummaryFromSetPlans path.
    func writeLive(_ target: CellEditTarget) {
        mutateSetPlan(target) { plan in
            if target.isWeight {
                let trimmed = editBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    plan.suggestedWeightKg = nil
                    plan.loadPercentOfBodyweight = nil
                } else if let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")) {
                    plan.suggestedWeightKg = value > 0
                        ? WeightPlatePolicy.kilograms(fromDisplayValue: value, unit: editWeightUnit)
                        : nil
                    plan.loadPercentOfBodyweight = nil
                }
            } else {
                plan.target = Self.metricTarget(from: editBuffer, metricKind: target.metricKind)
            }
        }
    }

    /// Apply a mutation to the addressed set plan via the existing setPlans path,
    /// materializing plans first so per-set edits stick.
    private func mutateSetPlan(_ target: CellEditTarget, _ mutation: (inout TrainingSetPlan) -> Void) {
        guard draft.blocks.indices.contains(target.blockIndex),
              draft.blocks[target.blockIndex].prescriptions.indices.contains(target.prescriptionIndex)
        else { return }
        var prescription = draft.blocks[target.blockIndex].prescriptions[target.prescriptionIndex]
        prescription.materializeSetPlans()
        guard var plans = prescription.setPlans, plans.indices.contains(target.setIndex) else { return }
        mutation(&plans[target.setIndex])
        prescription.setPlans = plans
        prescription.syncSummaryFromSetPlans()
        draft.blocks[target.blockIndex].prescriptions[target.prescriptionIndex] = prescription
    }

    // MARK: - Buffer seeding / display

    private func plan(for target: CellEditTarget) -> TrainingSetPlan? {
        guard draft.blocks.indices.contains(target.blockIndex),
              draft.blocks[target.blockIndex].prescriptions.indices.contains(target.prescriptionIndex)
        else { return nil }
        let prescription = draft.blocks[target.blockIndex].prescriptions[target.prescriptionIndex]
        let plans = prescription.setPlans ?? prescription.effectiveSetPlans
        return plans.indices.contains(target.setIndex) ? plans[target.setIndex] : prescription.effectiveSetPlans.last
    }

    func seedBuffer(for target: CellEditTarget) -> String {
        guard let plan = plan(for: target) else { return "" }
        if target.isWeight {
            guard let kg = plan.suggestedWeightKg else { return "" }
            return WeightPlatePolicy.formatLoggedWeight(kg, unit: editWeightUnit)
        }
        return Self.metricEditBuffer(plan.target, metricKind: target.metricKind)
    }

    func editPlaceholder(_ target: CellEditTarget) -> String {
        guard let plan = plan(for: target) else { return "—" }
        if target.isWeight {
            guard let kg = plan.suggestedWeightKg else { return "—" }
            return WeightPlatePolicy.formatLoggedWeight(kg, unit: editWeightUnit)
        }
        let text = Self.metricEditBuffer(plan.target, metricKind: target.metricKind)
        return text.isEmpty ? "—" : text
    }

    func editLabel(_ target: CellEditTarget) -> String {
        if target.isWeight { return "Weight" }
        switch target.metricKind {
        case .reps: return "Reps"
        case .holdSeconds: return "Hold"
        case .durationSeconds: return "Time"
        case .distanceMeters: return "Distance"
        case .calories: return "Calories"
        }
    }

    func editUnit(_ target: CellEditTarget) -> String? {
        if target.isWeight { return editWeightUnit.shortLabel }
        switch target.metricKind {
        case .reps: return nil
        case .holdSeconds, .durationSeconds: return "sec"
        case .distanceMeters: return "m"
        case .calories: return "cal"
        }
    }

    // MARK: - Metric <-> buffer

    /// Plain-number buffer for the metric column. Reps/range collapse to the
    /// lower bound (the keypad is single-number); holds/time/distance/cal show
    /// the magnitude. AMRAP/empty seed as blank.
    static func metricEditBuffer(_ target: TrainingTarget, metricKind: TrainingMetricKind) -> String {
        switch metricKind {
        case .reps:
            switch target {
            case .reps(let count): return "\(count)"
            case .repsRange(let low, _): return "\(low)"
            case .amrap: return ""
            default:
                guard let lower = target.metricLowerBound, lower > 0 else { return "" }
                return "\(lower)"
            }
        case .holdSeconds, .durationSeconds, .distanceMeters, .calories:
            guard let lower = target.metricLowerBound, lower > 0 else { return "" }
            return "\(lower)"
        }
    }

    /// Parse a plain-number buffer back into a target, anchored to the column's
    /// metric kind so a hold cell can't accidentally become reps. Empty → AMRAP
    /// for reps, zero magnitude for timed/measured kinds.
    static func metricTarget(from buffer: String, metricKind: TrainingMetricKind) -> TrainingTarget {
        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = Int(trimmed) ?? 0
        switch metricKind {
        case .reps:
            return value > 0 ? .reps(value) : .amrap
        case .holdSeconds:
            return .holdSeconds(value)
        case .durationSeconds:
            return .timedSeconds(value)
        case .distanceMeters:
            return .distanceMeters(value)
        case .calories:
            return .calories(value)
        }
    }
}
