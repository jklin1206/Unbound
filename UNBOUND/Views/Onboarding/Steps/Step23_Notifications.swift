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

                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(Color.unbound.accent)
                }

                VStack(spacing: 12) {
                    hudBenefitRow(icon: "flame.fill", text: L10n.onboarding("notifications.benefit.streak", defaultValue: "Never break a streak"))
                    hudBenefitRow(icon: "calendar", text: L10n.onboarding("notifications.benefit.schedule", defaultValue: "Session reminders that work with your schedule"))
                    hudBenefitRow(icon: "chart.line.uptrend.xyaxis", text: L10n.onboarding("notifications.benefit.monthly", defaultValue: "Monthly moments to see what changed"))
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
            DispatchQueue.main.async {
                flow.notificationsRequested = true
                onContinue()
            }
        }
    }

    private func hudBenefitRow(icon: String, text: String) -> some View {
        HUDPanel(isActive: false) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 24)
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

#Preview {
    Step23_Notifications(flow: OnboardingFlowViewModel(), progress: 0.76, onBack: {}, onContinue: {})
}
