import SwiftUI

// MARK: - Step_ScanAnalyzing
//
// Cinematic post-scan analysis. Movie-forensic-scan vibe. 6s of sweep +
// HUD readouts + crosshairs + status strings narrating analysis, then a
// heavy haptic "complete" punch and advance to verdict.
//
// Uses TimelineView to redraw every frame for smooth animation. Targeting
// crosshairs jump between anatomical regions. BPM pulse line hums along
// the bottom. Status string rotates through muscle groups.

struct Step_ScanAnalyzing: View {
    @Bindable var flow: OnboardingFlowViewModel
    let onComplete: () -> Void

    private let duration: Double = 6.0
    @State private var startTime: Date = .now
    @State private var hasCompleted = false
    @State private var completionBloom = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
            let elapsed = ctx.date.timeIntervalSince(startTime)
            let fraction = min(1.0, elapsed / duration)
            let percent = Int(fraction * 100)

            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                // Violet radial vignette, subtle pulse
                RadialGradient(
                    colors: [
                        Color.unbound.accent.opacity(0.18 + 0.06 * sin(elapsed * 2)),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: 360
                )
                .ignoresSafeArea()

                // Tech grid overlay
                Canvas { context, size in
                    let spacing: CGFloat = 48
                    let drift = (elapsed.truncatingRemainder(dividingBy: 4.0) / 4.0) * spacing
                    let cols = Int(size.width / spacing) + 2
                    let rows = Int(size.height / spacing) + 2

                    var path = Path()
                    for i in 0...cols {
                        let x = CGFloat(i) * spacing - drift
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for i in 0...rows {
                        let y = CGFloat(i) * spacing - drift
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(Color.unbound.textPrimary.opacity(0.06)), lineWidth: 1)
                }
                .ignoresSafeArea()

                // Subject: user's front scan photo, desaturated + scaled
                if let photo = flow.profilePhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .saturation(0.2)
                        .opacity(0.75)
                        .frame(maxWidth: .infinity)
                        .frame(height: 420)
                        .overlay(
                            // Color wash
                            Color.unbound.accent.opacity(0.12)
                                .blendMode(.overlay)
                        )
                        .mask(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                        )
                        .padding(.horizontal, 40)
                } else {
                    // Fallback silhouette
                    Image(systemName: "figure.stand")
                        .font(.system(size: 280, weight: .ultraLight))
                        .foregroundStyle(Color.unbound.textPrimary.opacity(0.22))
                }

                // Scan plane — sweeps top↔bottom
                ScanPlane(fraction: fraction)

                // Targeting crosshairs — jump every 400ms
                TargetingCrosshairs(elapsed: elapsed)

                // Corner HUD
                HudReadouts(percent: percent, elapsed: elapsed)

                // Completion bloom — fires at 100%
                if completionBloom {
                    RadialGradient(
                        colors: [Color.unbound.impact.opacity(0.6), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 400
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
            .onChange(of: fraction) { _, new in
                if new >= 1.0 && !hasCompleted {
                    hasCompleted = true
                    UnboundHaptics.heavy()
                    withAnimation(.easeOut(duration: 0.35)) {
                        completionBloom = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        onComplete()
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            startTime = .now
        }
    }
}

// MARK: - Scan plane

private struct ScanPlane: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            let sweep = 1.0 - abs(2 * (fraction.truncatingRemainder(dividingBy: 0.4) / 0.4) - 1)
            let y = CGFloat(sweep) * geo.size.height

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.accent.opacity(0),
                            Color.unbound.accent.opacity(0.5),
                            Color.unbound.accent,
                            Color.unbound.accent.opacity(0.5),
                            Color.unbound.accent.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .shadow(color: Color.unbound.accent.opacity(0.75), radius: 20, x: 0, y: 0)
                .shadow(color: Color.unbound.impact.opacity(0.45), radius: 30, x: 0, y: 0)
                .offset(y: y)
        }
    }
}

// MARK: - Targeting crosshairs + readouts

private struct TargetingCrosshairs: View {
    let elapsed: TimeInterval

    private let regions: [(name: String, offset: CGSize)] = [
        ("TRAPEZIUS",  .init(width: 0,    height: -180)),
        ("DELTOIDS",   .init(width: 70,   height: -120)),
        ("PECTORAL",   .init(width: 0,    height: -80)),
        ("LATISSIMUS", .init(width: -70,  height: -40)),
        ("CORE",       .init(width: 0,    height: 20)),
        ("QUADRICEPS", .init(width: 30,   height: 100)),
        ("CALVES",     .init(width: -30,  height: 170))
    ]

    var body: some View {
        let index = Int(elapsed / 0.45) % regions.count
        let region = regions[index]
        let score = 30 + (index * 11) % 60

        ZStack {
            // Crosshair reticle
            Rectangle()
                .strokeBorder(Color.unbound.accent, lineWidth: 1)
                .frame(width: 42, height: 42)

            // Readout tag
            HStack(spacing: 6) {
                Text(region.name)
                    .font(Font.unbound.captionS.monospaced())
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.accent)
                Text("·")
                    .foregroundStyle(Color.unbound.textTertiary)
                Text("\(score)%")
                    .font(Font.unbound.captionS.monospaced())
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.unbound.bg.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.6), lineWidth: 0.5)
            )
            .offset(x: 56, y: -6)
        }
        .offset(region.offset)
        .transition(.opacity)
        .id(index)
    }
}

// MARK: - HUD readouts (corners)

private struct HudReadouts: View {
    let percent: Int
    let elapsed: TimeInterval

    private let statusStrings = [
        "MAPPING MUSCLE GROUPS",
        "MEASURING SYMMETRY",
        "CALCULATING DENSITY",
        "SCORING POSTURE",
        "COMPILING PROTOCOL"
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(percent)%")
                        .font(Font.unbound.monoL)
                        .foregroundStyle(Color.unbound.accent)
                    Text("ANALYZING")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("BIOMETRIC")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textSecondary)
                    Text("ANALYSIS")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()

            HStack(alignment: .bottom) {
                let statusIndex = Int(elapsed / 1.2) % statusStrings.count
                Text(statusStrings[statusIndex])
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .id(statusIndex)
                    .transition(.opacity)
                Spacer()
                BpmPulse(elapsed: elapsed)
                    .frame(width: 80, height: 20)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
    }
}

// MARK: - BPM pulse line

private struct BpmPulse: View {
    let elapsed: TimeInterval

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let midY = size.height / 2
            let step = size.width / 12
            let phase = elapsed * 2

            path.move(to: CGPoint(x: 0, y: midY))
            for i in 0...12 {
                let x = CGFloat(i) * step
                let offset = sin(phase + Double(i) * 0.5) * 6
                let spike = (i == 4 || i == 8) ? -10.0 : offset
                path.addLine(to: CGPoint(x: x, y: midY + CGFloat(spike)))
            }
            context.stroke(path, with: .color(Color.unbound.accent), lineWidth: 1)
        }
    }
}
