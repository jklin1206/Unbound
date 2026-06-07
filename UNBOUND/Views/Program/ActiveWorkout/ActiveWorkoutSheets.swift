import SwiftUI

struct EditorSheet: View {
    @ObservedObject var session: ActiveWorkoutSession
    let ei: Int
    let si: Int
    let isWeight: Bool
    let onCommitted: () -> Void

    @State private var value: Double
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue
    @AppStorage(WeightPlatePolicy.microloadingDefaultsKey) private var microloadingEnabled = false

    init(session: ActiveWorkoutSession,
         ei: Int,
         si: Int,
         isWeight: Bool,
         onCommitted: @escaping () -> Void) {
        self.session = session
        self.ei = ei
        self.si = si
        self.isWeight = isWeight
        self.onCommitted = onCommitted

        let initial: Double
        if isWeight {
            let unit = WeightPlatePolicy.currentUnit
            let kilograms = session.exercises.indices.contains(ei)
                && session.exercises[ei].sets.indices.contains(si)
                ? (session.exercises[ei].sets[si].weightKg
                   ?? session.exercises[ei].sets[si].suggestedWeightKg)
                : nil
            initial = kilograms.map { WeightPlatePolicy.editingValue(fromKilograms: $0, unit: unit) } ?? 0
        } else {
            if session.exercises.indices.contains(ei),
               session.exercises[ei].sets.indices.contains(si) {
                let set = session.exercises[ei].sets[si]
                switch session.exercises[ei].metricKind {
                case .reps:
                    initial = Double(set.reps ?? set.suggestedReps ?? 0)
                case .holdSeconds:
                    initial = Double(set.holdSeconds ?? set.suggestedHoldSeconds ?? 0)
                case .durationSeconds:
                    initial = Double(set.durationSeconds ?? set.suggestedDurationSeconds ?? 0)
                case .distanceMeters:
                    initial = Double(set.distanceMeters ?? set.suggestedDistanceMeters ?? 0)
                case .calories:
                    initial = Double(set.calories ?? set.suggestedCalories ?? 0)
                }
            } else {
                initial = 0
            }
        }
        _value = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()
                VStack(spacing: 32) {
                    Spacer()
                    StepperControl(
                        label: label,
                        value: $value,
                        step: isWeight ? weightStep : 1,
                        unit: unit,
                        allowsDecimal: isWeight
                    )
                    Spacer()
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { commit() }
                        .foregroundStyle(Color.unbound.accent)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
    }

    private var isHoldMetric: Bool {
        session.exercises.indices.contains(ei)
            && (session.exercises[ei].blockKind == .carry
                || session.exercises[ei].metricKind == .holdSeconds
                || session.exercises[ei].metricKind == .durationSeconds)
    }

    private var label: String {
        if isWeight { return isHoldMetric ? "Load" : "Weight" }
        guard session.exercises.indices.contains(ei) else { return "Value" }
        switch session.exercises[ei].metricKind {
        case .reps: return "Reps"
        case .holdSeconds: return "Hold"
        case .durationSeconds: return "Time"
        case .distanceMeters: return "Distance"
        case .calories: return "Calories"
        }
    }

    private var unit: String? {
        if isWeight { return weightUnit.shortLabel }
        guard session.exercises.indices.contains(ei) else { return nil }
        switch session.exercises[ei].metricKind {
        case .reps: return nil
        case .holdSeconds, .durationSeconds: return "sec"
        case .distanceMeters: return "m"
        case .calories: return "cal"
        }
    }

    private var weightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    private var weightStep: Double {
        WeightPlatePolicy.loadIncrement(
            unit: weightUnit,
            microloadingEnabled: microloadingEnabled
        )
    }

    private func commit() {
        guard session.exercises.indices.contains(ei),
              session.exercises[ei].sets.indices.contains(si) else {
            dismiss()
            return
        }
        if isWeight {
            session.objectWillChange.send()
            session.exercises[ei].sets[si].weightKg = value > 0
                ? WeightPlatePolicy.kilograms(fromDisplayValue: value, unit: weightUnit)
                : nil
        } else {
            let intValue = Int(value)
            session.objectWillChange.send()
            switch session.exercises[ei].metricKind {
            case .reps:
                session.exercises[ei].sets[si].reps = intValue > 0 ? intValue : nil
            case .holdSeconds:
                session.exercises[ei].sets[si].holdSeconds = intValue > 0 ? intValue : nil
            case .durationSeconds:
                session.exercises[ei].sets[si].durationSeconds = intValue > 0 ? intValue : nil
            case .distanceMeters:
                session.exercises[ei].sets[si].distanceMeters = intValue > 0 ? intValue : nil
            case .calories:
                session.exercises[ei].sets[si].calories = intValue > 0 ? intValue : nil
            }
        }
        // Keep .logged unchanged — do not clear it.
        onCommitted()
        dismiss()
    }
}

// MARK: - NotesEditSheet

/// Lightweight inline notes editor — simple text entry that writes back via
/// session.setNotes(_:forExerciseAt:). No heavy dependencies.
struct NotesEditSheet: View {
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("EXERCISE NOTES")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)

                    TextField("How did this feel? Cues, tips…", text: $text, axis: .vertical)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .tint(Color.unbound.accent)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.unbound.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                        )
                        .lineLimit(4...10)

                    Spacer()
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                        .foregroundStyle(Color.unbound.accent)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
    }
}
