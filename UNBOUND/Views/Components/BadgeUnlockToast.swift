import SwiftUI

// MARK: - BadgeUnlockToast
//
// Small HUD pill — NOT a full-screen takeover. Rank-ups own the takeover;
// badges are the quieter second-order reward.
//
// Serialized queue: when multiple badges unlock on the same tick (e.g.
// first_session + streak_3 + sessions_10 + rank_c_any during a first
// session) each one gets its own dwell. Legendary rarities jump to the
// front so they aren't buried behind commons.

struct BadgeUnlockToastModifier: ViewModifier {
    @State private var queue: [BadgeUnlockEvent] = []
    @State private var current: BadgeUnlockEvent?
    @State private var visible = false
    @State private var speedLinesTrigger: UUID = UUID()

    private static let dwell: TimeInterval = 2.5
    private static let fadeGap: TimeInterval = 0.3

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let current, visible {
                    ZStack(alignment: .top) {
                        if current.badge.rarity == .legendary {
                            SpeedLines(
                                count: 28,
                                length: 140,
                                innerRadius: 40,
                                color: current.badge.rarity.tint,
                                burstDuration: 0.55,
                                trigger: speedLinesTrigger
                            )
                            .allowsHitTesting(false)
                            .frame(height: 160)
                            .padding(.top, 4)
                        }
                        BadgeUnlockPill(badge: current.badge)
                            .padding(.top, 12)
                            .padding(.horizontal, 20)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(23)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: visible)
            .onReceive(NotificationCenter.default.publisher(for: .badgeUnlocked)) { note in
                guard let incoming = note.userInfo?["event"] as? BadgeUnlockEvent else { return }
                enqueue(incoming)
            }
    }

    private func enqueue(_ event: BadgeUnlockEvent) {
        if event.badge.rarity == .legendary {
            // Legendaries bump to the front of pending so they stand out,
            // but never interrupt the currently-visible toast.
            queue.insert(event, at: 0)
        } else {
            queue.append(event)
        }
        if current == nil { pumpNext() }
    }

    private func pumpNext() {
        guard !queue.isEmpty else {
            current = nil
            return
        }
        let next = queue.removeFirst()
        current = next
        if next.badge.rarity == .legendary {
            UnboundHaptics.heavy()
            speedLinesTrigger = UUID()
        } else {
            UnboundHaptics.medium()
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { visible = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.dwell) {
            withAnimation(.easeOut(duration: 0.35)) { visible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.fadeGap) {
                pumpNext()
            }
        }
    }
}

struct BadgeUnlockPill: View {
    let badge: Badge

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: badge.iconSystemName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(badge.rarity.tint)
                .shadow(color: badge.rarity.tint.opacity(0.6), radius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text("BADGE UNLOCKED · \(badge.displayName.uppercased())")
                    .font(Font.unbound.monoS)
                    .tracking(1.6)
                    .foregroundStyle(badge.rarity.tint)
                    .lineLimit(1)
                Text(badge.description)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
            }
            Spacer()

            Text(badge.rarity.displayName.uppercased())
                .font(Font.unbound.monoS)
                .tracking(1.4)
                .foregroundStyle(badge.rarity.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().stroke(badge.rarity.tint, lineWidth: 1))
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
                .strokeBorder(badge.rarity.tint.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: badge.rarity.tint.opacity(0.35), radius: 22, x: 0, y: 6)
    }
}

extension View {
    func badgeUnlockToast() -> some View {
        modifier(BadgeUnlockToastModifier())
    }
}
