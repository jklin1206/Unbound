import SwiftUI

struct TierUnlockToastModifier: ViewModifier {
    @State private var event: TierUnlock?
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let event, visible {
                    TierUnlockToast(event: event)
                        .padding(.top, 12)
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(21)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: visible)
            .onReceive(NotificationCenter.default.publisher(for: .tierUnlocked)) { note in
                guard let incoming = note.userInfo?["event"] as? TierUnlock else { return }
                present(incoming)
            }
    }

    private func present(_ incoming: TierUnlock) {
        event = incoming
        UnboundHaptics.success()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            visible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.35)) {
                visible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if !visible { event = nil }
            }
        }
    }
}

struct TierUnlockToast: View {
    let event: TierUnlock

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.unbound.impact)
                .shadow(color: Color.unbound.impact.opacity(0.6), radius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text("Unlocked: \(event.exerciseName)")
                    .font(Font.unbound.bodyLStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                Text("New tier in \(familyDisplay) progression")
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
                .strokeBorder(Color.unbound.impact.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.unbound.impact.opacity(0.35), radius: 22, x: 0, y: 6)
    }

    private var familyDisplay: String {
        switch event.family {
        case "push": return "push"
        case "pull": return "pull"
        case "legs-single": return "single-leg"
        case "core-lever": return "core"
        default: return event.family
        }
    }
}

extension View {
    func tierUnlockToast() -> some View {
        modifier(TierUnlockToastModifier())
    }
}
