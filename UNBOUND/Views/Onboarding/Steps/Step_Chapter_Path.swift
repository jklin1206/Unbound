import SwiftUI

struct Step_Chapter_Path: View {
    let onContinue: () -> Void

    @State private var gateOpen = false
    @State private var copyOpen = false
    @State private var buttonOpen = false
    @State private var shockwave = false
    @State private var scanSweep = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("onboarding_path_open_gate")
                    .resizable()
                    .scaledToFill()
                    .frame(width: fullBleedSize(proxy).width, height: fullBleedSize(proxy).height)
                    .scaleEffect(gateOpen ? 1.72 : 2.55, anchor: .bottom)
                    .offset(y: gateOpen ? 112 : 176)
                    .saturation(gateOpen ? 1.18 : 0.82)
                    .brightness(gateOpen ? 0.02 : -0.32)
                    .contrast(gateOpen ? 1.08 : 1.22)
                    .clipped()
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 2.65), value: gateOpen)

                gateLight
                gateSplit
                scanLines
                vignette

                VStack(spacing: 16) {
                    Spacer(minLength: 0)

                    bottomStory
                        .opacity(copyOpen ? 1 : 0)
                        .offset(y: copyOpen ? 0 : 24)
                        .animation(.spring(response: 0.58, dampingFraction: 0.84), value: copyOpen)

                    HUDButton(
                        title: L10n.onboarding("chapterPath.primary", defaultValue: "Enter the path"),
                        icon: "arrow.right",
                        action: onContinue
                    )
                    .opacity(buttonOpen ? 1 : 0)
                    .scaleEffect(buttonOpen ? 1 : 0.94)
                    .animation(.spring(response: 0.52, dampingFraction: 0.78), value: buttonOpen)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, max(18, proxy.safeAreaInsets.bottom + 8))
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            gateOpen = false
            copyOpen = false
            buttonOpen = false
            shockwave = false
            scanSweep = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                gateOpen = true
                shockwave = true
                scanSweep = true
                UnboundHaptics.heavy()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) {
                copyOpen = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                buttonOpen = true
            }
        }
    }

    private var bottomStory: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.onboarding("chapterPath.chapter", defaultValue: "CHAPTER IV"))
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Color.unbound.accent)
                .shadow(color: Color.unbound.accent.opacity(0.75), radius: 18)

            Text(L10n.onboarding("chapterPath.title", defaultValue: "THE GATE OPENED"))
                .font(.system(size: 39, weight: .black, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .shadow(color: Color.unbound.impact.opacity(0.5), radius: 20)

            Text(L10n.onboarding("chapterPath.body", defaultValue: "The scan marked Day Zero. Now you step into the path: a plan, a rank ladder, and proof that changes when you do."))
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.76),
                    Color.black.opacity(0.44)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.34), lineWidth: 1)
        )
    }

    private var gateLight: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color.unbound.impact.opacity(gateOpen ? 0.52 : 0.02),
                    Color.unbound.accent.opacity(gateOpen ? 0.22 : 0.04),
                    Color.clear
                ],
                center: .center,
                startRadius: 4,
                endRadius: shockwave ? 520 : 36
            )
            .scaleEffect(shockwave ? 1.15 : 0.2)
            .blur(radius: shockwave ? 4 : 18)
            .animation(.easeOut(duration: 1.5), value: shockwave)

            Circle()
                .strokeBorder(Color.unbound.impact.opacity(shockwave ? 0 : 0.8), lineWidth: shockwave ? 1 : 4)
                .frame(width: shockwave ? 620 : 44, height: shockwave ? 620 : 44)
                .blur(radius: shockwave ? 12 : 0)
                .animation(.easeOut(duration: 1.05), value: shockwave)
        }
        .ignoresSafeArea()
    }

    private var gateSplit: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [Color.black.opacity(0.92), Color.black.opacity(0.32)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: gateOpen ? -220 : 0)

            LinearGradient(
                colors: [Color.black.opacity(0.32), Color.black.opacity(0.92)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: gateOpen ? 220 : 0)
        }
        .opacity(gateOpen ? 0 : 0.72)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.05), value: gateOpen)
    }

    private var scanLines: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.unbound.accent.opacity(0.58),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: index == 2 ? 2 : 1)
                        .offset(y: scanSweep ? proxy.size.height + CGFloat(index * 62) : -CGFloat(index * 58 + 90))
                        .blendMode(.screen)
                        .animation(.easeInOut(duration: 1.25).delay(Double(index) * 0.08), value: scanSweep)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var vignette: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.black.opacity(0.84), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 210)

            Spacer()

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.16), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 330)
        }
        .ignoresSafeArea()
    }

    private func fullBleedSize(_ proxy: GeometryProxy) -> CGSize {
        CGSize(
            width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
            height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
        )
    }
}

#Preview {
    Step_Chapter_Path(onContinue: {})
}
