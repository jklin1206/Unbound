import SwiftUI
import UserNotifications

struct Step23_Notifications: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: L10n.onboarding("notifications.title", defaultValue: "Stay on track."),
            subtitle: L10n.onboarding("notifications.subtitle", defaultValue: "A small nudge when it's time to keep the streak alive."),
            progress: progress,
            primaryTitle: flow.notificationsRequested
                ? L10n.onboarding("common.continue", defaultValue: "Continue")
                : L10n.onboarding("notifications.enable", defaultValue: "Enable notifications"),
            hudStep: .notifications,
            onBack: onBack,
            onPrimary: handlePrimary
        ) {
            VStack(spacing: 20) {
                Spacer().frame(height: 16)

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.unbound.accent.opacity(0.22),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 120
                            )
                        )
                        .frame(width: 220, height: 220)

                    HUDHexagon()
                        .stroke(Color.unbound.accent.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 140, height: 128)
                        .animeGlow(color: Color.unbound.accent, radius: 14, intensity: 0.7)

                    Image("badge_art_consistency_loop")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .shadow(color: Color.unbound.accent.opacity(0.55), radius: 18)
                }

                VStack(spacing: 12) {
                    hudBenefitRow(assetName: "badge_art_streak_7", text: L10n.onboarding("notifications.benefit.streak", defaultValue: "A clean nudge when it is time to train"))
                    hudBenefitRow(assetName: "badge_art_arc_week", text: L10n.onboarding("notifications.benefit.schedule", defaultValue: "Gym reminders that match your schedule"))
                    hudBenefitRow(assetName: "badge_art_first_scan", text: L10n.onboarding("notifications.benefit.monthly", defaultValue: "No extra progress or streak alerts by default"))
                }

                Spacer().frame(height: 8)

                if !flow.notificationsRequested {
                    Button(action: { onContinue() }) {
                        Text(L10n.onboarding("notifications.skip", defaultValue: "SKIP FOR NOW"))
                            .font(Font.unbound.monoS)
                            .tracking(1.6)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func handlePrimary() {
        if flow.notificationsRequested {
            onContinue()
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            DispatchQueue.main.async {
                flow.notificationsRequested = true
                onContinue()
            }
        }
    }

    private func hudBenefitRow(assetName: String, text: String) -> some View {
        HUDPanel(isActive: false) {
            HStack(spacing: 14) {
                OnboardingAssetGlyph(
                    assetName: assetName,
                    tint: Color.unbound.accent,
                    size: 28,
                    imagePadding: 5,
                    shape: .hexagon,
                    showsCornerMark: false
                )
                Text(text)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

#if DEBUG
#Preview {
    Step23_Notifications(flow: OnboardingFlowViewModel(), progress: 0.76, onBack: {}, onContinue: {})
}

#endif
