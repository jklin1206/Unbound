import SwiftUI

struct Step_Arc02_Problem: View {
    let onContinue: () -> Void

    @State private var silhouetteIn: Bool = false
    @State private var statsIn: Bool = false
    @State private var copyIn: Bool = false

    var body: some View {
        ZStack {
            AnimeBackdrop(variant: .desaturated, intensity: 1.0)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                HStack(alignment: .center, spacing: 18) {
                    SilhouetteView(
                        rimLight: .dim,
                        chromaticAberration: 0.6,
                        breathe: false,
                        scale: 0.8,
                        asset: .dormant
                    )
                    .frame(width: 170)
                    .opacity(silhouetteIn ? 1 : 0)
                    .offset(y: silhouetteIn ? 0 : 20)

                    VStack(spacing: 18) {
                        statBar(label: "STRENGTH",  tier: "E", value: 0.18, delay: 0.00)
                        statBar(label: "STAMINA",   tier: "E", value: 0.22, delay: 0.08)
                        statBar(label: "TECHNIQUE", tier: "E", value: 0.15, delay: 0.16)
                        statBar(label: "VITALITY",  tier: "E", value: 0.24, delay: 0.24)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(statsIn ? 1 : 0)
                    .offset(y: statsIn ? 0 : 16)
                }
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 12) {
                    Text("Your stats aren't where you want them")
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)
                        .tracking(0.2)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Everyone starts here. The ones who stay? They level up.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)
                .opacity(copyIn ? 1 : 0)
                .offset(y: copyIn ? 0 : 12)

                Spacer().frame(height: 24)

                UnboundButton(title: "Continue", icon: "arrow.right", action: onContinue)
                    .opacity(copyIn ? 1 : 0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .statusBarHidden()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                silhouetteIn = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.45)) {
                statsIn = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.85)) {
                copyIn = true
            }
        }
    }

    private func statBar(label: String, tier: String, value: Double, delay: Double) -> some View {
        StatBar(label: label, tier: tier, value: value, animate: true, muted: true, startDelay: 0.5 + delay)
    }
}

#Preview {
    Step_Arc02_Problem(onContinue: {})
}
