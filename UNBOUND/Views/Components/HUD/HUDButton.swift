import SwiftUI

struct HUDButton: View {
    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    @State private var pressed: Bool = false

    var body: some View {
        Button(action: handleTap) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let pulse = (sin(t * 2.0) + 1.0) / 2.0
                let wave = (sin(t * 1.4) + 1.0) / 2.0

                ZStack {
                    if isEnabled {
                        ChamferedRectangle(inset: 10)
                            .stroke(Color.unbound.accent.opacity(0.55 * (1.0 - wave)), lineWidth: 2)
                            .scaleEffect(1.0 + 0.08 * wave)
                            .blur(radius: 2)

                        ChamferedRectangle(inset: 10)
                            .stroke(Color.unbound.accent.opacity(0.3 * (1.0 - wave * 0.8)), lineWidth: 1)
                            .scaleEffect(1.0 + 0.16 * wave)
                            .blur(radius: 6)
                    }

                    ChamferedRectangle(inset: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color.unbound.surfaceElevated, Color.unbound.surface],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            ChamferedRectangle(inset: 10)
                                .stroke(
                                    isEnabled ? Color.unbound.accent : Color.unbound.border,
                                    lineWidth: 1.5
                                )
                        )
                        .overlay(label)
                        .shadow(
                            color: isEnabled
                                ? Color.unbound.accent.opacity(0.35 + 0.35 * pulse)
                                : .clear,
                            radius: isEnabled ? 16 + 10 * pulse : 0
                        )
                        .shadow(
                            color: isEnabled
                                ? Color.unbound.impact.opacity(0.18 + 0.22 * pulse)
                                : .clear,
                            radius: isEnabled ? 36 + 18 * pulse : 0
                        )
                }
                .frame(height: 58)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.98 : 1.0)
        .opacity(isEnabled ? 1.0 : 0.45)
        .disabled(!isEnabled || isLoading)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: pressed)
    }

    @ViewBuilder
    private var label: some View {
        if isLoading {
            ProgressView()
                .tint(Color.unbound.textPrimary)
        } else {
            HStack(spacing: 10) {
                Text(title.uppercased())
                    .font(Font.unbound.titleS)
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textPrimary)
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                }
            }
        }
    }

    private func handleTap() {
        guard isEnabled, !isLoading else { return }
        UnboundHaptics.heavy()
        pressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            pressed = false
        }
        action()
    }
}

#Preview("Button") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        VStack(spacing: 20) {
            HUDButton(title: "Continue", icon: "arrow.right", action: {})
            HUDButton(title: "Locked", isEnabled: false, action: {})
            HUDButton(title: "Loading", isLoading: true, action: {})
        }
        .padding()
    }
}
