import SwiftUI
import UIKit

// MARK: - Components

func formatWhole(_ value: Double) -> String {
    "\(Int(value.rounded()))"
}

struct CinematicRewardHUD: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) {
                    HUDNotchedLine(tint: tint)
                        .frame(height: 34)
                        .padding(.top, 92)
                    Spacer()
                    HUDNotchedLine(tint: tint)
                        .frame(height: 34)
                        .padding(.bottom, 126)
                }

                Path { path in
                    let step: CGFloat = 54
                    for x in stride(from: CGFloat(0), through: geo.size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 120))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height - 142))
                    }
                    for y in stride(from: CGFloat(160), through: geo.size.height - 160, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(tint.opacity(0.045), lineWidth: 1)

                VStack {
                    Spacer()
                    Rectangle()
                        .fill(tint.opacity(0.72))
                        .frame(width: max(24, geo.size.width * progress), height: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 106)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct HUDNotchedLine: View {
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let mid = geo.size.width / 2
                path.move(to: CGPoint(x: 0, y: 10))
                path.addLine(to: CGPoint(x: mid - 46, y: 10))
                path.addLine(to: CGPoint(x: mid - 34, y: 22))
                path.addLine(to: CGPoint(x: mid + 34, y: 22))
                path.addLine(to: CGPoint(x: mid + 46, y: 10))
                path.addLine(to: CGPoint(x: geo.size.width, y: 10))
            }
            .stroke(tint.opacity(0.72), lineWidth: 1.2)
        }
    }
}

struct TriangleCorner: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct RewardPanel<Content: View>: View {
    let tint: Color
    let active: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .center, spacing: 0) { content }
            .padding(.horizontal, 2)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .center)
            .shadow(color: active ? tint.opacity(0.18) : .clear, radius: 24, y: 8)
    }
}

// MARK: - Streak flame

struct StreakFlame: View {
    let active: Bool
    let tint: Color

    @State private var lit = false
    @State private var sparkles = false
    @State private var flicker = false

    // Cohesive fire — bright gold top into deep orange-red, no off-hue.
    private let fire = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.86, blue: 0.34),
            Color(red: 1.00, green: 0.55, blue: 0.12),
            Color(red: 0.92, green: 0.22, blue: 0.06)
        ],
        startPoint: .top, endPoint: .bottom
    )
    private let emberShadow = Color(red: 1.0, green: 0.5, blue: 0.12)

    var body: some View {
        ZStack {
            // Sparkle burst — same flare as the rank-badge reveal.
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) / 12 * 2 * .pi
                Circle()
                    .fill(emberShadow)
                    .frame(width: 5, height: 5)
                    .offset(x: sparkles ? cos(angle) * 118 : 0,
                            y: sparkles ? sin(angle) * 118 : 0)
                    .opacity(sparkles ? 0 : 0.95)
            }

            Image(systemName: "flame.fill")
                .font(.system(size: 104, weight: .black))
                .foregroundStyle(fire)
                .shadow(color: emberShadow.opacity(flicker ? 0.85 : 0.5), radius: flicker ? 34 : 24)
                .shadow(color: emberShadow.opacity(lit ? 0.4 : 0), radius: 60)
                .scaleEffect(lit ? (flicker ? 1.05 : 0.98) : 0.4, anchor: .bottom)
                .rotationEffect(.degrees(lit ? 0 : -10))
                .opacity(lit ? 1 : 0)
        }
        .onChange(of: active) { _, on in if on { ignite() } }
        .onAppear { if active { ignite() } }
    }

    private func ignite() {
        // Spring slam-in + sparkle burst (the badge reveal), then a living flicker.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { lit = true }
        withAnimation(.easeOut(duration: 0.8).delay(0.08)) { sparkles = true }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(0.55)) {
            flicker = true
        }
    }
}

// MARK: - Unified per-exercise rank card (skills + lifts)
