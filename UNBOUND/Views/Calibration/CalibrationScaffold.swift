import SwiftUI

struct CalibrationScaffold<Content: View>: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var primaryTitle: String = "Continue"
    var primaryEnabled: Bool = true
    var onBack: (() -> Void)? = nil
    var onPrimary: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            AnimeBackdrop(variant: .smoky, intensity: 1.0)
                .ignoresSafeArea()
            TechGridBackground(opacity: 0.26)
                .ignoresSafeArea()
            ParticleEmitter(config: .embers)
                .opacity(0.28)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(title.uppercased())
                            .font(Font.unbound.titleL)
                            .tracking(0.9)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .shadow(color: Color.unbound.accent.opacity(0.28), radius: 14)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(subtitle)
                                .font(Font.unbound.bodyM)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer().frame(height: 12)
                        content()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HUDButton(
                    title: primaryTitle,
                    icon: "arrow.right",
                    isEnabled: primaryEnabled,
                    action: onPrimary
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            ChamferedRectangle(inset: 4)
                                .stroke(Color.unbound.borderSubtle, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 32, height: 32)
            }

            Spacer(minLength: 0)

            Text(eyebrow)
                .font(Font.unbound.monoS)
                .tracking(2.0)
                .foregroundStyle(Color.unbound.accent)

            Spacer(minLength: 0)

            Color.clear.frame(width: 32, height: 32)
        }
    }
}
