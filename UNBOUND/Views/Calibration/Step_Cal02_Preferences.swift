import SwiftUI

struct Step_Cal02_Preferences: View {
    @Bindable var vm: CalibrationViewModel
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        CalibrationScaffold(
            eyebrow: "CALIBRATION · 02 / 03",
            title: "What do you like? What do you hate?",
            subtitle: "Tap once for yes, twice for substitute, three for avoid.",
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 10) {
                ForEach(Array(vm.preferenceRows.enumerated()), id: \.element.id) { idx, row in
                    TriStatePreferenceRow(
                        index: idx + 1,
                        row: row
                    ) {
                        UnboundHaptics.medium()
                        vm.togglePreference(row.id)
                    }
                }
            }
        }
    }
}

private struct TriStatePreferenceRow: View {
    let index: Int
    let row: CalibrationPreferenceRow
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HUDPanel(isActive: row.state != .none, pulse: false) {
                HStack(spacing: 16) {
                    Text(String(format: "%02d", index))
                        .font(Font.unbound.monoS)
                        .foregroundStyle(
                            row.state != .none ? Color.unbound.accent : Color.unbound.textTertiary
                        )
                        .frame(width: 28, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.displayName)
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text(stateLabel)
                            .font(Font.unbound.monoS)
                            .tracking(1.4)
                            .foregroundStyle(stateLabelColor)
                    }
                    Spacer(minLength: 8)

                    indicator
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private var stateLabel: String {
        switch row.state {
        case .none:       return "TAP TO MARK"
        case .yes:        return "YES · LOVE IT"
        case .substitute: return "SUB · USE ALTERNATIVE"
        case .avoid:      return "AVOID · NEVER PROGRAM"
        }
    }

    private var stateLabelColor: Color {
        switch row.state {
        case .none:       return Color.unbound.textTertiary
        case .yes:        return Color.unbound.accent
        case .substitute: return Color.unbound.textSecondary
        case .avoid:      return Color.unbound.alert
        }
    }

    @ViewBuilder
    private var indicator: some View {
        switch row.state {
        case .none:
            HUDHexagon()
                .stroke(Color.unbound.border, lineWidth: 1.25)
                .frame(width: 26, height: 24)
        case .yes:
            HUDHexagon()
                .fill(Color.unbound.accent)
                .frame(width: 26, height: 24)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.unbound.textPrimary)
                )
                .animeGlow(color: Color.unbound.accent, radius: 10, intensity: 0.8)
        case .substitute:
            HUDHexagon()
                .stroke(Color.unbound.accent, lineWidth: 1.5)
                .frame(width: 26, height: 24)
                .overlay(
                    Text("SUB")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(Color.unbound.accent)
                )
        case .avoid:
            HUDHexagon()
                .fill(Color.unbound.alert)
                .frame(width: 26, height: 24)
                .overlay(
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.unbound.textPrimary)
                )
        }
    }
}
