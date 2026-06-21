import SwiftUI

// MARK: - DayOneCalibrationCard
//
// Calibration prompt. Two visual modes:
//   `.hero` — full-hero card with pulsing HUD frame (onboarding emphasis)
//   `.slim` — compact banner below the weekly strip (secondary action once
//            the character sheet has taken the top-of-screen spot)
//
// The home hub renders `.slim` by default since the body map is now the
// hero; `.hero` is kept for callers that intentionally want the pulsing
// onboarding treatment (e.g. first-run flow).

struct DayOneCalibrationCard: View {
    enum Style {
        case hero
        case slim
    }

    let style: Style
    let onStart: () -> Void

    init(style: Style = .slim, onStart: @escaping () -> Void) {
        self.style = style
        self.onStart = onStart
    }

    var body: some View {
        switch style {
        case .hero: heroBody
        case .slim: slimBody
        }
    }

    // MARK: Hero

    private var heroBody: some View {
        HUDPanel(isActive: true, pulse: true) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("DAY 1 · CALIBRATION")
                        .font(Font.unbound.monoS)
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.accent)
                    Spacer()
                    Image(systemName: "target")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.unbound.accent)
                }

                Text("Lock your numbers")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)

                Text("A 4-exercise session to measure your real baseline.")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HUDButton(title: "Start Session", icon: "arrow.right", action: onStart)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Slim

    private var slimBody: some View {
        Button {
            UnboundHaptics.medium()
            onStart()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.unbound.accent.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: "target")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("CALIBRATION PENDING")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.accent)
                    Text("Lock your numbers — 4 lifts, ~12 min")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        DayOneCalibrationCard(style: .hero, onStart: {})
        DayOneCalibrationCard(style: .slim, onStart: {})
    }
    .padding()
    .background(Color.unbound.bg)
}
