import SwiftUI

// MARK: - Step_ScanReview
//
// Single-photo review. Shows the front capture large with retake + analyze.
//
// V1.1 will add optional side/back photos here as an unlockable "complete
// your 3D scan" moment post-paywall.

struct Step_ScanReview: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onRetake: (ScanAngle) -> Void
    let onSubmit: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: L10n.onboarding("scanReview.title", defaultValue: "Day Zero locked?"),
            subtitle: L10n.onboarding("scanReview.subtitle", defaultValue: "This is the before. In 30 days, you get the first real proof of the climb."),
            progress: progress,
            primaryTitle: L10n.onboarding("scanReview.primary", defaultValue: "Enter the arc"),
            primaryIcon: "flame.fill",
            primaryEnabled: flow.capturedPhotos[.front] != nil,
            hudStep: .scanReview,
            onBack: onBack,
            onPrimary: onSubmit
        ) {
            VStack(spacing: 18) {
                photoCard
                privacyPill
            }
            .padding(.top, 4)
        }
        // No AI body rating — AI never grades the body (scan-redesign-v2).
    }

    // MARK: Photo card — big, centered, premium

    private var photoCard: some View {
        VStack(spacing: 14) {
            Group {
                if let img = flow.capturedPhotos[.front] {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.4), lineWidth: 1.5)
            )
            .shadow(color: Color.unbound.accent.opacity(0.2), radius: 16, x: 0, y: 0)

            Button(action: { onRetake(.front) }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text(L10n.onboarding("scanReview.retake", defaultValue: "Retake Day Zero"))
                        .font(Font.unbound.bodyMStrong)
                }
                .foregroundStyle(Color.unbound.textSecondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.unbound.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Privacy pill — reassurance

    private var privacyPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.onboarding("scanReview.privacy.title", defaultValue: "Private by default"))
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(L10n.onboarding("scanReview.privacy.body", defaultValue: "Your photo stays on your device. Never uploaded."))
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }
}
