import SwiftUI
import UIKit

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
            BadgeEmblemView(badge: badge, size: 38, isUnlocked: true)

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

// MARK: - BadgeEmblemView

struct BadgeEmblemView: View {
    let badge: Badge
    var size: CGFloat = 64
    var isUnlocked: Bool? = nil

    private var unlocked: Bool { isUnlocked ?? badge.isUnlocked }
    private var tint: Color { unlocked ? badge.rarity.tint : Color.unbound.textTertiary }
    private var family: BadgeEmblemFamily { BadgeEmblemFamily(id: badge.id) }
    private var generatedAssetName: String { "badge_art_\(badge.id)" }

    var body: some View {
        Group {
            if let image = UIImage(named: generatedAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipped()
                    .overlay {
                        if !unlocked {
                            Color.unbound.bg.opacity(0.38)
                            Image(systemName: "lock.fill")
                                .font(.system(size: size * 0.16, weight: .bold))
                                .foregroundStyle(Color.unbound.textTertiary)
                                .offset(x: size * 0.27, y: size * 0.27)
                        }
                    }
                    .saturation(unlocked ? 1 : 0.18)
                    .opacity(unlocked ? 1 : 0.62)
            } else {
                fallbackEmblem
            }
        }
        .frame(width: size, height: size)
    }

    private var fallbackEmblem: some View {
        ZStack {
            plate
            linework
            Image(systemName: badge.iconSystemName)
                .font(.system(size: size * 0.34, weight: .black))
                .foregroundStyle(tint)
                .shadow(color: unlocked ? tint.opacity(0.38) : .clear, radius: size * 0.10)
            if !unlocked {
                ZStack {
                    Color.unbound.bg.opacity(0.28)
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.16, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .offset(x: size * 0.27, y: size * 0.27)
                }
                .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
            }
        }
        .frame(width: size, height: size)
        .saturation(unlocked ? 1 : 0.18)
        .opacity(unlocked ? 1 : 0.62)
    }

    @ViewBuilder
    private var plate: some View {
        switch family {
        case .streak:
            Circle()
                .fill(plateFill)
                .overlay(Circle().strokeBorder(tint.opacity(unlocked ? 0.62 : 0.28), lineWidth: 1.2))
                .overlay(Circle().inset(by: size * 0.13).stroke(tint.opacity(0.22), lineWidth: 1))
        case .rank:
            Hexagon()
                .fill(plateFill)
                .overlay(Hexagon().stroke(tint.opacity(unlocked ? 0.70 : 0.32), lineWidth: 1.4))
                .rotationEffect(.degrees(30))
        case .skill:
            BadgeShield()
                .fill(plateFill)
                .overlay(BadgeShield().stroke(tint.opacity(unlocked ? 0.68 : 0.30), lineWidth: 1.2))
        case .strength:
            Diamond()
                .fill(plateFill)
                .overlay(Diamond().stroke(tint.opacity(unlocked ? 0.68 : 0.30), lineWidth: 1.2))
        case .proof:
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(plateFill)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                        .strokeBorder(tint.opacity(unlocked ? 0.62 : 0.28), lineWidth: 1.1)
                )
        case .session:
            CutCornerPlate(cut: size * 0.18)
                .fill(plateFill)
                .overlay(CutCornerPlate(cut: size * 0.18).stroke(tint.opacity(unlocked ? 0.62 : 0.28), lineWidth: 1.1))
        }
    }

    private var plateFill: LinearGradient {
        LinearGradient(
            colors: [
                tint.opacity(unlocked ? 0.22 : 0.08),
                Color.unbound.surface,
                Color.unbound.bg.opacity(0.94)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var linework: some View {
        switch family {
        case .streak:
            ForEach(0..<3, id: \.self) { index in
                ArcSegment(start: .degrees(Double(index) * 105 + 12), end: .degrees(Double(index) * 105 + 58))
                    .stroke(tint.opacity(0.30), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                    .padding(size * 0.08)
            }
        case .rank, .strength:
            Path { path in
                path.move(to: CGPoint(x: size * 0.20, y: size * 0.50))
                path.addLine(to: CGPoint(x: size * 0.80, y: size * 0.50))
                path.move(to: CGPoint(x: size * 0.50, y: size * 0.20))
                path.addLine(to: CGPoint(x: size * 0.50, y: size * 0.80))
            }
            .stroke(tint.opacity(0.16), lineWidth: 1)
        case .skill:
            VStack(spacing: size * 0.08) {
                ForEach(0..<3, id: \.self) { index in
                    Rectangle()
                        .fill(tint.opacity(0.18))
                        .frame(width: size * CGFloat(0.46 - Double(index) * 0.08), height: 1)
                }
            }
            .offset(y: size * 0.18)
        case .proof:
            HStack(spacing: size * 0.08) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(tint.opacity(0.18))
                        .frame(width: 1, height: size * 0.58)
                }
            }
            .rotationEffect(.degrees(18))
        case .session:
            Path { path in
                path.move(to: CGPoint(x: size * 0.16, y: size * 0.26))
                path.addLine(to: CGPoint(x: size * 0.44, y: size * 0.26))
                path.move(to: CGPoint(x: size * 0.56, y: size * 0.74))
                path.addLine(to: CGPoint(x: size * 0.84, y: size * 0.74))
            }
            .stroke(tint.opacity(0.22), lineWidth: 1)
        }
    }
}

private enum BadgeEmblemFamily {
    case streak, rank, skill, strength, proof, session

    init(id: String) {
        if id.contains("streak") { self = .streak }
        else if id.contains("rank") || id.hasPrefix("rank_") { self = .rank }
        else if id.contains("muscle") || id.contains("handstand") || id.contains("pull") || id.contains("dip") || id.contains("pistol") || id.contains("pushup") { self = .skill }
        else if id.hasPrefix("bw_") || id.contains("deadlift") || id.contains("squat") || id.contains("bench") { self = .strength }
        else if id.contains("scan") || id.contains("photo") || id.contains("proof") || id.contains("arc") { self = .proof }
        else { self = .session }
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct BadgeShield: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.24))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.maxY - rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.maxY - rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.24))
        path.closeSubpath()
        return path
    }
}

private struct CutCornerPlate: Shape {
    let cut: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

private struct ArcSegment: Shape {
    let start: Angle
    let end: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: start,
            endAngle: end,
            clockwise: false
        )
        return path
    }
}
