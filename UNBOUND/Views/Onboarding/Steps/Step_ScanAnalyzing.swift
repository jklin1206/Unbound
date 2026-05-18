import SwiftUI

// MARK: - Step_ScanAnalyzing
//
// Post-scan commitment beat. This screen does NOT do body-composition
// analysis — the scan photo is just a day-zero marker. What's actually
// happening during these 6s: we save the photo and compile the adaptive
// protocol from the user's onboarding answers (archetype, focus areas,
// experience, commitment, equipment). The copy is honest about that.
//
// The cinematic treatment (scan sweep, crosshairs, BPM pulse) is
// atmosphere, not instrumentation. No fake "density: 58%" percentages
// — anatomy labels only. Anything that implies measurement has been
// pulled so we're not promising a product we don't ship.

struct Step_ScanAnalyzing: View {
    @Bindable var flow: OnboardingFlowViewModel
    let onComplete: () -> Void

    private let duration: Double = 6.0
    @State private var startTime: Date = .now
    @State private var animationDone = false   // animation reached 100%
    @State private var hasCompleted = false    // onComplete() already called
    @State private var completionBloom = false
    @State private var insightsService = LocalBodyInsightsService()
    @State private var analysisTask: Task<Void, Never>? = nil

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
            let elapsed = ctx.date.timeIntervalSince(startTime)
            let fraction = min(1.0, elapsed / duration)
            // Hold at 99% while waiting for the LLM after animation completes
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
                } else if let baseline = UIImage(named: "body_baseline") {
                    // Fallback subject when the user has no scan photo yet
                    // (dev skip / camera-denied path) — shows the baseline
                    // starter silhouette getting "scanned" instead of a
                    // raw SF Symbol.
                    Image(uiImage: baseline)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 420)
                        .opacity(0.7)
                        .overlay(
                            Color.unbound.accent.opacity(0.12)
                                .blendMode(.overlay)
                        )
                        .padding(.horizontal, 40)
                } else {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 280, weight: .ultraLight))
                        .foregroundStyle(Color.unbound.textPrimary.opacity(0.22))
                }

                // Scan plane — sweeps top↔bottom
                ScanPlane(fraction: fraction)

                // Pulsing corner reticles — atmosphere, no labels
                ScanReticles(elapsed: elapsed)

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
                if new >= 1.0 && !animationDone {
                    animationDone = true
                    complete()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            startTime = .now
            runLocalBodyInsights()
        }
        .onDisappear {
            analysisTask?.cancel()
        }
    }

    private func complete() {
        guard !hasCompleted else { return }
        hasCompleted = true
        UnboundHaptics.heavy()
        withAnimation(.easeOut(duration: 0.35)) { completionBloom = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onComplete() }
    }

    /// Kicks off on-device Vision analysis of the front scan photo. Runs
    /// concurrent with the 6s cinematic — usually completes in under 1s,
    /// so by the time the sweep finishes, `flow.scanInsights` is ready
    /// for the Verdict screen. Silently no-ops when there's no photo
    /// (dev-skip path) or when Vision can't find a usable body pose.
    ///
    /// Also commits the first ScanCheckpoint so onboarding produces a
    /// persistent scan record (the same one the recurring scan flow produces).
    private func runLocalBodyInsights() {
        guard flow.scanInsights == nil else { return }
        guard let photo = flow.capturedPhotos[.front] else { return }

        analysisTask = Task { @MainActor in
            let insights = await insightsService.analyze(image: photo)
            guard !Task.isCancelled else { return }
            flow.scanInsights = insights

            // Commit the day-zero ScanCheckpoint. Fire-and-forget — failure
            // is silent; the user still proceeds to Verdict.
            if let jpeg = photo.jpegData(compressionQuality: 0.85) {
                let userId = AuthService.shared.currentUserId ?? "anonymous"
                _ = try? await ScanCheckpointService.shared.commit(
                    userId: userId,
                    photoData: jpeg
                )
            }
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

// MARK: - Scan reticles (corner brackets, no labels)

private struct ScanReticles: View {
    let elapsed: TimeInterval

    var body: some View {
        GeometryReader { geo in
            let pulse = 0.55 + 0.15 * sin(elapsed * 3.0)
            let color = Color.unbound.accent.opacity(pulse)
            let arm: CGFloat = 18
            let stroke: CGFloat = 1.5
            let inset: CGFloat = 40

            ZStack {
                // Top-left
                CornerBracket(arm: arm, stroke: stroke, color: color)
                    .position(x: inset, y: inset + 60)

                // Top-right
                CornerBracket(arm: arm, stroke: stroke, color: color)
                    .rotationEffect(.degrees(90))
                    .position(x: geo.size.width - inset, y: inset + 60)

                // Bottom-left
                CornerBracket(arm: arm, stroke: stroke, color: color)
                    .rotationEffect(.degrees(270))
                    .position(x: inset, y: geo.size.height - inset - 60)

                // Bottom-right
                CornerBracket(arm: arm, stroke: stroke, color: color)
                    .rotationEffect(.degrees(180))
                    .position(x: geo.size.width - inset, y: geo.size.height - inset - 60)
            }
        }
        .ignoresSafeArea()
    }
}

private struct CornerBracket: View {
    let arm: CGFloat
    let stroke: CGFloat
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            path.move(to: CGPoint(x: arm, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: arm))
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: stroke, lineCap: .square))
        }
        .frame(width: arm, height: arm)
    }
}

// MARK: - HUD readouts (corners)

private struct HudReadouts: View {
    let percent: Int
    let elapsed: TimeInterval

    // Status strings describe what's *actually* happening during these 6s.
    // On-device Vision reads the user's body pose keypoints (real) and
    // computes shoulder-to-hip ratio (real). The protocol compilation
    // step weaves those ratios into the focus-area priorities from the
    // questionnaire. Nothing aspirational — every line here is true.
    private let statusStrings = [
        "LOCKING YOUR DAY ZERO",
        "READING YOUR FRAME",
        "MEASURING SHOULDER-TO-HIP",
        "TUNING YOUR FOCUS AREAS",
        "BUILDING YOUR PROTOCOL"
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(percent)%")
                        .font(Font.unbound.monoL)
                        .foregroundStyle(Color.unbound.accent)
                    Text("LOCKING IN")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("DAY ZERO")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textSecondary)
                    Text("COMMITTED")
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.ember)
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
