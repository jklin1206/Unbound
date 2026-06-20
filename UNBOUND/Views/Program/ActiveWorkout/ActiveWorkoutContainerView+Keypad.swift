import SwiftUI

// MARK: - Bottom-docked editing (drives the shared NumberPadEditorModel)
//
// Builds the per-cell NumberPadCellConfig (label/unit/seed/placeholder + the
// live-write/commit/RPE-pick closures) the shared module needs. The state machine
// and dock chrome live in NumberPadEditor.swift; this just wires the session.

extension ActiveWorkoutContainerView {
    func beginEdit(ei: Int, si: Int, field: ActiveCell.Field) {
        let target = ActiveCell(ei: ei, si: si, field: field)
        keypad.begin(target, config: config(for: target))
    }

    func config(for target: ActiveCell) -> NumberPadCellConfig {
        if target.field == .rpe {
            return NumberPadCellConfig(
                kind: .rpe,
                rpeValue: currentRPE(target.ei, target.si),
                rpePick: { value in
                    session.setRPE(exerciseIndex: target.ei, setIndex: target.si, value)
                    saveDraft()
                }
            )
        }
        return NumberPadCellConfig(
            kind: .numeric(allowsDecimal: target.isWeight),
            label: editLabel(target),
            unit: editUnit(target),
            placeholder: editPlaceholder(target),
            seed: seedBuffer(for: target),
            liveWrite: { buffer in writeLive(target, buffer: buffer) },
            commitWrite: { saveDraft() }
        )
    }

    /// Write the typed buffer into the session live (so the row updates as you
    /// type). Mirrors the prior writeLive; never touches `.logged`.
    func writeLive(_ target: ActiveCell, buffer: String) {
        guard session.exercises.indices.contains(target.ei),
              session.exercises[target.ei].sets.indices.contains(target.si) else { return }
        let parsed = Double(buffer)
        session.objectWillChange.send()
        if target.isWeight {
            if let parsed, parsed > 0 {
                session.exercises[target.ei].sets[target.si].weightKg =
                    WeightPlatePolicy.kilograms(fromDisplayValue: parsed, unit: editWeightUnit)
            } else {
                session.exercises[target.ei].sets[target.si].weightKg = nil
            }
            return
        }
        let intValue = parsed.map { Int($0) }
        let value = (intValue ?? 0) > 0 ? intValue : nil
        switch session.exercises[target.ei].metricKind {
        case .reps: session.exercises[target.ei].sets[target.si].reps = value
        case .holdSeconds: session.exercises[target.ei].sets[target.si].holdSeconds = value
        case .durationSeconds: session.exercises[target.ei].sets[target.si].durationSeconds = value
        case .distanceMeters: session.exercises[target.ei].sets[target.si].distanceMeters = value
        case .calories: session.exercises[target.ei].sets[target.si].calories = value
        }
    }

    func seedBuffer(for target: ActiveCell) -> String {
        guard session.exercises.indices.contains(target.ei),
              session.exercises[target.ei].sets.indices.contains(target.si) else { return "" }
        let set = session.exercises[target.ei].sets[target.si]
        if target.isWeight {
            guard let kg = set.weightKg else { return "" }
            return displayNumber(WeightPlatePolicy.editingValue(fromKilograms: kg, unit: editWeightUnit))
        }
        switch session.exercises[target.ei].metricKind {
        case .reps: return set.reps.map(String.init) ?? ""
        case .holdSeconds: return set.holdSeconds.map(String.init) ?? ""
        case .durationSeconds: return set.durationSeconds.map(String.init) ?? ""
        case .distanceMeters: return set.distanceMeters.map(String.init) ?? ""
        case .calories: return set.calories.map(String.init) ?? ""
        }
    }

    func editPlaceholder(_ target: ActiveCell) -> String {
        guard session.exercises.indices.contains(target.ei),
              session.exercises[target.ei].sets.indices.contains(target.si) else { return "—" }
        let set = session.exercises[target.ei].sets[target.si]
        if target.isWeight {
            guard let kg = set.lastPerformance?.weightKg ?? set.suggestedWeightKg ?? set.weightKg else { return "—" }
            return displayNumber(WeightPlatePolicy.editingValue(fromKilograms: kg, unit: editWeightUnit))
        }
        let value: Int?
        switch session.exercises[target.ei].metricKind {
        case .reps: value = set.suggestedReps ?? set.reps
        case .holdSeconds: value = set.suggestedHoldSeconds ?? set.holdSeconds
        case .durationSeconds: value = set.suggestedDurationSeconds ?? set.durationSeconds
        case .distanceMeters: value = set.suggestedDistanceMeters ?? set.distanceMeters
        case .calories: value = set.suggestedCalories ?? set.calories
        }
        return value.map(String.init) ?? "—"
    }

    func editLabel(_ target: ActiveCell) -> String {
        guard session.exercises.indices.contains(target.ei) else { return "Value" }
        let exercise = session.exercises[target.ei]
        if target.isWeight {
            let isHold = exercise.blockKind == .carry
                || exercise.metricKind == .holdSeconds
                || exercise.metricKind == .durationSeconds
            return isHold ? "Load" : "Weight"
        }
        switch exercise.metricKind {
        case .reps: return "Reps"
        case .holdSeconds: return "Hold"
        case .durationSeconds: return "Time"
        case .distanceMeters: return "Distance"
        case .calories: return "Calories"
        }
    }

    func editUnit(_ target: ActiveCell) -> String? {
        if target.isWeight { return editWeightUnit.shortLabel }
        guard session.exercises.indices.contains(target.ei) else { return nil }
        switch session.exercises[target.ei].metricKind {
        case .reps: return nil
        case .holdSeconds, .durationSeconds: return "sec"
        case .distanceMeters: return "m"
        case .calories: return "cal"
        }
    }

    func currentRPE(_ ei: Int, _ si: Int) -> Int? {
        guard session.exercises.indices.contains(ei),
              session.exercises[ei].sets.indices.contains(si) else { return nil }
        let set = session.exercises[ei].sets[si]
        return set.rpe ?? set.suggestedRPE
    }

    func displayNumber(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }
}
