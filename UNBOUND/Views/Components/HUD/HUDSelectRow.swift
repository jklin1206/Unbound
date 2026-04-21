import SwiftUI

struct HUDSelectRow: View {
    let index: Int
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let onTap: () -> Void

    @State private var pressScale: CGFloat = 1.0

    var body: some View {
        Button(action: handleTap) {
            HUDPanel(isActive: isSelected, pulse: isSelected) {
                HStack(spacing: 16) {
                    Text(String(format: "%02d", index))
                        .font(Font.unbound.monoS)
                        .foregroundStyle(isSelected ? Color.unbound.accent : Color.unbound.textTertiary)
                        .frame(width: 28, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .multilineTextAlignment(.leading)
                        if let subtitle {
                            Text(subtitle)
                                .font(Font.unbound.bodyS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                    }

                    Spacer(minLength: 8)

                    hexagonIndicator
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(HUDSelectRowButtonStyle())
        .scaleEffect(pressScale)
    }

    private var hexagonIndicator: some View {
        ZStack {
            if isSelected {
                HUDHexagon()
                    .fill(Color.unbound.accent)
                    .frame(width: 26, height: 24)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.unbound.textPrimary)
                    )
                    .animeGlow(color: Color.unbound.accent, radius: 10, intensity: 0.8)
            } else {
                HUDHexagon()
                    .stroke(Color.unbound.border, lineWidth: 1.25)
                    .frame(width: 26, height: 24)
            }
        }
        .frame(width: 28, height: 28)
    }

    private func handleTap() {
        UnboundHaptics.medium()
        withAnimation(.easeOut(duration: 0.12)) {
            pressScale = 0.98
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                pressScale = 1.0
            }
        }
        onTap()
    }
}

private struct HUDSelectRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.92 : 1.0)
    }
}

#Preview("Rows") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        VStack(spacing: 12) {
            HUDSelectRow(index: 1, title: "0 days", subtitle: "Starting fresh", isSelected: false, onTap: {})
            HUDSelectRow(index: 2, title: "1–2 days", subtitle: "Occasional", isSelected: false, onTap: {})
            HUDSelectRow(index: 3, title: "3–4 days", subtitle: "Consistent", isSelected: false, onTap: {})
            HUDSelectRow(index: 4, title: "5+ days", subtitle: "Heavy volume", isSelected: true, onTap: {})
        }
        .padding()
    }
}
