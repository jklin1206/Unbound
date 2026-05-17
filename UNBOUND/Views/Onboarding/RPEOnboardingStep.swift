import SwiftUI

struct RPEOnboardingStep: View {
    let onContinue: () -> Void
    @State private var demo: Effort = .solid

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("HOW HARD WAS THAT SET?")
                .font(Font.unbound.captionS).tracking(2)
                .foregroundStyle(Color.unbound.textTertiary)

            Button {
                let order: [Effort] = [.easy, .solid, .hard]
                demo = order[((order.firstIndex(of: demo) ?? 1) + 1) % 3]
                UnboundHaptics.tick()
            } label: {
                Circle().fill(color(demo))
                    .frame(width: 96, height: 96)
                    .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
                    .shadow(color: color(demo).opacity(0.5), radius: 24)
            }
            .buttonStyle(.plain)

            Text(demo == .easy ? "Easy" : demo == .solid ? "Solid" : "Hard")
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
                .contentTransition(.opacity)

            Text("Tap it after every set. Green easy, yellow solid, red hard. That's it — it tunes your program for you.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()

            Button(action: onContinue) {
                Text("GOT IT")
                    .font(Font.unbound.bodyLStrong).tracking(2)
                    .foregroundStyle(Color.unbound.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.unbound.accent))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    private func color(_ e: Effort) -> Color {
        switch e {
        case .easy:  return Color.unbound.success
        case .solid: return Color.unbound.warnOrange
        case .hard:  return Color.unbound.alert
        }
    }
}
