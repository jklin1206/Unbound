import SwiftUI

// MARK: - SkinUnlockToast
//
// Small HUD pill that fades in from the top when a new SkillTreeSkin
// unlocks. Listens on `.skinUnlocked`.

struct SkinUnlockToastModifier: ViewModifier {
    @State private var event: SkinUnlock?
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let event, visible {
                    SkinUnlockToast(event: event)
                        .padding(.top, 12)
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(22)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: visible)
            .onReceive(NotificationCenter.default.publisher(for: .skinUnlocked)) { note in
                guard let incoming = note.userInfo?["event"] as? SkinUnlock else { return }
                present(incoming)
            }
    }

    private func present(_ incoming: SkinUnlock) {
        event = incoming
        UnboundHaptics.success()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { visible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.35)) { visible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if !visible { event = nil }
            }
        }
    }
}

struct SkinUnlockToast: View {
    let event: SkinUnlock

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(event.skin.primaryColor)
                .shadow(color: event.skin.impactColor.opacity(0.6), radius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text("SKIN UNLOCKED · \(event.skin.displayName.uppercased())")
                    .font(Font.unbound.monoS)
                    .tracking(1.6)
                    .foregroundStyle(event.skin.primaryColor)
                Text(event.skin.description)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(event.skin.primaryColor.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: event.skin.impactColor.opacity(0.35), radius: 22, x: 0, y: 6)
    }
}

extension View {
    func skinUnlockToast() -> some View {
        modifier(SkinUnlockToastModifier())
    }
}
