import SwiftUI

struct Step_Chapter_Path: View {
    let onContinue: () -> Void

    @State private var cameraOpen = false
    @State private var copyOpen = false
    @State private var buttonOpen = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            Image("onboarding_path_rank_gates")
                .resizable()
                .scaledToFill()
                .scaleEffect(cameraOpen ? 1.02 : 2.42, anchor: .bottom)
                .offset(y: cameraOpen ? 0 : 390)
                .saturation(cameraOpen ? 1.14 : 0.88)
                .brightness(cameraOpen ? 0.01 : -0.24)
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.82),
                                Color.black.opacity(0.28),
                                Color.black.opacity(0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 190)

                        Spacer()

                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black.opacity(cameraOpen ? 0.3 : 0.1),
                                Color.unbound.bg.opacity(cameraOpen ? 0.92 : 0.62)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: cameraOpen ? 250 : 160)
                    }
                )
                .animation(.easeInOut(duration: 3.05), value: cameraOpen)

            if cameraOpen {
                VStack {
                    Spacer()
                    RadialGradient(
                        colors: [
                            Color.unbound.accent.opacity(pulse ? 0.34 : 0.12),
                            Color.clear
                        ],
                        center: .bottom,
                        startRadius: 20,
                        endRadius: 360
                    )
                    .frame(height: 310)
                    .blur(radius: 10)
                    .scaleEffect(pulse ? 1.08 : 0.96, anchor: .bottom)
                    .animation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true), value: pulse)
                }
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text("CHAPTER IV")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color.unbound.accent)
                        .shadow(color: Color.unbound.accent.opacity(0.62), radius: 18)

                    Text("THE CLIMB REVEALS")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .shadow(color: Color.unbound.accent.opacity(0.46), radius: 20)

                    Text("You start at the floor. The rest of the ladder only matters after you begin moving.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textPrimary.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.78),
                            Color.black.opacity(0.46)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.unbound.accent.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .opacity(copyOpen ? 1 : 0)
                .offset(y: copyOpen ? 0 : 26)
                .animation(.easeOut(duration: 0.56), value: copyOpen)

                Spacer().frame(height: 18)

                HUDButton(
                    title: "Show me the climb",
                    icon: "arrow.right",
                    action: onContinue
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
                .opacity(buttonOpen ? 1 : 0)
                .scaleEffect(buttonOpen ? 1 : 0.94)
                .animation(.spring(response: 0.52, dampingFraction: 0.78), value: buttonOpen)
            }
        }
        .contentShape(Rectangle())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            cameraOpen = false
            copyOpen = false
            buttonOpen = false
            pulse = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                cameraOpen = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.95) {
                copyOpen = true
                pulse = true
                UnboundHaptics.heavy()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.45) {
                buttonOpen = true
            }
        }
    }
}

#Preview {
    Step_Chapter_Path(onContinue: {})
}
