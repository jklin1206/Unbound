import SwiftUI

/// The commitment ritual at the sealed gate. Right after the reward taste, the
/// user lands in front of the FIRST GATE — closed, dark, waiting. Reading the
/// short vow and signing with a finger is the act that opens it: sealing lands
/// a heavy haptic + accent flare, then advances into `Step_Chapter_Path`, which
/// renders the SAME gate art blasting open. The signature is captured onto the
/// flow so it can be re-surfaced later.
struct Step_Pact: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var strokes: [[CGPoint]] = []
    @State private var isSealing = false
    @State private var sealFlare = false
    @State private var copyIn = false

    private var hasSigned: Bool { strokes.contains { $0.count > 2 } }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // The gate with its doors genuinely SHUT — the same scene
                // Step_Chapter_Path crossfades open, so signing here → the next
                // step reads as one continuous moment: sign, and the doors part.
                Image("onboarding_path_sealed_gate")
                    .resizable()
                    .scaledToFill()
                    .frame(width: fullBleedSize(proxy).width, height: fullBleedSize(proxy).height)
                    .scaleEffect(2.55, anchor: .bottom)
                    .offset(y: 176)
                    .saturation(0.9)
                    .brightness(sealFlare ? 0 : -0.12)
                    .contrast(1.1)
                    .clipped()
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.5), value: sealFlare)

                vignette

                VStack(spacing: 14) {
                    Spacer(minLength: 0)

                    story
                        .opacity(copyIn ? 1 : 0)
                        .offset(y: copyIn ? 0 : 20)
                        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: copyIn)

                    signatureCard
                        .opacity(copyIn ? 1 : 0)
                        .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.12), value: copyIn)

                    HUDButton(
                        title: isSealing ? "OPENING" : "SIGN · OPEN THE GATE",
                        icon: isSealing ? "lock.open.fill" : "signature",
                        isEnabled: hasSigned && !isSealing,
                        action: seal
                    )
                    .opacity(copyIn ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.2), value: copyIn)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, max(18, proxy.safeAreaInsets.bottom + 8))
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            copyIn = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { copyIn = true }
        }
    }

    // MARK: - Story

    private var story: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THE FIRST GATE")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.unbound.accent)
                .shadow(color: Color.unbound.accent.opacity(0.75), radius: 18)
                .shadow(color: .black.opacity(0.9), radius: 3)

            Text("The gate is sealed.")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .shadow(color: .black.opacity(0.85), radius: 4, y: 1)

            Text("The journey waits on the other side. It opens only for those who sign.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.9), radius: 3, y: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: - Signature

    private var signatureCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SIGN TO ENTER")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                if hasSigned && !isSealing {
                    Button {
                        UnboundHaptics.soft()
                        withAnimation(.easeOut(duration: 0.2)) { strokes = [] }
                    } label: {
                        Text("CLEAR")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)

            ZStack {
                SignaturePadView(strokes: $strokes)
                    .frame(height: 150)

                // Baseline + prompt, hidden once there's ink.
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.unbound.textTertiary.opacity(0.7))
                        Rectangle()
                            .fill(Color.unbound.borderSubtle)
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 22)
                }
                .allowsHitTesting(false)

                if !hasSigned {
                    Text("draw your signature")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary.opacity(0.8))
                        .allowsHitTesting(false)
                }
            }
            // The baseline overlay's Spacer is greedy — pin the pad's height on
            // the ZStack itself or the whole card inflates to fill the screen.
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        sealFlare ? Color.unbound.accent : Color.unbound.borderSubtle,
                        lineWidth: sealFlare ? 2 : 1
                    )
            )
            .shadow(color: Color.unbound.accent.opacity(sealFlare ? 0.5 : 0), radius: 22)
            .scaleEffect(sealFlare ? 1.015 : 1)
        }
    }

    // MARK: - Sealed-gate dressing

    private var vignette: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.black.opacity(0.84), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 190)

            Spacer()

            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0),
                    .init(color: Color.black.opacity(0.5), location: 0.32),
                    .init(color: Color.black.opacity(0.9), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 520)
        }
        .ignoresSafeArea()
    }

    private func fullBleedSize(_ proxy: GeometryProxy) -> CGSize {
        CGSize(
            width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
            height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
        )
    }

    // MARK: - Seal

    private func seal() {
        guard hasSigned, !isSealing else { return }
        flow.pactSignatureStrokes = strokes
        UnboundHaptics.heavy()
        withAnimation(.easeOut(duration: 0.28)) {
            isSealing = true
            sealFlare = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            onContinue()
        }
    }
}

#if DEBUG
#Preview {
    Step_Pact(flow: OnboardingFlowViewModel(), progress: 0.9, onBack: {}, onContinue: {})
}
#endif
