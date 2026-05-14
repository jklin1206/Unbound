import SwiftUI

#if DEBUG
// Hot-reload for SwiftUI iteration. Save any .swift file and the
// simulator re-renders affected views without a rebuild. Requires
// InjectionIII.app installed and pointed at this project.
// See: https://github.com/johnno1962/HotReloading
import HotReloading
#endif

@main
struct UnboundApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var services = ServiceContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(services)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var services: ServiceContainer
    @ObservedObject private var entitlement = EntitlementService.shared
    @State private var isAuthenticated = false
    @State private var isCheckingAuth = true

    // Reacts to UserDefaults changes — flipping this key from Settings
    // immediately re-routes the app back into onboarding.
    @AppStorage("onboardingCompleted") private var hasCompletedOnboarding: Bool = false
    @AppStorage("unbound.calibration.completed") private var hasCompletedCalibration: Bool = false

    var body: some View {
        Group {
            if isCheckingAuth {
                ZStack {
                    Color.unbound.bg.ignoresSafeArea()
                    ProgressView()
                        .tint(Color.unbound.accent)
                }
            } else if !hasCompletedOnboarding {
                OnboardingContainerView(onComplete: {
                    hasCompletedOnboarding = true
                })
            } else if !isAuthenticated {
                AuthContainerView()
            } else if !hasCompletedCalibration {
                CalibrationContainerView(onComplete: {
                    hasCompletedCalibration = true
                })
            } else {
                // Entitlement gating now lives inline on premium features
                // (Coach, Program, Report "unlock" CTA). The app root always
                // lands on Home once onboarding + calibration are complete —
                // the onboarding paywall step is the primary funnel, and
                // per-feature paywalls handle subsequent conversion.
                HomeTabView()
            }
        }
        .task {
            #if DEBUG
            // Dev-only: skip the sign-in gate by auto-provisioning an anonymous local UUID.
            AuthService.shared.autoProvisionIfNeeded()
            #endif

            for await userId in services.auth.authStatePublisher.values {
                isAuthenticated = userId != nil
                if let userId {
                    services.analytics.setUserId(userId)
                    try? await services.subscription.login(userId: userId)
                    // Backfill the 6-axis hex from existing logs on first launch
                    // (no-op if the profile already exists in the store).
                    await services.attribute.backfillFromExistingLogs(userId: userId)
                    // One-time skill-tier migration: replay full log history
                    // to seed UserSkillTierState. Idempotent — guarded by
                    // a UserDefaults flag so it only runs once per user.
                    Task {
                        let profile = try? await services.user.fetchProfile(userId: userId)
                        let bodyweightKg = profile?.weightKg ?? 70.0
                        let logs = (try? await services.workoutLog.fetchLogs(userId: userId, programId: nil)) ?? []
                        let history = logs.flatMap { $0.exerciseEntries }
                        await SkillTierMigration.migrateIfNeeded(
                            userId: userId,
                            history: history,
                            bodyweightKg: bodyweightKg
                        )
                    }
                }
                isCheckingAuth = false
            }
        }
    }
}
