import SwiftUI
import StoreKit

struct Step_UnboundFix: View {
    let onContinue: () -> Void

    @State private var hasAnimated = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            AnimeBackdrop(variant: .godRay, intensity: 0.78)
                .ignoresSafeArea()
            TechGridBackground(opacity: 0.16)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                SystemNoticeCard(
                    eyebrow: L10n.onboarding("unboundFix.eyebrow", defaultValue: "COUNTER-SYSTEM FOUND"),
                    title: L10n.string(.appName, defaultValue: "UNBOUND"),
                    message: L10n.onboarding("unboundFix.message", defaultValue: "A progression layer for your training."),
                    accent: Color.unbound.accent,
                    assetName: "badge_art_first_build_identity_resolved",
                    pulse: pulse
                ) {
                    VStack(spacing: 10) {
                        FixChip(assetName: "badge_art_first_scan", title: L10n.onboarding("unboundFix.chip.baseline", defaultValue: "BASELINE"))
                        FixChip(assetName: "badge_art_proof_10", title: L10n.onboarding("unboundFix.chip.stats", defaultValue: "STATS"))
                        FixChip(assetName: "onboarding_path_rank_gates", title: L10n.onboarding("unboundFix.chip.unlocks", defaultValue: "UNLOCKS"))
                        FixChip(assetName: "onboarding_path_protocol_dossier", title: L10n.onboarding("unboundFix.chip.protocol", defaultValue: "PROTOCOL"))
                    }
                }
                .padding(.horizontal, 22)
                .opacity(hasAnimated ? 1 : 0)
                .offset(y: hasAnimated ? 0 : 12)

                Spacer()

                UnboundButton(title: L10n.onboarding("unboundFix.cta", defaultValue: "Begin your arc"), icon: "flame.fill", action: onContinue)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .opacity(hasAnimated ? 1 : 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.86).delay(0.1)) {
                hasAnimated = true
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct SystemNoticeCard<Content: View>: View {
    let eyebrow: String
    let title: String
    let message: String
    let accent: Color
    let assetName: String
    let pulse: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                OnboardingAssetGlyph(
                    assetName: assetName,
                    tint: accent,
                    size: 34,
                    imagePadding: 5,
                    shape: .hexagon
                )
                .opacity(pulse ? 1 : 0.86)

                VStack(alignment: .leading, spacing: 3) {
                    Text(eyebrow)
                        .font(Font.unbound.monoS)
                        .tracking(1.8)
                        .foregroundStyle(accent)

                    Text(L10n.onboarding("unboundFix.newEntry", defaultValue: "NEW ENTRY"))
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(Font.unbound.displayM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(accent.opacity(pulse ? 0.55 : 0.24), lineWidth: 1)
        )
        .shadow(color: accent.opacity(pulse ? 0.18 : 0.08), radius: pulse ? 22 : 10)
    }
}

struct SystemMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label.uppercased())
                .font(Font.unbound.monoS)
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer(minLength: 12)
            Text(value)
                .font(Font.unbound.monoS)
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.52))
        )
    }
}

struct FixChip: View {
    let assetName: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            OnboardingAssetGlyph(
                assetName: assetName,
                tint: Color.unbound.accent,
                size: 26,
                imagePadding: 5,
                shape: .hexagon,
                showsCornerMark: false
            )

            Text(title)
                .font(Font.unbound.monoS)
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textPrimary)

            Spacer(minLength: 0)

            OnboardingAssetGlyph(
                assetName: "badge_art_first_session",
                tint: Color.unbound.accent,
                size: 20,
                imagePadding: 4,
                shape: .hexagon,
                showsCornerMark: false
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.52))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.18), lineWidth: 1)
        )
    }
}
