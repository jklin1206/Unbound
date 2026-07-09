import SwiftUI

// MARK: - Step_PainCost
//
// Cinematic accountability beat between the opening video and the game hook,
// staged as a literal in-game SYSTEM window materializing in front of you
// (Solo-Leveling "[ SYSTEM ]" notification language): a glowing cyan-framed
// panel with corner brackets and a live status header. The System narrates the
// user's past back to them one line at a time - each with a haptic - and names
// the thing that was missing (no one held them to it), before the accent line
// asserts the turn: the System does now. problemFrame's game question lands next.
//
// The window chrome is factored into `SystemNotificationWindow` so the later
// obstacle-fix beat speaks in the same system voice.
//
// Tap while the sequence is running reveals everything instantly; tap after
// it settles advances. No progress bar, no back - this is a story frame.

struct Step_PainCost: View {
    let onContinue: () -> Void

    @State private var windowAppeared = false
    @State private var visibleLines = 0
    @State private var showsBreakLine = false
    @State private var showsTapHint = false
    @State private var sequenceComplete = false

    private var costLines: [String] {
        [
            L10n.onboarding("painCost.line1", defaultValue: "The System has chosen you."),
            L10n.onboarding("painCost.line2", defaultValue: "You begin at zero, like all before.")
        ]
    }

    private var breakLine: String {
        L10n.onboarding("painCost.break", defaultValue: "Most never rise from it.")
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            AnimeBackdrop(variant: .smoky, intensity: 0.7)
                .ignoresSafeArea()
            ParticleEmitter(config: .embers)
                .opacity(0.12)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            SystemNotificationWindow {
                VStack(spacing: 20) {
                    VStack(spacing: 18) {
                        ForEach(Array(costLines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(Font.unbound.titleM)
                                .foregroundStyle(Color.unbound.textPrimary.opacity(0.92))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(visibleLines > index ? 1 : 0)
                                .scaleEffect(visibleLines > index ? 1 : 1.06)
                                .blur(radius: visibleLines > index ? 0 : 4)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // The override: the app's power color breaks out of the cyan
                    // system frame, so the turn reads as color as much as copy.
                    Text(breakLine)
                        .font(Font.unbound.displayM)
                        .foregroundStyle(Color.unbound.accent)
                        .shadow(color: Color.unbound.accent.opacity(0.6), radius: 18)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                        .opacity(showsBreakLine ? 1 : 0)
                        .scaleEffect(showsBreakLine ? 1 : 1.12)
                        .blur(radius: showsBreakLine ? 0 : 7)
                }
            }
            .padding(.horizontal, 26)
            .opacity(windowAppeared ? 1 : 0)
            .scaleEffect(windowAppeared ? 1 : 0.94)
            .blur(radius: windowAppeared ? 0 : 6)

            VStack {
                Spacer()
                Text(L10n.onboarding("chapter.tapToContinue", defaultValue: "TAP TO CONTINUE"))
                    .font(Font.unbound.monoS)
                    .tracking(2)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .opacity(showsTapHint ? 0.6 : 0)
                    .padding(.bottom, 40)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: handleTap)
        .onAppear(perform: runSequence)
        .statusBarHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func handleTap() {
        if sequenceComplete {
            UnboundHaptics.heavy()
            onContinue()
        } else {
            // Impatient tap: land every line at once and open the exit.
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                visibleLines = costLines.count
                showsBreakLine = true
                showsTapHint = true
            }
            sequenceComplete = true
        }
    }

    private func runSequence() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            windowAppeared = true
        }

        let lineDelays: [Double] = [0.7, 1.75]
        for (index, delay) in lineDelays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard !sequenceComplete else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    visibleLines = max(visibleLines, index + 1)
                }
                UnboundHaptics.medium()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.95) {
            guard !sequenceComplete else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                showsBreakLine = true
            }
            UnboundHaptics.heavy()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
            guard !sequenceComplete else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                showsTapHint = true
            }
            sequenceComplete = true
        }
    }
}

// MARK: - SystemNotificationWindow

/// Reusable Solo-Leveling "[ SYSTEM ]" notification window: a glowing cyan panel
/// with a double border, outset corner brackets, and a live status header, with
/// a content slot below the header divider. Shared by the onboarding story beats
/// (painCost, obstacleFix) so they read as the same in-game System speaking.
struct SystemNotificationWindow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @State private var statusPulse = false

    private var systemCyan: Color { Color.unbound.coachCyan }

    var body: some View {
        VStack(spacing: 20) {
            header

            Rectangle()
                .fill(systemCyan.opacity(0.28))
                .frame(height: 1)

            content()
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(panelBackground)
        .overlay(cornerBrackets)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                statusPulse = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .black))
            Text(L10n.onboarding("painCost.eyebrow", defaultValue: "[ SYSTEM ]"))
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .tracking(3)
            Spacer(minLength: 8)
            Circle()
                .fill(systemCyan)
                .frame(width: 6, height: 6)
                .shadow(color: systemCyan, radius: 4)
                .opacity(statusPulse ? 1 : 0.28)
        }
        .foregroundStyle(systemCyan)
    }

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.7))
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(systemCyan.opacity(0.05))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(systemCyan.opacity(0.55), lineWidth: 1.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(systemCyan.opacity(0.14), lineWidth: 1)
                .padding(4)
        )
        .shadow(color: systemCyan.opacity(0.32), radius: 22)
    }

    // Outset L-brackets at each corner: the touch that reads as a game HUD frame
    // rather than a plain card.
    private var cornerBrackets: some View {
        SystemFrameBrackets(length: 16)
            .stroke(systemCyan.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .padding(-5)
            .shadow(color: systemCyan.opacity(0.5), radius: 5)
    }
}

/// Four L-shaped corner ticks that frame a rect like a game targeting/HUD panel.
private struct SystemFrameBrackets: Shape {
    var length: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        // Top-right
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        // Bottom-left
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        return path
    }
}

#Preview {
    Step_PainCost(onContinue: {})
}
