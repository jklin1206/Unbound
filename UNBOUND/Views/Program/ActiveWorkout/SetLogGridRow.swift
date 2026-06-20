import SwiftUI

/// One set row. SUGGESTED while `!logged` (program values shown dim,
/// trailing hollow ring = manual confirmation); LOGGED once `logged`
/// (actual values solid, quiet ✓ status glyph). Editing a cell pre-seeds
/// the editor to actual-or-suggested without auto-confirming the set.
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
    let lastPerformance: LastSetPerformance?
    let metricKind: TrainingMetricKind
    let tracksHold: Bool
    let logged: Bool
    let qualityFlags: Set<PerformanceQualityFlag>
    let isCurrent: Bool
    var calmStyle: Bool = false
    let onEditWeight: () -> Void
    let onEditReps: () -> Void
    let onPickRPE: () -> Void
    let onConfirmAsPlanned: () -> Void
    let onToggleQualityFlag: (PerformanceQualityFlag) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    if isCurrent {
                        Circle()
                            .fill(Color.unbound.coachCyan.opacity(0.20))
                            .frame(width: 26, height: 26)
                    }
                    Text("\(setNumber)")
                        .font(Font.unbound.monoS.weight(isCurrent ? .bold : .regular))
                        .foregroundStyle(isCurrent ? Color.unbound.coachCyan : Color.unbound.textTertiary)
                }
                .frame(width: 26, alignment: .leading)

                previousCell

                cell(actual: weightKg.map(formatLoggedWeight),
                     suggested: (lastPerformance?.weightKg ?? suggestedWeightKg).map(formatSuggestionWeight),
                     action: onEditWeight)
                cell(actual: metricActual,
                     suggested: metricSuggested,
                     action: onEditReps)

                confirmControl.frame(width: 40)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, (!calmStyle && isCurrent) ? 8 : 0)
        .background {
            if isCurrent && !calmStyle {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.unbound.surfaceElevated.opacity(0.42))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.unbound.coachCyan.opacity(0.18), lineWidth: 1))
            }
        }
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

    /// "What you did last time" for the Previous column — one clean value, matched by
    /// metric (weight for loaded lifts; reps / seconds otherwise).
    private var previousText: String? {
        guard let last = lastPerformance else { return nil }
        switch metricKind {
        case .reps:
            if let kg = last.weightKg {
                return formatLoggedWeight(kg)
            } else if let r = last.reps {
                return "\(r)"
            }
            return nil
        case .holdSeconds:
            return last.durationSeconds.map { "\($0)s" }
        case .durationSeconds:
            return last.durationSeconds.map(Self.time)
        case .distanceMeters, .calories:
            return last.reps.map { "\($0)" }
        }
    }

    /// Previous column — same boxed style as Weight/Reps, in a quieter read-only
    /// shade. Last time's matching value; em-dash when there's no history.
    @ViewBuilder private var previousCell: some View {
        Text(previousText ?? "—")
            .font(Font.unbound.monoM)
            .foregroundStyle(Color.unbound.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.unbound.bg.opacity(0.6))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    @ViewBuilder private var confirmControl: some View {
        if logged {
            ZStack {
                Circle()
                    .fill(Color.unbound.success.opacity(0.14))
                    .frame(width: 30, height: 30)
                    .overlay(Circle().strokeBorder(Color.unbound.success.opacity(0.72), lineWidth: 1.5))
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.success)
            }
            .accessibilityLabel("Set \(setNumber) logged")
        } else {
            Button(action: onConfirmAsPlanned) {
                ZStack {
                    Circle()
                        .strokeBorder(isCurrent ? Color.unbound.coachCyan : Color.unbound.textTertiary, lineWidth: isCurrent ? 2 : 1.5)
                        .frame(width: 30, height: 30)
                    if isCurrent {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.unbound.coachCyan)
                    }
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
                .background { valueFieldBackground() }
        }
        .buttonStyle(.plain)
    }

    /// Editable-value affordance: a soft rounded box for every value field, with a
    /// quiet cyan border on the current set so it reads as the active input.
    @ViewBuilder
    private func valueFieldBackground() -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.unbound.bg.opacity(isCurrent ? 0.9 : 0.6))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.unbound.coachCyan.opacity(isCurrent ? 0.65 : 0), lineWidth: 1)
            }
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
        return Color.unbound.textSecondary   // dim suggestion / em-dash — AA-large on the recessed bg box
    }

    private var weightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    private func formatLoggedWeight(_ kilograms: Double) -> String {
        WeightPlatePolicy.formatLoggedWeight(kilograms, unit: weightUnit)
    }

    private func formatSuggestionWeight(_ kilograms: Double) -> String {
        WeightPlatePolicy.formatSuggestionWeight(kilograms, unit: weightUnit)
    }

    private static func time(_ seconds: Int) -> String {
        "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }
}
