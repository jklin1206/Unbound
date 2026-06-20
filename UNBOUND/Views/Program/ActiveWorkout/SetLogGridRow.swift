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

                cell(actual: weightKg.map(formatLoggedWeight),
                     suggested: (lastPerformance?.weightKg ?? suggestedWeightKg).map(formatSuggestionWeight),
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
                        .background { valueFieldBackground() }
                }
                .buttonStyle(.plain)

                confirmControl.frame(width: 40)
            }

            if let line = lastReferenceLine {
                Text(line)
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.leading, 34)
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

    private var lastReferenceLine: String? {
        guard let last = lastPerformance else { return nil }
        var parts: [String] = []
        switch metricKind {
        case .reps:
            if let kg = last.weightKg, let r = last.reps {
                if let s = suggestedWeightKg, s != kg { parts.append("target " + formatSuggestionWeight(s)) }
                parts.append("last " + formatLoggedWeight(kg) + " × \(r)")
            } else if let r = last.reps {
                parts.append("last \(r) reps")
            }
        case .holdSeconds:
            if let d = last.durationSeconds { parts.append("last \(d)s") }
        case .durationSeconds:
            if let d = last.durationSeconds { parts.append("last " + Self.time(d)) }
        case .distanceMeters, .calories:
            if let r = last.reps { parts.append("last \(r)") }
        }
        guard !parts.isEmpty else { return nil }
        parts.append(Self.relativeAge(last.performedAt))
        return parts.joined(separator: " · ")
    }

    private static func relativeAge(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 0 { return "today" }
        if days == 1 { return "1d ago" }
        return "\(days)d ago"
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

    /// Editable-value affordance. Calm style: a hairline underline (accent when
    /// the set is current) instead of a filled box, so the row reads as a form
    /// field without the box-soup. Legacy/trial style: the filled cell.
    @ViewBuilder
    private func valueFieldBackground() -> some View {
        if calmStyle {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(isCurrent ? Color.unbound.coachCyan.opacity(0.40) : Color.unbound.borderSubtle)
                    .frame(height: 1)
            }
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrent ? Color.unbound.bg.opacity(0.84) : Color.unbound.surfaceElevated)
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
        return Color.unbound.textTertiary   // dim suggestion or em-dash
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
