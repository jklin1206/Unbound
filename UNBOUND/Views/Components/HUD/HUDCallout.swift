import SwiftUI

struct HUDCallout: View {
    var iconSystemName: String? = nil
    let eyebrow: String
    let message: String

    private var inner: some View {
        HStack(alignment: .top, spacing: 14) {
            if let iconSystemName {
                ZStack {
                    HUDHexagon()
                        .fill(Color.unbound.accent.opacity(0.15))
                        .frame(width: 34, height: 32)
                        .overlay(
                            HUDHexagon()
                                .stroke(Color.unbound.accent, lineWidth: 1)
                        )
                    Image(systemName: iconSystemName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.unbound.accent)
                }
                .frame(width: 36, height: 36)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow.uppercased())
                    .font(Font.unbound.monoS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.accent)
                Text(message)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    var body: some View {
        HUDPanel(isActive: false) {
            inner
        }
    }
}

#Preview("Callout") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        VStack(spacing: 12) {
            HUDCallout(
                iconSystemName: "sparkles",
                eyebrow: "SYSTEM NOTE",
                message: "Calibration improves across every answer. Be honest — the protocol scales to you."
            )
            HUDCallout(
                eyebrow: "TIP",
                message: "Pick the option that reflects your last 30 days, not your best week."
            )
        }
        .padding()
    }
}
