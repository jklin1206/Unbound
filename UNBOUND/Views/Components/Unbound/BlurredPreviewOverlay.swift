import SwiftUI

// MARK: - BlurredPreviewOverlay
//
// STUB — fully wired Day 2 for the paywall teaser.
//
// Shows content blurred + darkened with a floating CTA block. Used when we
// reveal the full protocol preview post-verdict, then blur it behind a
// "Unlock full protocol" paywall CTA.
//
// Day 2 will hook this up to RevenueCat/Superwall.

struct BlurredPreviewOverlay<Preview: View, CTA: View>: View {
    @ViewBuilder var preview: () -> Preview
    @ViewBuilder var cta: () -> CTA

    var body: some View {
        ZStack {
            preview()
                .blur(radius: 14, opaque: false)
                .overlay(Color.unbound.bg.opacity(0.35))
                .allowsHitTesting(false)

            VStack {
                Spacer()
                cta()
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.unbound.border, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
    }
}

#Preview {
    BlurredPreviewOverlay(
        preview: {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(0..<6) { i in
                    UnboundCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Week \(i + 1)")
                                .font(Font.unbound.titleS)
                                .foregroundStyle(Color.unbound.textPrimary)
                            Text("Full plan content — locked behind paywall")
                                .font(Font.unbound.bodyM)
                                .foregroundStyle(Color.unbound.textSecondary)
                        }
                    }
                }
            }
            .padding(20)
        },
        cta: {
            VStack(spacing: 12) {
                Text("Unlock your full protocol")
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary)
                UnboundButton(title: "Start 7-day free trial") {}
            }
        }
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.unbound.bg)
}
