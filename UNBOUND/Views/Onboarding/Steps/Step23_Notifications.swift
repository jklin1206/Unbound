import SwiftUI
import UserNotifications

struct Step23_Notifications: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: L10n.onboarding("notifications.title", defaultValue: "The System will call you back."),
            subtitle: L10n.onboarding("notifications.subtitle", defaultValue: "Only when your training window opens."),
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

                // Plain bell — no badge art, no hex chrome.
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.unbound.accent.opacity(0.20),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 110
                            )
                        )
                        .frame(width: 200, height: 200)

                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(Color.unbound.accent)
                        .shadow(color: Color.unbound.accent.opacity(0.5), radius: 16)
                }

                VStack(spacing: 12) {
                    hudBenefitRow(icon: "bell.fill", text: L10n.onboarding("notifications.benefit.streak", defaultValue: "A directive when it is time to train"))
                    hudBenefitRow(icon: "calendar", text: L10n.onboarding("notifications.benefit.schedule", defaultValue: "Timing matched to your chosen schedule"))
                    hudBenefitRow(icon: "moon.zzz.fill", text: L10n.onboarding("notifications.benefit.monthly", defaultValue: "No extra progress or streak alerts by default"))
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

    private func hudBenefitRow(icon: String, text: String) -> some View {
        HUDPanel(isActive: false) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
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

#if DEBUG
#Preview {
    Step23_Notifications(flow: OnboardingFlowViewModel(), progress: 0.76, onBack: {}, onContinue: {})
}

#endif
