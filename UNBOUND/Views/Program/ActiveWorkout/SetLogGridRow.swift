import SwiftUI

/// One set row. SUGGESTED while `!logged` (program values shown dim,
/// trailing hollow ring = "log as planned"); LOGGED once `logged`
/// (actual values solid, filled ✓ status glyph). Editing a cell pre-seeds
/// the editor to actual-or-suggested.
struct SetLogGridRow: View {
    let setNumber: Int
    let weightKg: Double?
    let reps: Int?
    let holdSeconds: Int?
    let durationSeconds: Int?
    let distanceMeters: Int?
    let calories: Int?
    let rpe: Int?
    let suggestedWeightKg: Double?
    let suggestedReps: Int?
    let suggestedHoldSeconds: Int?
    let suggestedDurationSeconds: Int?
    let suggestedDistanceMeters: Int?
    let suggestedCalories: Int?
    let suggestedRPE: Int?
    let metricKind: TrainingMetricKind
    let tracksHold: Bool
    let logged: Bool
    let onEditWeight: () -> Void
    let onEditReps: () -> Void
    let onPickRPE: () -> Void
    let onConfirmAsPlanned: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

    var body: some View {
        HStack(spacing: 8) {
            Text("\(setNumber)")
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 20, alignment: .leading)

            cell(actual: weightKg.map(formatLoggedWeight),
                 suggested: suggestedWeightKg.map(formatLoggedWeight),
                 action: onEditWeight)
            cell(actual: metricActual,
                 suggested: metricSuggested,
                 action: onEditReps)

            Button(action: onPickRPE) {
                Text(display(actual: rpe.map(String.init),
                             suggested: suggestedRPE.map(String.init)))
                    .font(Font.unbound.monoM)
                    .foregroundStyle(valueColor(hasActual: rpe != nil,
                                                hasSuggested: suggestedRPE != nil))
                    .frame(width: 44)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(Color.unbound.surfaceElevated))
            }
            .buttonStyle(.plain)

            confirmControl.frame(width: 40)
        }
        .padding(.vertical, 8)
        .animation(reduceMotion ? nil
                   : .spring(response: 0.3, dampingFraction: 0.65),
                   value: logged)
    }

    private var metricActual: String? {
        switch metricKind {
        case .reps:
            return reps.map(String.init)
        case .holdSeconds:
            return holdSeconds.map { "\($0)s" }
        case .durationSeconds:
            return durationSeconds.map(Self.time)
        case .distanceMeters:
            return distanceMeters.map { "\($0)m" }
        case .calories:
            return calories.map { "\($0)" }
        }
    }

    private var metricSuggested: String? {
        switch metricKind {
        case .reps:
            return suggestedReps.map(String.init)
        case .holdSeconds:
            return suggestedHoldSeconds.map { "\($0)s" }
        case .durationSeconds:
            return suggestedDurationSeconds.map(Self.time)
        case .distanceMeters:
            return suggestedDistanceMeters.map { "\($0)m" }
        case .calories:
            return suggestedCalories.map { "\($0)" }
        }
    }

    @ViewBuilder private var confirmControl: some View {
        if logged {
            ZStack {
                Circle().fill(Color.unbound.accent).frame(width: 30, height: 30)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.bg)
            }
            .accessibilityLabel("Set \(setNumber) logged")
        } else {
            Button(action: onConfirmAsPlanned) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.unbound.textTertiary, lineWidth: 1.5)
                        .frame(width: 30, height: 30)
                }
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("set\(setNumber).confirm")
            .accessibilityLabel("Log set \(setNumber) as planned")
        }
    }

    private func cell(actual: String?, suggested: String?,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(display(actual: actual, suggested: suggested))
                .font(Font.unbound.monoM)
                .foregroundStyle(valueColor(hasActual: actual != nil,
                                            hasSuggested: suggested != nil))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color.unbound.surfaceElevated))
        }
        .buttonStyle(.plain)
    }

    /// Actual value wins when present (user touched it); else the dim
    /// program suggestion; else em-dash.
    private func display(actual: String?, suggested: String?) -> String {
        if let a = actual { return a }
        if let s = suggested { return s }
        return "—"
    }

    private func valueColor(hasActual: Bool, hasSuggested: Bool) -> Color {
        if logged || hasActual { return Color.unbound.textPrimary }
        return Color.unbound.textTertiary   // dim suggestion or em-dash
    }

    private var weightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    private func formatLoggedWeight(_ kilograms: Double) -> String {
        WeightPlatePolicy.formatLoggedWeight(kilograms, unit: weightUnit)
    }

    private static func time(_ seconds: Int) -> String {
        "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }
}
