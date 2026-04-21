import SwiftUI

struct HUDBaselineCard: View {
    let index: Int
    @Binding var baseline: CalibrationBaseline

    var body: some View {
        HUDPanel(isActive: baseline.isKnown, pulse: false) {
            VStack(alignment: .leading, spacing: 14) {
                header
                input
                unknownToggle
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index + 1))
                .font(Font.unbound.monoS)
                .tracking(1.4)
                .foregroundStyle(baseline.isKnown ? Color.unbound.accent : Color.unbound.textTertiary)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(baseline.displayName)
                    .font(Font.unbound.titleS)
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(hint)
                    .font(Font.unbound.monoS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private var hint: String {
        switch baseline.kind {
        case .weight: return "WORKING WEIGHT · FOR 8 REPS"
        case .reps: return "CLEAN REPS · NO KIP"
        }
    }

    @ViewBuilder
    private var input: some View {
        if baseline.isKnown {
            picker
        } else {
            defaultChip
        }
    }

    @ViewBuilder
    private var picker: some View {
        switch baseline.kind {
        case .weight:
            HUDScrollPicker(
                selection: weightBinding,
                values: weightValues,
                formatter: { "\(Int($0)) \(baseline.unit.uppercased())" }
            )
        case .reps:
            HUDScrollPicker(
                selection: repsBinding,
                values: Array(0...50),
                formatter: { "\($0) REPS" }
            )
        }
    }

    private var weightValues: [Double] {
        if baseline.unit.lowercased() == "lbs" {
            return stride(from: 0, through: 600, by: 5).map(Double.init)
        }
        return stride(from: 0.0, through: 300.0, by: 2.5).map { $0 }
    }

    private var weightBinding: Binding<Double> {
        Binding(
            get: { snapWeight(baseline.value) },
            set: { baseline.value = $0 }
        )
    }

    private var repsBinding: Binding<Int> {
        Binding(
            get: { Int(baseline.value.rounded()) },
            set: { baseline.value = Double($0) }
        )
    }

    private func snapWeight(_ raw: Double) -> Double {
        guard let nearest = weightValues.min(by: { abs($0 - raw) < abs($1 - raw) }) else {
            return raw
        }
        return nearest
    }

    private var defaultChip: some View {
        HStack(spacing: 10) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
            Text(defaultChipText)
                .font(Font.unbound.monoS)
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            ChamferedRectangle(inset: 6)
                .fill(Color.unbound.bg.opacity(0.5))
        )
        .overlay(
            ChamferedRectangle(inset: 6)
                .stroke(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var defaultChipText: String {
        let value = baseline.kind == .reps
            ? "\(Int(baseline.value.rounded())) reps"
            : "\(Int(baseline.value)) \(baseline.unit)"
        return "DEFAULT · \(value.uppercased())"
    }

    private var unknownToggle: some View {
        Button {
            UnboundHaptics.soft()
            baseline.isKnown.toggle()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    ChamferedRectangle(inset: 4)
                        .stroke(
                            baseline.isKnown ? Color.unbound.borderSubtle : Color.unbound.accent,
                            lineWidth: 1
                        )
                        .frame(width: 38, height: 22)
                    HStack {
                        if !baseline.isKnown { Spacer() }
                        ChamferedRectangle(inset: 3)
                            .fill(baseline.isKnown ? Color.unbound.textTertiary : Color.unbound.accent)
                            .frame(width: 16, height: 14)
                            .padding(3)
                        if baseline.isKnown { Spacer() }
                    }
                    .frame(width: 38, height: 22)
                }
                Text(baseline.isKnown ? "KNOWN" : "DON'T KNOW YET")
                    .font(Font.unbound.monoS)
                    .tracking(1.4)
                    .foregroundStyle(baseline.isKnown ? Color.unbound.textSecondary : Color.unbound.accent)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
